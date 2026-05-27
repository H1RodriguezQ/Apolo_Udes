import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../data/models/models.dart';
import '../data/mock/mock_data.dart';
import '../data/services/database_service.dart';
import '../data/services/firestore_service.dart';
import '../data/services/email_service.dart';

class AppProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  Usuario? _usuarioActual;
  Usuario? get usuarioActual => _usuarioActual;
  String get userRole => _usuarioActual?.rol == RolUsuario.administrador ? 'admin' : 'operador';
  bool get isAdmin => _usuarioActual?.rol == RolUsuario.administrador;

  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  bool _camaraPermitida = false;
  bool get camaraPermitida => _camaraPermitida;

  StreamSubscription? _invitadosSubscription;
  StreamSubscription? _invitacionesSubscription;
  StreamSubscription? _confirmacionesSubscription;
  final Set<String> _invitadosProcesados = {};

  // ── Aforo editable ──
  int _aforoDisponible = 145;
  int get aforoDisponible => _aforoDisponible;
  void setAforoDisponible(int valor) {
    _aforoDisponible = valor;
    notifyListeners();
  }

  // ── Fecha ceremonia cargada de Firestore ──
  String _fechaCeremonia = '';

  List<Graduando> _graduandos = List.from(MockData.graduandos);
  List<Invitacion> _invitaciones = [];
  List<Confirmacion> _confirmaciones = [];
  List<Directivo> _directivos = [];
  final List<RegistroAcceso> _registrosAcceso = List.from(MockData.registrosAcceso);
  final List<CampanaNotificacion> _notificaciones = List.from(MockData.notificaciones);
  List<Usuario> _usuarios = List.from(MockData.usuarios);
  List<ActividadReciente> _actividades = List.from(MockData.actividades);

  List<Graduando> get graduandos => _graduandos;
  List<Invitacion> get invitaciones => _invitaciones;
  List<Confirmacion> get confirmaciones => _confirmaciones;
  List<Directivo> get directivos => _directivos;
  List<RegistroAcceso> get registrosAcceso => _registrosAcceso;
  List<CampanaNotificacion> get notificaciones => _notificaciones;
  List<Usuario> get usuarios => _usuarios;
  List<ActividadReciente> get actividades => _actividades;

  int get totalGraduandos => _graduandos.length;
  int get totalInvitaciones => _invitaciones.length;
  int get totalConfirmaciones =>
      _confirmaciones.where((c) => c.estado == EstadoConfirmacion.confirmado).length;
  int get totalDirectivos => _directivos.length;
  int get directivosConfirmados =>
      _directivos.where((d) => d.estado == EstadoDirectivo.confirmado).length;

  // ── Auth ──
  bool login(String correo, String password, {String role = 'admin'}) {
    final rolBuscado = role == 'admin' ? RolUsuario.administrador : RolUsuario.operador;

    final usuario = _usuarios.firstWhere(
      (u) =>
          u.correo.toLowerCase() == correo.toLowerCase() &&
          u.password == password &&
          u.rol == rolBuscado &&
          u.estado == EstadoUsuario.activo,
      orElse: () => Usuario(
        id: '', nombre: '', correo: '', password: '',
        rol: RolUsuario.operador, estado: EstadoUsuario.inactivo,
        ultimoAcceso: DateTime.now(),
      ),
    );

    if (usuario.id.isEmpty) return false;

    final index = _usuarios.indexWhere((u) => u.id == usuario.id);
    if (index != -1) {
      _usuarios[index] = usuario.copyWith(ultimoAcceso: DateTime.now());
    }

    _isAuthenticated = true;
    _usuarioActual = usuario;
    _selectedIndex = 0;
    notifyListeners();

    _cargarFechaCeremonia();
    _iniciarEscuchaInvitados();
    _procesarInvitadosPendientes();
    _escucharInvitacionesFirestore();
    _escucharConfirmacionesFirestore();
    _escucharDirectivosFirestore();
    return true;
  }

  void logout() {
    _isAuthenticated = false;
    _usuarioActual = null;
    _selectedIndex = 0;
    _invitadosSubscription?.cancel();
    _invitacionesSubscription?.cancel();
    _confirmacionesSubscription?.cancel();
    _directivosSubscription?.cancel();
    _invitadosSubscription = null;
    _invitacionesSubscription = null;
    _confirmacionesSubscription = null;
    _directivosSubscription = null;
    _invitadosProcesados.clear();
    _invitaciones = [];
    _confirmaciones = [];
    _fechaCeremonia = '';
    notifyListeners();
  }

  // ── Carga fecha de ceremonia desde Firestore ──
  Future<void> _cargarFechaCeremonia() async {
    if (kIsWeb) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('evento')
          .get();
      if (doc.exists && doc.data()?['fechaCeremonia'] != null) {
        final ts = doc.data()!['fechaCeremonia'] as Timestamp;
        _fechaCeremonia = DateFormat("EEEE d 'de' MMMM 'de' yyyy", 'es_CO')
            .format(ts.toDate());
      }
    } catch (e) {
      debugPrint('Error cargando fecha: $e');
    }
  }

  // ── Escucha invitaciones desde Firestore en tiempo real ──
  void _escucharInvitacionesFirestore() {
    if (kIsWeb) return;
    _invitacionesSubscription?.cancel();
    _invitacionesSubscription = FirebaseFirestore.instance
        .collection('invitados')
        .orderBy('fechaRegistro', descending: true)
        .snapshots()
        .listen((snapshot) {
      _invitaciones = snapshot.docs.map((doc) {
        final data = doc.data();
        final graduandoId = data['graduandoId'] as String? ?? '';
        final graduando = _graduandos.firstWhere(
          (g) => g.id == graduandoId,
          orElse: () => Graduando(
            id: '', codigoEstudiantil: '', documento: '', nombres: '',
            apellidos: '', programa: '', facultad: '', telefono: '',
            correo: '', horaCeremonia: '', estado: EstadoGraduando.activo,
          ),
        );

        final estadoStr = data['estado'] as String? ?? 'pendiente';
        EstadoInvitacion estado;
        switch (estadoStr) {
          case 'enviado': estado = EstadoInvitacion.enviada; break;
          case 'confirmado': estado = EstadoInvitacion.confirmada; break;
          case 'rechazado': estado = EstadoInvitacion.rechazada; break;
          default: estado = EstadoInvitacion.pendiente;
        }

        final confirmacion = data['confirmacion'] as String?;
        if (confirmacion == 'confirmado') estado = EstadoInvitacion.confirmada;
        if (confirmacion == 'rechazado') estado = EstadoInvitacion.rechazada;

        final tipoStr = data['tipo'] as String? ?? 'principal';
        final tipo = tipoStr == 'secundaria'
            ? TipoInvitacion.secundaria
            : TipoInvitacion.principal;

        DateTime? fechaEnvio;
        final fechaTs = data['fechaRegistro'];
        if (fechaTs is Timestamp) fechaEnvio = fechaTs.toDate();

        return Invitacion(
          id: doc.id,
          invitado: data['nombreInvitado'] as String? ?? '',
          graduandoId: graduandoId,
          graduandoNombre: graduando.nombreCompleto.isNotEmpty
              ? graduando.nombreCompleto
              : data['graduandoNombre'] as String? ?? '',
          tipo: tipo,
          estado: estado,
          fechaEnvio: fechaEnvio,
          codigoQr: data['codigoQr'] as String?,
        );
      }).toList();
      notifyListeners();
    }, onError: (e) => debugPrint('Error escuchando invitaciones: $e'));
  }

  // ── Escucha confirmaciones desde Firestore en tiempo real ──
  void _escucharConfirmacionesFirestore() {
    if (kIsWeb) return;
    _confirmacionesSubscription?.cancel();
    _confirmacionesSubscription = FirebaseFirestore.instance
        .collection('invitados')
        .where('confirmacion', whereIn: ['confirmado', 'rechazado'])
        .snapshots()
        .listen((snapshot) {
      _confirmaciones = snapshot.docs.map((doc) {
        final data = doc.data();
        final confirmacionStr = data['confirmacion'] as String? ?? 'pendiente';
        final graduandoId = data['graduandoId'] as String? ?? '';
        final graduando = _graduandos.firstWhere(
          (g) => g.id == graduandoId,
          orElse: () => Graduando(
            id: '', codigoEstudiantil: '', documento: '', nombres: '',
            apellidos: '', programa: '', facultad: '', telefono: '',
            correo: '', horaCeremonia: '', estado: EstadoGraduando.activo,
          ),
        );

        EstadoConfirmacion estado;
        switch (confirmacionStr) {
          case 'confirmado': estado = EstadoConfirmacion.confirmado; break;
          case 'rechazado': estado = EstadoConfirmacion.rechazado; break;
          default: estado = EstadoConfirmacion.pendiente;
        }

        return Confirmacion(
          id: doc.id,
          invitado: data['nombreInvitado'] as String? ?? '',
          documento: data['documento'] as String? ?? '',
          graduandoNombre: graduando.nombreCompleto.isNotEmpty
              ? graduando.nombreCompleto
              : data['graduandoNombre'] as String? ?? '',
          estado: estado,
          codigoQr: data['codigoQr'] as String?,
        );
      }).toList();
      notifyListeners();
    }, onError: (e) => debugPrint('Error escuchando confirmaciones: $e'));
  }

  // ── Firestore listener para nuevos invitados pendientes ──
  void _iniciarEscuchaInvitados() {
    if (kIsWeb) return;
    _invitadosSubscription?.cancel();
    _invitadosSubscription = FirebaseFirestore.instance
        .collection('invitados')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final id = change.doc.id;
          if (!_invitadosProcesados.contains(id)) {
            _invitadosProcesados.add(id);
            _procesarNuevoInvitado(id, data);
          }
        }
      }
    });
  }

  Future<void> _procesarInvitadosPendientes() async {
    if (kIsWeb) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('invitados')
          .where('estado', isEqualTo: 'pendiente')
          .get();
      debugPrint('Invitados pendientes: ${snapshot.docs.length}');
      for (final doc in snapshot.docs) {
        if (!_invitadosProcesados.contains(doc.id)) {
          _invitadosProcesados.add(doc.id);
          await _procesarNuevoInvitado(doc.id, doc.data());
        }
      }
    } catch (e) {
      debugPrint('Error procesando pendientes: $e');
    }
  }

  // ── Procesa invitado: genera QR, sube a ImgBB y envía correo ──
  Future<void> _procesarNuevoInvitado(String invitadoId, Map<String, dynamic> data) async {
    try {
      final graduandoId = data['graduandoId'] as String;
      final nombreInvitado = data['nombreInvitado'] as String;
      final correoInvitado = data['correoInvitado'] as String;
      final codigoQr = data['codigoQr'] as String;

      debugPrint('Procesando: $nombreInvitado - $correoInvitado');

      Graduando? graduando;
      try {
        graduando = _graduandos.firstWhere((g) => g.id == graduandoId);
      } catch (_) {
        graduando = _graduandos.isNotEmpty ? _graduandos.first : null;
      }
      if (graduando == null) return;

      final qrBytes = await _generarQrBytes(codigoQr);

      String qrUrl = '';
      try {
        qrUrl = await FirestoreService.subirQrStorage(
          codigoQr: codigoQr,
          qrBytes: qrBytes,
        );
        debugPrint('QR subido: $qrUrl');
      } catch (e) {
        debugPrint('Error subiendo QR: $e');
      }

      // Usar fecha de Firestore si está disponible
      final fecha = _fechaCeremonia.isNotEmpty
          ? _fechaCeremonia
          : DateFormat("EEEE d 'de' MMMM 'de' yyyy", 'es_CO')
              .format(DateTime.now().add(const Duration(days: 30)));

      final exito = await EmailService.enviarInvitacion(
        graduando: graduando,
        nombreInvitado: nombreInvitado,
        correoInvitado: correoInvitado,
        codigoQr: codigoQr,
        qrBase64: base64Encode(qrBytes),
        qrUrl: qrUrl,
        fechaCeremonia: fecha,
        invitadoId: invitadoId,
      );

      if (exito) {
        await FirebaseFirestore.instance
            .collection('invitados')
            .doc(invitadoId)
            .update({'estado': 'enviado', 'qrUrl': qrUrl});
        _agregarActividad('Invitación enviada a $nombreInvitado', 'email');
        notifyListeners();
        debugPrint('✅ QR enviado a $correoInvitado');
      }
    } catch (e) {
      debugPrint('Error procesando invitado: $e');
    }
  }

  // ── Genera QR como bytes ──
  Future<Uint8List> _generarQrBytes(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      color: const Color(0xFF0F2347),
      emptyColor: Colors.white,
    );
    final imageSize = const Size(200, 200);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    qrPainter.paint(canvas, imageSize);
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 200);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  // ── Permisos ──
  Future<bool> solicitarPermisoCamara() async {
    final status = await Permission.camera.request();
    _camaraPermitida = status.isGranted;
    notifyListeners();
    return _camaraPermitida;
  }

  Future<void> verificarPermisoCamara() async {
    final status = await Permission.camera.status;
    _camaraPermitida = status.isGranted;
    notifyListeners();
  }

  // ── Graduandos CRUD ──
  Future<void> cargarGraduandosDesdeDB() async {
    if (kIsWeb) return;
    try {
      final fromDB = await DatabaseService.instance.getAllGraduandos();
      if (fromDB.isNotEmpty) {
        _graduandos = fromDB;
      } else {
        for (final g in _graduandos) {
          await DatabaseService.instance.insertGraduando(g);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando BD: $e');
    }
  }

  Future<void> agregarGraduando(Graduando graduando) async {
    if (!kIsWeb) await DatabaseService.instance.insertGraduando(graduando);
    try {
      await FirestoreService.guardarGraduando(graduando);
    } catch (e) {
      debugPrint('Error Firestore: $e');
    }
    _graduandos.add(graduando);
    _agregarActividad('Nuevo graduando registrado - ${graduando.nombreCompleto}', 'user');
    notifyListeners();
    if (graduando.correo.isNotEmpty) _enviarCorreoRegistroInvitados(graduando);
  }

  Future<void> _enviarCorreoRegistroInvitados(Graduando graduando) async {
    try {
      await EmailService.enviarCorreoRegistroInvitados(
        graduando: graduando,
        fechaCeremonia: _fechaCeremonia,
      );
    } catch (e) {
      debugPrint('Error enviando correo: $e');
    }
  }

  Future<int> importarGraduandos(List<Graduando> nuevos) async {
    int agregados = 0;
    if (!kIsWeb) {
      agregados = await DatabaseService.instance.insertGraduandosBulk(nuevos);
      _graduandos = await DatabaseService.instance.getAllGraduandos();
    } else {
      for (final g in nuevos) {
        final existe = _graduandos.any(
          (e) => e.documento == g.documento || e.codigoEstudiantil == g.codigoEstudiantil,
        );
        if (!existe) { _graduandos.add(g); agregados++; }
      }
    }
    final graduandosNuevos = _graduandos.take(agregados).toList();
    for (final g in graduandosNuevos) {
      try {
        await FirestoreService.guardarGraduando(g);
        if (g.correo.isNotEmpty) _enviarCorreoRegistroInvitados(g);
      } catch (e) { debugPrint('Error: $e'); }
    }
    _agregarActividad('Importación Excel - $agregados graduandos agregados', 'user');
    notifyListeners();
    return nuevos.length - agregados;
  }

  Future<void> limpiarGraduandos() async {
    final cantidad = _graduandos.length;
    if (!kIsWeb) await DatabaseService.instance.deleteAllGraduandos();
    _graduandos.clear();
    _agregarActividad('Lista de graduandos eliminada ($cantidad registros)', 'user');
    notifyListeners();
  }

  Future<void> editarGraduando(Graduando graduando) async {
    if (!kIsWeb) await DatabaseService.instance.updateGraduando(graduando);
    final index = _graduandos.indexWhere((g) => g.id == graduando.id);
    if (index != -1) { _graduandos[index] = graduando; notifyListeners(); }
  }

  Future<void> eliminarGraduando(String id) async {
    if (!kIsWeb) await DatabaseService.instance.deleteGraduando(id);
    try { await FirestoreService.eliminarGraduando(id); } catch (e) { debugPrint('$e'); }
    _graduandos.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  // ── Invitaciones ──
  void limpiarInvitaciones() {
    if (!isAdmin) return;
    final cantidad = _invitaciones.length;
    _invitaciones = [];
    _agregarActividad('Invitaciones eliminadas ($cantidad registros)', 'delete');
    notifyListeners();
  }

  // ── Confirmaciones ──
  void limpiarConfirmaciones() {
    if (!isAdmin) return;
    final cantidad = _confirmaciones.length;
    _confirmaciones = [];
    _agregarActividad('Confirmaciones eliminadas ($cantidad registros)', 'delete');
    notifyListeners();
  }

  // ── Directivos CRUD ──
  StreamSubscription? _directivosSubscription;

  void _escucharDirectivosFirestore() {
    if (kIsWeb) return;
    _directivosSubscription?.cancel();
    _directivosSubscription = FirebaseFirestore.instance
        .collection('directivos')
        .snapshots()
        .listen((snapshot) {
      _directivos = snapshot.docs.map((doc) {
        final data = doc.data();
        EstadoDirectivo estado = EstadoDirectivo.pendiente;
        final conf = data['confirmacion'] as String?;
        if (conf == 'confirmado') estado = EstadoDirectivo.confirmado;
        if (conf == 'rechazado') estado = EstadoDirectivo.rechazado;
        return Directivo(
          id: doc.id,
          nombre: data['nombre'] as String? ?? '',
          cargo: data['cargo'] as String? ?? '',
          correo: data['correo'] as String? ?? '',
          facultad: data['facultad'] as String?,
          telefono: data['telefono'] as String?,
          estado: estado,
          fechaConfirmacion: null,
        );
      }).toList();
      notifyListeners();
    }, onError: (e) => debugPrint('Error escuchando directivos: $e'));
  }

  Future<void> agregarDirectivo(Directivo directivo) async {
    if (!isAdmin) return;
    try {
      await FirebaseFirestore.instance
          .collection('directivos')
          .doc(directivo.id)
          .set({
        'id': directivo.id,
        'nombre': directivo.nombre,
        'cargo': directivo.cargo,
        'correo': directivo.correo,
        'facultad': directivo.facultad,
        'telefono': directivo.telefono,
        'confirmacion': 'pendiente',
        'fechaRegistro': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error guardando directivo: $e');
    }
    _directivos.add(directivo);
    _agregarActividad('Directivo agregado - ${directivo.nombre}', 'user');
    notifyListeners();

    if (directivo.correo.isNotEmpty) {
      try {
        await EmailService.enviarInvitacionDirectivo(
          nombre: directivo.nombre,
          cargo: directivo.cargo,
          correo: directivo.correo,
          directivoId: directivo.id,
          fechaCeremonia: _fechaCeremonia,
        );
        debugPrint('✅ Invitación directivo enviada a ${directivo.correo}');
      } catch (e) {
        debugPrint('Error enviando correo directivo: $e');
      }
    }
  }

  Future<void> editarDirectivo(Directivo directivo) async {
    if (!isAdmin) return;
    try {
      await FirebaseFirestore.instance
          .collection('directivos')
          .doc(directivo.id)
          .update({
        'nombre': directivo.nombre,
        'cargo': directivo.cargo,
        'correo': directivo.correo,
        'facultad': directivo.facultad,
        'telefono': directivo.telefono,
      });
    } catch (e) {
      debugPrint('Error editando directivo: $e');
    }
    final index = _directivos.indexWhere((d) => d.id == directivo.id);
    if (index != -1) {
      _directivos[index] = directivo;
      _agregarActividad('Directivo actualizado - ${directivo.nombre}', 'user');
      notifyListeners();
    }
  }

  Future<void> eliminarDirectivo(String id) async {
    if (!isAdmin) return;
    try {
      await FirebaseFirestore.instance.collection('directivos').doc(id).delete();
    } catch (e) {
      debugPrint('Error eliminando directivo: $e');
    }
    _directivos.removeWhere((d) => d.id == id);
    _agregarActividad('Directivo eliminado', 'delete');
    notifyListeners();
  }

  Future<void> limpiarDirectivos() async {
    if (!isAdmin) return;
    final cantidad = _directivos.length;
    for (final d in List.from(_directivos)) {
      try {
        await FirebaseFirestore.instance.collection('directivos').doc(d.id).delete();
      } catch (_) {}
    }
    _directivos = [];
    _agregarActividad('Directivos eliminados ($cantidad registros)', 'delete');
    notifyListeners();
  }

  // ── Usuarios CRUD ──
  void agregarUsuario(Usuario usuario) {
    if (!isAdmin) return;
    _usuarios.add(usuario);
    notifyListeners();
  }

  void editarUsuario(Usuario usuario) {
    if (!isAdmin) return;
    final index = _usuarios.indexWhere((u) => u.id == usuario.id);
    if (index != -1) { _usuarios[index] = usuario; notifyListeners(); }
  }

  void eliminarUsuario(String id) {
    if (!isAdmin) return;
    _usuarios.removeWhere((u) => u.id == id);
    notifyListeners();
  }

  // ── Códigos QR ya usados ──
  final Set<String> _codigosUsados = {};

  bool codigoYaUsado(String codigo) => _codigosUsados.contains(codigo);

  // ── Acceso QR ──
  RegistroAcceso? verificarAcceso(String codigoODocumento) {
    // Bloquear segunda entrada
    if (_codigosUsados.contains(codigoODocumento)) return null;

    final confirmacion = _confirmaciones.firstWhere(
      (c) => c.codigoQr == codigoODocumento || c.documento == codigoODocumento,
      orElse: () => Confirmacion(
        id: '', invitado: '', documento: '', graduandoNombre: '',
        estado: EstadoConfirmacion.pendiente,
      ),
    );
    if (confirmacion.id.isEmpty) return null;
    if (confirmacion.estado == EstadoConfirmacion.confirmado) {
      // Marcar como usado
      _codigosUsados.add(codigoODocumento);

      final registro = RegistroAcceso(
        id: 'ACC${DateTime.now().millisecondsSinceEpoch}',
        nombre: confirmacion.invitado,
        documento: confirmacion.documento,
        horaAcceso: DateTime.now(),
        valido: true,
      );
      _registrosAcceso.insert(0, registro);
      _agregarActividad('Acceso registrado - ${confirmacion.invitado} (QR)', 'qr');
      notifyListeners();
      return registro;
    }
    return null;
  }

  void _agregarActividad(String detalle, String tipo) {
    _actividades.insert(
      0,
      ActividadReciente(
        id: 'ACT${DateTime.now().millisecondsSinceEpoch}',
        detalle: detalle,
        usuario: _usuarioActual?.correo ?? 'sistema',
        hora: DateTime.now(),
        tipo: tipo,
      ),
    );
    if (_actividades.length > 20) {
      _actividades = _actividades.take(20).toList();
    }
  }

  Future<void> enviarRecordatorios() async {
    if (kIsWeb) return;
    int enviados = 0;

    // Solo enviar a invitados que tienen correo y estado enviado o confirmado
    final snapshot = await FirebaseFirestore.instance
        .collection('invitados')
        .where('estado', whereIn: ['enviado', 'confirmado'])
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final correo = data['correoInvitado'] as String? ?? '';
      final nombre = data['nombreInvitado'] as String? ?? '';
      final codigoQr = data['codigoQr'] as String? ?? '';
      final qrUrl = data['qrUrl'] as String? ?? '';
      final graduandoNombre = data['graduandoNombre'] as String? ?? '';
      final graduandoId = data['graduandoId'] as String? ?? '';

      if (correo.isEmpty) continue;

      // Obtener hora del graduando
      String hora = '';
      try {
        final graduando = _graduandos.firstWhere((g) => g.id == graduandoId);
        hora = graduando.horaCeremonia;
      } catch (_) {}

      try {
        await EmailService.enviarRecordatorio(
          nombreInvitado: nombre,
          correoInvitado: correo,
          codigoQr: codigoQr,
          fechaCeremonia: _fechaCeremonia,
          horaCeremonia: hora,
          graduandoNombre: graduandoNombre,
          qrUrl: qrUrl,
        );
        enviados++;
      } catch (e) {
        debugPrint('Error enviando recordatorio a $correo: $e');
      }
    }

    _agregarActividad('Recordatorios enviados ($enviados)', 'email');
    notifyListeners();
  }
}