import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/validators/validadores_graduando.dart';
import '../data/models/models.dart';
import '../data/services/database_service.dart';
import '../data/services/firestore_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/usuarios_service.dart';

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

  StreamSubscription? _graduandosSubscription;
  StreamSubscription? _invitacionesSubscription;
  StreamSubscription? _confirmacionesSubscription;
  StreamSubscription? _directivosSubscription;
  StreamSubscription? _solicitudesSubscription;
  StreamSubscription? _conexionSubscription;
  Timer? _timerConexion;
  bool _enLinea = true;

  /// false cuando la tablet no le está respondiendo a Firestore (sin internet).
  bool get enLinea => _enLinea;

  int _aforoDisponible = 145;
  int get aforoDisponible => _aforoDisponible;
  void setAforoDisponible(int valor) {
    _aforoDisponible = valor;
    notifyListeners();
  }


  // Ninguna lista arranca con datos de prueba: en producción solo se muestran
  // datos reales que vienen de Firestore o de la copia local de SQLite.
  List<Graduando> _graduandos = [];
  List<Invitacion> _invitaciones = [];
  List<Confirmacion> _confirmaciones = [];
  List<Directivo> _directivos = [];
  final List<RegistroAcceso> _registrosAcceso = [];
  List<CampanaNotificacion> _notificaciones = [];
  List<Usuario> _usuarios = [];
  List<ActividadReciente> _actividades = [];

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
  // El rol proviene del documento usuarios/{uid}, que solo un administrador
  // puede escribir (reglas de Firestore). El cliente no lo elige.
  // Devuelve null si el inicio de sesion fue correcto, o el mensaje de error.
  Future<String?> login(String correo, String password) async {
    try {
      final usuario = await AuthService.iniciarSesion(correo, password);
      _isAuthenticated = true;
      _usuarioActual = usuario;
      _selectedIndex = 0;
      notifyListeners();
      _escucharGraduandosFirestore();
      _escucharEstadoConexion();
      _cargarUsuariosFirestore();
      _escucharInvitacionesFirestore();
      _escucharConfirmacionesFirestore();
      _escucharDirectivosFirestore();
      _escucharSolicitudesCorreo();
      await _cargarValidacionesDelDia();
      return null;
    } on AuthException catch (e) {
      return e.mensaje;
    }
  }

  // Restaura la sesion al abrir la aplicacion, si el token sigue vigente.
  Future<void> restaurarSesion() async {
    final usuario = await AuthService.sesionActual();
    if (usuario == null) return;
    _isAuthenticated = true;
    _usuarioActual = usuario;
    _selectedIndex = 0;
    notifyListeners();
    _escucharGraduandosFirestore();
    _escucharEstadoConexion();
    _cargarUsuariosFirestore();
    _escucharInvitacionesFirestore();
    _escucharConfirmacionesFirestore();
    _escucharDirectivosFirestore();
    _escucharSolicitudesCorreo();
    await _cargarValidacionesDelDia();
  }

  // Perfiles de usuario para mostrar en la interfaz.
  Future<void> _cargarUsuariosFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('usuarios').get();
      _usuarios = snap.docs.map((doc) {
        final data = doc.data();
        final rolStr = data['rol'] as String? ?? 'operador';
        return Usuario(
          id: doc.id,
          nombre: data['nombre'] as String? ?? '',
          correo: data['correo'] as String? ?? '',
          password: '',
          rol: rolStr == 'admin' ? RolUsuario.administrador : RolUsuario.operador,
          estado: (data['estado'] as String? ?? 'activo') == 'activo'
              ? EstadoUsuario.activo
              : EstadoUsuario.inactivo,
          ultimoAcceso: DateTime.now(),
          puntoValidacion: data['puntoValidacion'] as String?,
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando usuarios: $e');
    }
  }

  /// Accesos que ya no se pueden repetir hoy: suma de lo validado en
  /// Firestore (hoy), de lo validado sin conexión y de los confirmados.
  int get accesosHoy => _codigosUsados.length;

  /// Cierre de la jornada (fin de turno). Deja constancia en la bitácora de
  /// cuántos accesos se llevaron hoy y cierra la sesión para que el siguiente
  /// turno entre con su propio usuario. No borra nada: `validaciones` guarda
  /// el histórico del día y Firestore sigue siendo la fuente de verdad.
  Future<void> cerrarJornada() async {
    final autor = _usuarioActual;
    final accesos = _codigosUsados.length;
    if (autor != null) {
      // Antes de cerrar sesión: la auditoría necesita el token vigente.
      await UsuariosService.auditar(
        autor,
        'Cerro la jornada con $accesos acceso(s) validado(s)',
        tipo: 'jornada',
        detalle: 'Cierre de turno; el detalle del día queda en validaciones',
      );
    }
    logout();
  }

  void logout() {
    AuthService.cerrarSesion();
    _isAuthenticated = false;
    _usuarioActual = null;
    _selectedIndex = 0;
    _graduandosSubscription?.cancel();
    _invitacionesSubscription?.cancel();
    _confirmacionesSubscription?.cancel();
    _directivosSubscription?.cancel();
    _solicitudesSubscription?.cancel();
    _graduandosSubscription = null;
    _invitacionesSubscription = null;
    _confirmacionesSubscription = null;
    _directivosSubscription = null;
    _solicitudesSubscription = null;
    _validacionesSubscription?.cancel();
    _conexionSubscription?.cancel();
    _timerConexion?.cancel();
    _validacionesSubscription = null;
    _conexionSubscription = null;
    _timerConexion = null;
    _enLinea = true;
    _codigosUsados.clear();
    _codigosValidadosLocalmente.clear();
    _codigosValidosDelDia.clear();
    _invitaciones = [];
    _confirmaciones = [];
    _notificaciones = [];
    _usuarios = [];
    notifyListeners();
  }

  // ── Estado de la conexión ──
  // Se mide con el propio Firestore: si el dato llega de la caché local, la
  // tablet no está hablando con el servidor. No se agrega una librería de
  // conectividad porque lo que importa en la entrada es exactamente eso:
  // poder consultar Firestore y subir las validaciones.
  void _escucharEstadoConexion() {
    if (kIsWeb) return;
    _conexionSubscription?.cancel();
    _conexionSubscription = FirebaseFirestore.instance
        .collection('configuracion')
        .doc('evento')
        // Sin esto solo se avisa cuando cambian los datos; se necesita que
        // también avise cuando cambia el ORIGEN (servidor <-> caché).
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      _actualizarConexion(snap.metadata.isFromCache);
    }, onError: (e) {
      debugPrint('Error midiendo la conexión: $e');
      _actualizarConexion(true);
    });
  }

  // Se espera un momento antes de avisar "sin conexión" para no parpadear
  // al abrir la app (Firestore tarda un instante en confirmar que ya habló
  // con el servidor). Si vuelve la red en ese tiempo, no se marca nada.
  void _actualizarConexion(bool vieneDeCache) {
    if (!vieneDeCache) {
      _timerConexion?.cancel();
      _timerConexion = null;
      if (!_enLinea) {
        _enLinea = true;
        notifyListeners();
      }
      return;
    }
    if (_timerConexion != null || !_enLinea) return;
    _timerConexion = Timer(const Duration(seconds: 3), () {
      _timerConexion = null;
      if (_enLinea) {
        _enLinea = false;
        notifyListeners();
      }
    });
  }

  void _escucharInvitacionesFirestore() {
    _invitacionesSubscription?.cancel();
    _invitacionesSubscription = FirebaseFirestore.instance
        .collection('invitados').orderBy('fechaRegistro', descending: true)
        .snapshots().listen((snapshot) {
      _invitaciones = snapshot.docs.map((doc) {
        final data = doc.data();
        final graduandoId = data['graduandoId'] as String? ?? '';
        final graduando = _graduandos.firstWhere((g) => g.id == graduandoId,
          orElse: () => Graduando(id: '', codigoEstudiantil: '', documento: '', nombres: '',
            apellidos: '', programa: '', facultad: '', telefono: '', correo: '', horaCeremonia: '', estado: EstadoGraduando.activo));
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
        // Un invitado anulado nunca aparece como confirmado: manda su
        // `estado` sobre lo que diga `confirmacion` y se marca aparte para
        // no contarlo como "rechazado" (lo anuló la universidad, no él).
        if (estadoStr == 'anulado') estado = EstadoInvitacion.anulada;
        final tipoStr = data['tipo'] as String? ?? 'principal';
        final tipo = tipoStr == 'secundaria' ? TipoInvitacion.secundaria : TipoInvitacion.principal;
        DateTime? fechaEnvio;
        final fechaTs = data['fechaRegistro'];
        if (fechaTs is Timestamp) fechaEnvio = fechaTs.toDate();
        return Invitacion(id: doc.id, invitado: data['nombreInvitado'] as String? ?? '',
          graduandoId: graduandoId, graduandoNombre: graduando.nombreCompleto.isNotEmpty ? graduando.nombreCompleto : data['graduandoNombre'] as String? ?? '',
          tipo: tipo, estado: estado, fechaEnvio: fechaEnvio, codigoQr: data['codigoQr'] as String?);
      }).toList();
      notifyListeners();
    }, onError: (e) => debugPrint('Error escuchando invitaciones: $e'));
  }

  // Desde que el registro en la página web cuenta como confirmación, todo
  // invitado registrado que ya tenga su código de acceso puede entrar. Antes
  // solo entraban los que tenían `confirmacion: 'confirmado'` (la página
  // vieja de "asistiré / no asistiré") y los registrados en la web siempre
  // salían como QR inválido.
  // No entran: los anulados (los anuló la universidad) ni los que avisaron
  // que no asisten. Los que todavía no tienen código quedan "pendientes":
  // Apps Script se los asigna y les manda el correo en unos minutos.
  void _escucharConfirmacionesFirestore() {
    _confirmacionesSubscription?.cancel();
    _confirmacionesSubscription = FirebaseFirestore.instance
        .collection('invitados')
        .snapshots().listen((snapshot) {
      _confirmaciones = snapshot.docs
          .where((doc) => doc.data()['estado'] != 'anulado')
          .map((doc) {
        final data = doc.data();
        final graduandoId = data['graduandoId'] as String? ?? '';
        final graduando = _graduandos.firstWhere((g) => g.id == graduandoId,
          orElse: () => Graduando(id: '', codigoEstudiantil: '', documento: '', nombres: '',
            apellidos: '', programa: '', facultad: '', telefono: '', correo: '', horaCeremonia: '', estado: EstadoGraduando.activo));
        final codigoQr = (data['codigoQr'] as String? ?? '').trim();
        EstadoConfirmacion estado;
        if (data['confirmacion'] == 'rechazado') {
          estado = EstadoConfirmacion.rechazado;
        } else if (codigoQr.isNotEmpty) {
          estado = EstadoConfirmacion.confirmado;
        } else {
          estado = EstadoConfirmacion.pendiente;
        }
        return Confirmacion(id: doc.id, invitado: data['nombreInvitado'] as String? ?? '',
          documento: data['documento'] as String? ?? '',
          graduandoNombre: graduando.nombreCompleto.isNotEmpty ? graduando.nombreCompleto : data['graduandoNombre'] as String? ?? '',
          estado: estado, codigoQr: codigoQr.isEmpty ? null : codigoQr);
      }).toList();
      _reconstruirCodigosUsados();
      notifyListeners();
    }, onError: (e) => debugPrint('Error escuchando confirmaciones: $e'));
  }

  void setSelectedIndex(int index) { _selectedIndex = index; notifyListeners(); }

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

  // ── Graduandos: sincronización entre tablets ──
  // Firestore es la fuente de verdad. Cada tablet escucha la colección en
  // tiempo real, de modo que un graduando agregado, editado o eliminado en
  // una tablet aparece en la otra en segundos y sin reiniciar la aplicación.
  void _escucharGraduandosFirestore() {
    _graduandosSubscription?.cancel();
    _graduandosSubscription = FirebaseFirestore.instance
        .collection('graduandos')
        .snapshots()
        .listen((snapshot) {
      final lista = snapshot.docs
          .map((doc) => _graduandoDesdeDatos(doc.id, doc.data()))
          .toList();
      _graduandos = _fusionarGraduandos(lista,
          desdeCache: snapshot.metadata.isFromCache);
      _ordenarGraduandos();
      notifyListeners();
      // Cada snapshot también se guarda en SQLite: si se cae la conexión o
      // se cierra la app, la próxima apertura muestra los mismos datos.
      _espejarGraduandosEnSQLite();
    }, onError: (e) => debugPrint('Error escuchando graduandos: $e'));
  }

  /// Une lo que llega de Firestore con lo que ya estaba en memoria.
  /// Un snapshot que viene de la caché local puede estar incompleto (solo
  /// trae lo que ya se leyó antes), así que no borra: solo agrega o
  /// actualiza. Los snapshots que vienen del servidor sí son completos y
  /// mandan sobre la lista completa (incluidas las eliminaciones).
  List<Graduando> _fusionarGraduandos(List<Graduando> desdeFirestore,
      {required bool desdeCache}) {
    if (!desdeCache || _graduandos.isEmpty) return desdeFirestore;
    final porId = <String, Graduando>{for (final g in _graduandos) g.id: g};
    for (final g in desdeFirestore) {
      porId[g.id] = g;
    }
    return porId.values.toList();
  }

  /// Mismo criterio de orden que usa SQLite (por apellidos) para que la
  /// lista se vea igual en las dos tablets.
  void _ordenarGraduandos() {
    _graduandos.sort((a, b) => a.apellidos
        .toLowerCase()
        .compareTo(b.apellidos.toLowerCase()));
  }

  /// Convierte un documento de Firestore en el objeto de la app.
  Graduando _graduandoDesdeDatos(String id, Map<String, dynamic> d) {
    final estadoStr = d['estado'] as String? ?? 'activo';
    EstadoGraduando estado;
    switch (estadoStr) {
      case 'pendiente':
        estado = EstadoGraduando.pendiente;
        break;
      case 'inactivo':
        estado = EstadoGraduando.inactivo;
        break;
      default:
        estado = EstadoGraduando.activo;
    }
    return Graduando(
      id: id,
      codigoEstudiantil: d['codigoEstudiantil'] as String? ?? '',
      documento: d['documento'] as String? ?? '',
      nombres: d['nombres'] as String? ?? '',
      apellidos: d['apellidos'] as String? ?? '',
      programa: d['programa'] as String? ?? '',
      facultad: d['facultad'] as String? ?? '',
      telefono: d['telefono'] as String? ?? '',
      correo: d['correo'] as String? ?? '',
      horaCeremonia: d['horaCeremonia'] as String? ?? '08:00 AM',
      estado: estado,
      // Estado del correo del enlace de registro (lo escribe el servidor).
      correoRegistro: d['correoRegistro'] as String?,
    );
  }

  Future<void> _espejarGraduandosEnSQLite() async {
    if (kIsWeb) return;
    try {
      await DatabaseService.instance.sincronizarGraduandos(_graduandos);
    } catch (e) {
      debugPrint('Error espejando graduandos en SQLite: $e');
    }
  }

  /// Agrega o reemplaza un graduando en la lista en memoria usando el ID
  /// como clave. Antes se usaba `add`, y como el listener de Firestore
  /// también entregaba el mismo documento, el graduando quedaba dos veces.
  void _actualizarGraduandoLocal(Graduando graduando) {
    final i = _graduandos.indexWhere((g) => g.id == graduando.id);
    if (i == -1) {
      _graduandos.add(graduando);
    } else {
      _graduandos[i] = graduando;
    }
    _ordenarGraduandos();
  }

  // ── Graduandos CRUD ──

  /// Carga la copia local de SQLite al abrir la app. Así, si la tablet está
  /// sin internet, se ven los graduandos guardados; cuando llega el primer
  /// snapshot de Firestore, la lista se reemplaza por la de la nube.
  Future<void> cargarGraduandosDesdeDB() async {
    if (kIsWeb) return;
    try {
      final fromDB = await DatabaseService.instance.getAllGraduandos();
      if (fromDB.isNotEmpty) {
        _graduandos = fromDB;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error cargando BD: $e');
    }
  }

  Future<void> agregarGraduando(Graduando graduando) async {
    // Primero Firestore (la fuente de verdad). Si falla, lanza el error y
    // no se toca nada local, para no dejar la nube y el dispositivo distintos.
    await FirestoreService.guardarGraduando(graduando);
    if (!kIsWeb) await DatabaseService.instance.insertGraduando(graduando);
    _actualizarGraduandoLocal(graduando);
    _agregarActividad('Nuevo graduando registrado - ${graduando.nombreCompleto}', 'user');
    notifyListeners();
    // El correo con el enlace de registro lo envía Apps Script: guardarGraduando
    // deja el graduando con correoRegistro = "pendiente".
  }

  /// Importa un Excel. El chequeo de duplicados se hace contra Firestore,
  /// no contra la lista local: la tabla puede haberse registrado en otra
  /// tablet y la copia local no estar al día. Devuelve cuántos eran
  /// duplicados (por documento o por código estudiantil).
  Future<int> importarGraduandos(List<Graduando> nuevos) async {
    final snapshot =
        await FirebaseFirestore.instance.collection('graduandos').get();
    final documentos = <String>{};
    final codigos = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final documento = (data['documento'] as String? ?? '').trim();
      final codigo = (data['codigoEstudiantil'] as String? ?? '').trim();
      if (documento.isNotEmpty) documentos.add(documento);
      if (codigo.isNotEmpty) codigos.add(codigo);
    }

    final realmenteNuevos = <Graduando>[];
    int duplicados = 0;
    for (final g in nuevos) {
      final repetido = documentos.contains(g.documento) ||
          codigos.contains(g.codigoEstudiantil);
      if (repetido) {
        duplicados++;
        continue;
      }
      // Se marcan de una vez: si el mismo Excel trae dos filas iguales,
      // la segunda tampoco entra.
      documentos.add(g.documento);
      codigos.add(g.codigoEstudiantil);
      realmenteNuevos.add(g);
    }

    // Antes se metían en SQLite TODOS los `nuevos`, duplicados incluidos.
    // Ahora solo se escribe lo que realmente no existía, y siempre
    // primero en Firestore.
    for (final g in realmenteNuevos) {
      await FirestoreService.guardarGraduando(g);
      if (!kIsWeb) await DatabaseService.instance.insertGraduando(g);
      _actualizarGraduandoLocal(g);
    }

    _agregarActividad('Importación Excel - ${realmenteNuevos.length} graduandos agregados', 'user');
    notifyListeners();
    return duplicados;
  }

  // Las tres operaciones siguientes escriben PRIMERO en Firestore y solo
  // después en la base local. Si Firestore falla, lanzan el error para que la
  // pantalla lo muestre, en vez de dejar la nube y el dispositivo distintos.

  /// Borra todos los graduandos (Firestore y local) y anula sus invitados.
  /// Antes solo borraba la base local: los graduandos seguían en la nube y
  /// sus enlaces de registro de invitados seguían funcionando.
  Future<void> limpiarGraduandos() async {
    if (!isAdmin) return;
    final cantidad = _graduandos.length;
    await FirestoreService.eliminarTodosGraduandos();
    if (!kIsWeb) await DatabaseService.instance.deleteAllGraduandos();
    _graduandos.clear();
    _agregarActividad('Lista de graduandos eliminada ($cantidad registros)', 'user');
    notifyListeners();
  }

  /// Antes solo actualizaba la base local: la página pública y los correos
  /// seguían mostrando los datos viejos.
  Future<void> editarGraduando(Graduando graduando) async {
    if (!isAdmin) return;
    await FirestoreService.actualizarGraduando(graduando);
    // `insert` con reemplazo sirve de actualización y de alta a la vez, así
    // que la copia local queda bien aunque la fila no existiera.
    if (!kIsWeb) await DatabaseService.instance.insertGraduando(graduando);
    _actualizarGraduandoLocal(graduando);
    notifyListeners();
  }

  /// Elimina el graduando y anula a sus invitados. Devuelve cuántos invitados
  /// quedaron anulados.
  Future<int> eliminarGraduando(String id) async {
    if (!isAdmin) return 0;
    final anulados = await FirestoreService.eliminarGraduando(id);
    if (!kIsWeb) await DatabaseService.instance.deleteGraduando(id);
    _graduandos.removeWhere((g) => g.id == id);
    notifyListeners();
    return anulados;
  }

  void limpiarInvitaciones() { if (!isAdmin) return; _invitaciones = []; notifyListeners(); }
  void limpiarConfirmaciones() { if (!isAdmin) return; _confirmaciones = []; notifyListeners(); }

  // ── Directivos CRUD con QR ──

  void _escucharDirectivosFirestore() {
    _directivosSubscription?.cancel();
    _directivosSubscription = FirebaseFirestore.instance
        .collection('directivos').snapshots().listen((snapshot) {
      _directivos = snapshot.docs.map((doc) {
        final data = doc.data();
        EstadoDirectivo estado = EstadoDirectivo.pendiente;
        final conf = data['confirmacion'] as String?;
        if (conf == 'confirmado') estado = EstadoDirectivo.confirmado;
        if (conf == 'rechazado') estado = EstadoDirectivo.rechazado;
        return Directivo(
          id: doc.id, nombre: data['nombre'] as String? ?? '',
          cargo: data['cargo'] as String? ?? '', correo: data['correo'] as String? ?? '',
          facultad: data['facultad'] as String?, telefono: data['telefono'] as String?,
          estado: estado, fechaConfirmacion: null,
          codigoQr: data['codigoQr'] as String?,
          // Estado del correo de invitación (lo escribe el servidor).
          correoInvitacion: data['correoInvitacion'] as String?,
        );
      }).toList();
      _reconstruirCodigosUsados();
      notifyListeners();
    }, onError: (e) => debugPrint('Error escuchando directivos: $e'));
  }

  Future<void> agregarDirectivo(Directivo directivo) async {
    if (!isAdmin) return;

    // Código aleatorio de 128 bits. Antes era 'DIR-{id}-{milisegundos}',
    // que se podía adivinar con solo mirar la hora del registro.
    final codigoQr = FirestoreService.generarCodigoAcceso(prefijo: 'DIR');

    try {
      await FirebaseFirestore.instance.collection('directivos').doc(directivo.id).set({
        'nombre': directivo.nombre, 'cargo': directivo.cargo, 'correo': directivo.correo,
        'facultad': directivo.facultad, 'telefono': directivo.telefono,
        'confirmacion': 'pendiente', 'codigoQr': codigoQr,
        'fechaRegistro': FieldValue.serverTimestamp(),
        // Apps Script envía la invitación a los que están "pendiente".
        'correoInvitacion': 'pendiente',
      });
    } catch (e) { debugPrint('Error guardando directivo: $e'); }

    // En la caché local también queda como "pendiente": en cuanto el
    // servidor lo envíe lo escribirá con el resultado real.
    final directivoConQr = directivo
        .copyWith(codigoQr: codigoQr, correoInvitacion: 'pendiente');
    _directivos.add(directivoConQr);
    _agregarActividad('Directivo agregado - ${directivo.nombre}', 'user');
    notifyListeners();

    // La invitación la envía Apps Script (correoInvitacion = "pendiente").
  }

  /// Reenviar la invitación a un directivo: se marca como pendiente y
  /// Apps Script la envía en su siguiente revisión (máximo 5 minutos).
  Future<bool> enviarCorreoDirectivo(Directivo directivo) async {
    try {
      await FirebaseFirestore.instance.collection('directivos').doc(directivo.id).update({
        'correoInvitacion': 'pendiente',
      });
      _agregarActividad('Invitación a directivo ${directivo.nombre} programada', 'email');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error programando correo directivo: $e');
      return false;
    }
  }

  Future<void> editarDirectivo(Directivo directivo) async {
    if (!isAdmin) return;
    try {
      await FirebaseFirestore.instance.collection('directivos').doc(directivo.id).update({
        'nombre': directivo.nombre, 'cargo': directivo.cargo, 'correo': directivo.correo,
        'facultad': directivo.facultad, 'telefono': directivo.telefono,
      });
    } catch (e) { debugPrint('Error editando directivo: $e'); }
    final index = _directivos.indexWhere((d) => d.id == directivo.id);
    if (index != -1) { _directivos[index] = directivo; _agregarActividad('Directivo actualizado - ${directivo.nombre}', 'user'); notifyListeners(); }
  }

  Future<void> eliminarDirectivo(String id) async {
    if (!isAdmin) return;
    try { await FirebaseFirestore.instance.collection('directivos').doc(id).delete(); } catch (e) { debugPrint('Error: $e'); }
    _directivos.removeWhere((d) => d.id == id);
    _agregarActividad('Directivo eliminado', 'delete');
    notifyListeners();
  }

  Future<void> limpiarDirectivos() async {
    if (!isAdmin) return;
    final cantidad = _directivos.length;
    for (final d in List.from(_directivos)) {
      try { await FirebaseFirestore.instance.collection('directivos').doc(d.id).delete(); } catch (_) {}
    }
    _directivos = [];
    _agregarActividad('Directivos eliminados ($cantidad registros)', 'delete');
    notifyListeners();
  }

  // ── Usuarios CRUD ──
  void agregarUsuario(Usuario usuario) { if (!isAdmin) return; _usuarios.add(usuario); notifyListeners(); }
  void editarUsuario(Usuario usuario) { if (!isAdmin) return; final i = _usuarios.indexWhere((u) => u.id == usuario.id); if (i != -1) { _usuarios[i] = usuario; notifyListeners(); } }
  void eliminarUsuario(String id) { if (!isAdmin) return; _usuarios.removeWhere((u) => u.id == id); notifyListeners(); }

  // ── Códigos QR ya usados ──
  // IMPORTANTE: una invitación sirve para UN solo ingreso, sin importar si
  // el operador leyó el QR o digitó el documento. Para eso `_codigosUsados`
  // se reconstruye con tres fuentes:
  //   1. las validaciones "válidas" del día que llegan desde Firestore
  //      (es lo que hace que las dos tablets se pongan de acuerdo),
  //   2. lo que validó ESTA tablet, que todavía no está sincronizado si no
  //      hay internet,
  //   3. todos los identificadores del mismo invitado (código QR y
  //      documento), para que uno bloquee al otro.
  //
  // LÍMITADO POR DISEÑO: mientras una tablet está sin internet no se entera
  // de lo que validó la otra, así que el mismo QR podría aceptarse en las dos
  // entradas durante ese tiempo. Al reconectarse, ambas reciben las
  // validaciones de la otra y la segunda lectura queda rechazada. Por eso la
  // pantalla de Control de Acceso avisa cuando no hay conexión.
  final Set<String> _codigosUsados = {};
  final Set<String> _codigosValidadosLocalmente = {};
  final Set<String> _codigosValidosDelDia = {};
  StreamSubscription? _validacionesSubscription;
  bool codigoYaUsado(String codigo) => _codigosUsados.contains(codigo);

  /// Bloquea de una vez todos los identificadores de una misma invitación.
  void _marcarComoUsado(List<String> identificadores) {
    for (final id in identificadores) {
      if (id.isNotEmpty) _codigosValidadosLocalmente.add(id);
    }
    _reconstruirCodigosUsados();
  }

  /// Arma `_codigosUsados` a partir de las tres fuentes descritas arriba.
  /// Se vuelve a llamar cada vez que llega una validación, una confirmación
  /// o un directivo, porque recién entonces se puede saber que un documento
  /// y un código QR pertenecen a la misma persona.
  void _reconstruirCodigosUsados() {
    _codigosUsados.clear();
    _codigosUsados.addAll(_codigosValidosDelDia);
    _codigosUsados.addAll(_codigosValidadosLocalmente);

    for (final c in _confirmaciones) {
      final codigoUsado =
          (c.codigoQr != null && _codigosUsados.contains(c.codigoQr)) ||
              (c.documento.isNotEmpty && _codigosUsados.contains(c.documento));
      if (!codigoUsado) continue;
      if (c.codigoQr != null && c.codigoQr!.isNotEmpty) {
        _codigosUsados.add(c.codigoQr!);
      }
      if (c.documento.isNotEmpty) _codigosUsados.add(c.documento);
    }

    for (final d in _directivos) {
      if (d.codigoQr != null &&
          d.codigoQr!.isNotEmpty &&
          _codigosUsados.contains(d.codigoQr)) {
        _codigosUsados.add(d.codigoQr!);
      }
    }
  }

  /// Identifica a quién pertenece un código QR o un documento digitado.
  /// Devuelve null si no corresponde a ningún invitado confirmado de la lista.
  Confirmacion? _confirmacionDe(String codigoODocumento) {
    for (final c in _confirmaciones) {
      if (c.codigoQr == codigoODocumento ||
          (c.documento.isNotEmpty && c.documento == codigoODocumento)) {
        return c;
      }
    }
    return null;
  }

  // ── V-07: escucha en tiempo real de las validaciones del dia ──
  Future<void> _cargarValidacionesDelDia() async {
    _validacionesSubscription?.cancel();
    _codigosValidosDelDia.clear();
    final hoy = DateTime.now();
    final inicio = Timestamp.fromDate(DateTime(hoy.year, hoy.month, hoy.day));

    _validacionesSubscription = FirebaseFirestore.instance
        .collection('validaciones')
        .where('timestamp', isGreaterThanOrEqualTo: inicio)
        .snapshots()
        .listen((snapshot) {
      final validos = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['resultado'] == 'valido') {
          final codigo = data['codigo'] as String?;
          if (codigo != null && codigo.isNotEmpty) validos.add(codigo);
        }
      }
      // Siempre se guarda el código QR del invitado (nunca el documento
      // digitado), así que con un solo identificador alcanza para bloquear
      // al invitado en las dos tablets.
      _codigosValidosDelDia
        ..clear()
        ..addAll(validos);
      _reconstruirCodigosUsados();
      debugPrint('Validaciones sincronizadas: ${_codigosUsados.length}');
    }, onError: (e) => debugPrint('Error escuchando validaciones: $e'));
  }

  // ── Acceso QR (invitados + directivos) ──
  RegistroAcceso? verificarAcceso(String codigoODocumento) {
    if (_codigosUsados.contains(codigoODocumento)) {
      // Ya se usó esta invitación (por QR o por documento). Se guarda el
      // código QR si se puede identificar al invitado: el documento digitado
      // no se registra (minimización de datos).
      final usada = _confirmacionDe(codigoODocumento);
      _guardarValidacionFirestore(
          usada?.codigoQr ?? '', '', 'desconocido', 'usado');
      return null;
    }

    // 1. Buscar en CONFIRMACIONES (invitados registrados con código)
    final confirmacion = _confirmacionDe(codigoODocumento);

    if (confirmacion != null &&
        confirmacion.estado == EstadoConfirmacion.confirmado) {
      // Se bloquean juntos el código QR y el documento: si alguien entró
      // digitando la cédula, el QR de esa misma invitación queda usado
      // (y al revés). Antes cada uno se validaba por su lado y daba dos
      // entradas con la misma invitación.
      _marcarComoUsado(
          [confirmacion.codigoQr ?? '', confirmacion.documento, codigoODocumento]);
      final registro = RegistroAcceso(
        id: 'ACC${DateTime.now().millisecondsSinceEpoch}', nombre: confirmacion.invitado,
        documento: confirmacion.documento, horaAcceso: DateTime.now(), valido: true,
      );
      _registrosAcceso.insert(0, registro);
      _agregarActividad('Acceso registrado - ${confirmacion.invitado} (QR)', 'qr');
      // En `validaciones` SIEMPRE va el código QR: es el identificador único
      // que comparten las dos tablets, sin importar cómo se haya leído.
      _guardarValidacionFirestore(confirmacion.codigoQr ?? codigoODocumento,
          confirmacion.invitado, 'invitado', 'valido');
      notifyListeners();
      return registro;
    }

    // 2. Buscar en DIRECTIVOS
    final directivo = _directivos.firstWhere(
      (d) => d.codigoQr == codigoODocumento,
      orElse: () => Directivo(id: '', nombre: '', cargo: '', correo: '', estado: EstadoDirectivo.pendiente),
    );

    if (directivo.id.isNotEmpty && directivo.estado == EstadoDirectivo.confirmado) {
      _marcarComoUsado([directivo.codigoQr ?? '', codigoODocumento]);
      final registro = RegistroAcceso(
        id: 'ACC${DateTime.now().millisecondsSinceEpoch}',
        nombre: '${directivo.nombre} (${directivo.cargo})',
        documento: directivo.id, horaAcceso: DateTime.now(), valido: true,
      );
      _registrosAcceso.insert(0, registro);
      _agregarActividad('Acceso directivo - ${directivo.nombre} (QR)', 'qr');
      _guardarValidacionFirestore(directivo.codigoQr ?? codigoODocumento,
          directivo.nombre, 'directivo', 'valido');
      notifyListeners();
      return registro;
    }

    // 3. No encontrado. No se guarda el texto ingresado: podria ser una
    // cedula escrita a mano (minimizacion de datos).
    _guardarValidacionFirestore('', '', 'desconocido', 'invalido');
    return null;
  }

  // ── V-07: registro permanente de cada intento de validacion ──
  // Los campos coinciden exactamente con lo que exige la regla de Firestore.
  Future<void> _guardarValidacionFirestore(
      String codigo, String nombre, String tipo, String resultado) async {
    final usuario = _usuarioActual;
    if (usuario == null) return;
    try {
      await FirebaseFirestore.instance.collection('validaciones').add({
        'codigo': codigo,
        'nombre': nombre,
        'tipo': tipo,
        'resultado': resultado,
        'puntoValidacion': (usuario.puntoValidacion ?? '').trim().isEmpty
            ? 'Administracion'
            : (usuario.puntoValidacion ?? '').trim(),
        'operadorId': usuario.id,
        'operadorCorreo': usuario.correo,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error guardando validacion en Firestore: $e');
    }
  }

  void _agregarActividad(String detalle, String tipo) {
    _actividades.insert(0, ActividadReciente(
      id: 'ACT${DateTime.now().millisecondsSinceEpoch}', detalle: detalle,
      usuario: _usuarioActual?.correo ?? 'sistema', hora: DateTime.now(), tipo: tipo,
    ));
    if (_actividades.length > 20) _actividades = _actividades.take(20).toList();
  }

  // ── Correos: los envía el servidor (Apps Script), nunca la app ──
  // Antes la app enviaba cada correo por SMTP con la contraseña de Gmail
  // guardada DENTRO del APK: cualquiera que descomprimiera el APK podía
  // leerla, y el envío dependía de que la tablet siguiera encendida. Ahora
  // la app solo deja UNA petición en `solicitudes_correo` y el servidor la
  // procesa, actualizando `enviados` y `estado`.

  /// Muestra en Notificaciones cómo va cada solicitud de correo.
  void _escucharSolicitudesCorreo() {
    if (!isAdmin) return;
    _solicitudesSubscription?.cancel();
    _solicitudesSubscription = FirebaseFirestore.instance
        .collection('solicitudes_correo')
        .orderBy('fecha', descending: true)
        .snapshots()
        .listen((snapshot) {
      _notificaciones = snapshot.docs.map((doc) {
        final data = doc.data();
        final destinatarios = data['destinatarios'] as String? ?? 'todos';
        final mensaje = (data['mensaje'] as String? ?? '').trim();
        return CampanaNotificacion(
          id: doc.id,
          titulo: data['titulo'] as String? ?? '',
          descripcion: _destinatariosEnTexto(destinatarios) +
              (mensaje.isEmpty ? '' : ' — $mensaje'),
          estado: _estadoDeSolicitud(data['estado'] as String?),
          fechaEnvio: (data['fecha'] as Timestamp?)?.toDate(),
          tasaEntrega: 0,
          // Lo que el servidor ya lleva enviando de esta solicitud.
          totalDestinatarios: (data['enviados'] as num?)?.toInt() ?? 0,
          // Copia del pedido para poder reintentarlo si el servidor falló.
          tipo: data['tipo'] as String? ?? 'campana',
          destinatarios: destinatarios,
          mensaje: mensaje,
          invitadoId: data['invitadoId'] as String?,
          correoOpcional: data['correoOpcional'] as String?,
        );
      }).toList();
      notifyListeners();
    }, onError: (e) => debugPrint('Error escuchando solicitudes de correo: $e'));
  }

  String _destinatariosEnTexto(String destinatarios) {
    switch (destinatarios) {
      case 'confirmados':
        return 'Solo confirmados';
      case 'pendientes':
        return 'Solo pendientes';
      default:
        return 'Todos los invitados';
    }
  }

  EstadoNotificacion _estadoDeSolicitud(String? texto) {
    switch (texto) {
      case 'terminada':
        return EstadoNotificacion.terminada;
      case 'en_proceso':
        return EstadoNotificacion.enProceso;
      case 'error':
        return EstadoNotificacion.rechazado;
      default:
        return EstadoNotificacion.pendiente;
    }
  }

  /// Deja una sola petición de correo para que el servidor la procese.
  /// Los tamaños se recortan aquí porque las reglas de Firestore los exigen.
  Future<void> _solicitarCorreo({
    required String tipo,
    required String titulo,
    required String mensaje,
    required String destinatarios,
    String? invitadoId,
    String? correoOpcional,
  }) async {
    if (!isAdmin) {
      throw StateError('Solo el administrador puede enviar correos.');
    }
    var t = titulo.trim();
    if (t.isEmpty) t = 'Campaña de comunicación';
    if (t.length > 100) t = t.substring(0, 100);

    var m = mensaje.trim();
    if (m.isEmpty) {
      m = 'Te esperamos en la ceremonia de grado de la Universidad de Santander.';
    }
    if (m.length > 1000) m = m.substring(0, 1000);

    await FirebaseFirestore.instance.collection('solicitudes_correo').add({
      'tipo': tipo,
      'titulo': t,
      'mensaje': m,
      'destinatarios': destinatarios,
      if (invitadoId != null && invitadoId.isNotEmpty) 'invitadoId': invitadoId,
      if (correoOpcional != null && correoOpcional.isNotEmpty)
        'correoOpcional': correoOpcional.trim(),
      'estado': 'pendiente',
      'creadoPor': _usuarioActual?.correo ?? '',
      'fecha': FieldValue.serverTimestamp(),
      'enviados': 0,
    });
    await _avisarServidorCorreos();
  }

  /// Pide al servidor que reenvíe la invitación de UN invitado concreto.
  /// Se usa para corregir un correo mal escrito sin borrar la invitación.
  Future<void> solicitarReenvioInvitacion({
    required String invitadoId,
    required String nombre,
    required String correo,
  }) {
    final correoLimpio = correo.trim();
    // Un SOLO validador para todas las capas (formularios, Excel, página
    // pública y reglas de Firestore): validarCorreo() de
    // core/validators/validadores_graduando.dart.
    final errorCorreo = validarCorreo(correoLimpio);
    if (errorCorreo != null) {
      return Future.error(errorCorreo);
    }
    return _solicitarCorreo(
      tipo: 'invitacion',
      titulo: 'Invitación para $nombre',
      mensaje: 'Te invitamos a la ceremonia de grado de la Universidad de '
          'Santander. Encontrarás tu invitación y tu código de acceso en el '
          'enlace que recibiste.',
      destinatarios: 'individual',
      invitadoId: invitadoId,
      correoOpcional: correoLimpio,
    );
  }

  /// Avisa al servidor para que procese la solicitud YA. Si no hay URL
  /// configurada o falla la llamada, no se pierde nada: Apps Script corre
  /// solo cada 5 minutos y la solicitud seguirá en `pendiente`.
  Future<void> _avisarServidorCorreos() async {
    final url = AppConstants.urlEnvioCorreos;
    if (url.isEmpty) return;
    try {
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('No se pudo avisar al servidor de correos: $e');
    }
  }

  Future<void> enviarRecordatorios() async {
    await _solicitarCorreo(
      tipo: 'recordatorio',
      titulo: 'Recordatorio de la ceremonia',
      mensaje: 'Te recordamos tu asistencia a la ceremonia de grado de la '
          'Universidad de Santander. Consulta tu invitación y confirma tu '
          'asistencia.',
      destinatarios: 'todos',
    );
    _agregarActividad('Recordatorio solicitado a los invitados', 'email');
    notifyListeners();
  }

  Future<void> enviarCampana({required String titulo, required String mensaje, required String destinatarios}) async {
    await _solicitarCorreo(
      tipo: 'campana',
      titulo: titulo,
      mensaje: mensaje,
      destinatarios: destinatarios,
    );
    _agregarActividad('Campaña "$titulo" programada', 'email');
    notifyListeners();
  }

  // ── Reenvíos de los correos que manda el servidor ──

  /// Vuelve a poner en cola el correo con el enlace de registro de un
  /// graduando. La app NO manda correos: solo devuelve `correoRegistro` a
  /// 'pendiente' y Apps Script (que revisa cada 5 minutos) lo vuelve a
  /// procesar y escribe 'enviado' o 'error' en el mismo campo.
  Future<bool> reenviarCorreoRegistro(String graduandoId, String nombre) async {
    if (!isAdmin) return false;
    try {
      await FirebaseFirestore.instance
          .collection('graduandos')
          .doc(graduandoId)
          .update({'correoRegistro': 'pendiente'});
      final autor = _usuarioActual;
      if (autor != null) {
        await UsuariosService.auditar(
          autor,
          'Reenvio enlace de registro',
          tipo: 'graduando',
          // Solo el ID: la bitácora no acumula datos personales.
          detalle: 'Graduando $graduandoId',
        );
      }
      _agregarActividad('Reenvío del enlace de registro solicitado - $nombre', 'email');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error reenviando enlace de registro: $e');
      return false;
    }
  }

  /// Reintenta una solicitud de correo que el servidor marcó con `error`.
  /// Las reglas no dejan editar `solicitudes_correo` (su estado solo lo
  /// mueve el servidor), así que el reintento crea OTRA solicitud idéntica
  /// en la cola: es exactamente lo que habría que pedir a mano.
  Future<bool> reintentarCorreo(CampanaNotificacion solicitud) async {
    if (!isAdmin) return false;
    try {
      await _solicitarCorreo(
        tipo: solicitud.tipo,
        titulo: solicitud.titulo,
        mensaje: solicitud.mensaje,
        destinatarios: solicitud.destinatarios,
        invitadoId: solicitud.invitadoId,
        correoOpcional: solicitud.correoOpcional,
      );
      final autor = _usuarioActual;
      if (autor != null) {
        await UsuariosService.auditar(
          autor,
          'Reintento de correo: ${solicitud.titulo}',
          tipo: 'email',
          detalle:
              'Tipo ${solicitud.tipo}; destinatarios ${solicitud.destinatarios}',
        );
      }
      _agregarActividad('Reintento de correo - ${solicitud.titulo}', 'email');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error reintentando correo: $e');
      return false;
    }
  }

  // ── Anulación de invitados (TAREA 6) ──

  /// Anula UN invitado y le devuelve su cupo al graduando, todo en la misma
  /// transacción (o se hace todo o no se hace nada).
  ///
  /// Por qué es una transacción: si se anulara y el cupo se liberara en
  /// pasos separados, una caída a mitad dejaría un invitado anulado con el
  /// cupo ocupado para siempre (nadie más podría usarlo).
  ///
  /// El registro jamás se borra: pasa a `estado: 'anulado'` con su motivo,
  /// que es lo que exige la trazabilidad. El índice `invitados_documentos`
  /// se conserva a propósito: la persona anulada no puede volver a
  /// registrarse por su cuenta para recuperar el cupo.
  ///
  /// Devuelve cuántos cupos quedaron ocupados después de anular.
  Future<int> anularInvitado(Invitacion invitacion, {String motivo = ''}) async {
    if (!isAdmin) {
      throw StateError('Solo el administrador puede anular invitados.');
    }

    var motivoLimpio = motivo.trim();
    if (motivoLimpio.isEmpty) motivoLimpio = 'sin_motivo';
    // La bitácora guarda un solo texto corto; no se arrastra nada más.
    if (motivoLimpio.length > 80) motivoLimpio = motivoLimpio.substring(0, 80);

    final ocupados = await FirestoreService.anularInvitado(
      invitadoId: invitacion.id,
      motivo: motivoLimpio,
    );

    final autor = _usuarioActual;
    if (autor != null) {
      await UsuariosService.auditar(
        autor,
        'Anulo invitado ${invitacion.id}',
        tipo: 'invitacion',
        // Sin nombres ni datos personales en la bitácora: solo el ID y el
        // resultado, que es lo necesario para reconstruir qué pasó.
        detalle: 'Graduando ${invitacion.graduandoId}; cupos ocupados: $ocupados',
      );
    }
    _agregarActividad('Invitado anulado en ${invitacion.graduandoNombre}', 'delete');
    notifyListeners();
    return ocupados;
  }
}