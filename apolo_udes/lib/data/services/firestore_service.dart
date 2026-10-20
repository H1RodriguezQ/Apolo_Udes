import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference get _graduandos => _db.collection('graduandos');
  static CollectionReference get _invitados => _db.collection('invitados');
  static CollectionReference get _cupos => _db.collection('cupos');

  /// Espejo público de graduandos: solo los campos que la página pública
  /// necesita mostrar, sin documento, teléfono ni correo.
  static CollectionReference get _graduandosPublico =>
      _db.collection('graduandos_publico');

  /// Invitados que puede registrar cada graduando por defecto (RF-11).
  static const int invitadosBase = 2;

  // ---------------------------------------------------------------------------
  // Códigos de acceso
  // ---------------------------------------------------------------------------

  static final _rnd = Random.secure();
  static const _alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Genera un código de acceso aleatorio de 128 bits de entropía.
  /// El alfabeto omite caracteres que se confunden al leerlos (I, O, 0, 1).
  static String generarCodigoAcceso({String prefijo = 'INV'}) {
    final buffer = StringBuffer(prefijo)..write('-');
    for (var i = 0; i < 26; i++) {
      if (i > 0 && i % 6 == 0) buffer.write('-');
      buffer.write(_alfabeto[_rnd.nextInt(_alfabeto.length)]);
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Graduandos
  // ---------------------------------------------------------------------------

  /// Guarda el graduando y su espejo público en una sola operación atómica.
  static Future<void> guardarGraduando(Graduando g) async {
    final lote = _db.batch();

    lote.set(_graduandos.doc(g.id), {
      'id': g.id,
      'nombres': g.nombres,
      'apellidos': g.apellidos,
      'nombreCompleto': g.nombreCompleto,
      'documento': g.documento,
      'codigoEstudiantil': g.codigoEstudiantil,
      'programa': g.programa,
      'facultad': g.facultad,
      'correo': g.correo,
      'telefono': g.telefono,
      'horaCeremonia': g.horaCeremonia,
      'estado': g.estado.name,
      'fechaRegistro': FieldValue.serverTimestamp(),
      'invitadosRegistrados': false,
      'invitadosPermitidos': invitadosBase,
      // Apps Script envía el correo con el enlace de registro a todos los
      // graduandos que están en "pendiente" (revisa cada 5 minutos).
      'correoRegistro': 'pendiente', // ← NUEVO
    });

    lote.set(
      _graduandosPublico.doc(g.id),
      {
        'nombreCompleto': g.nombreCompleto,
        'programa': g.programa,
        'facultad': g.facultad,
        'invitadosPermitidos': invitadosBase,
      },
      // merge: no se borran los campos que ya traía el espejo público
      // (sobre todo `cuposUsados`, que lo sube la página pública).
      SetOptions(merge: true),
    );

    await lote.commit();
  }

  /// Actualiza los datos de un graduando existente y su espejo público.
  /// A diferencia de `guardarGraduando`, no toca `invitadosPermitidos` ni la
  /// fecha de registro, así que no borra un invitado adicional autorizado.
  static Future<void> actualizarGraduando(Graduando g) async {
    final lote = _db.batch();
    lote.update(_graduandos.doc(g.id), {
      'nombres': g.nombres,
      'apellidos': g.apellidos,
      'nombreCompleto': g.nombreCompleto,
      'documento': g.documento,
      'codigoEstudiantil': g.codigoEstudiantil,
      'programa': g.programa,
      'facultad': g.facultad,
      'correo': g.correo,
      'telefono': g.telefono,
      'horaCeremonia': g.horaCeremonia,
    });
    lote.set(
      _graduandosPublico.doc(g.id),
      {
        'nombreCompleto': g.nombreCompleto,
        'programa': g.programa,
        'facultad': g.facultad,
      },
      SetOptions(merge: true),
    );
    await lote.commit();
  }

  /// Datos con los que se marca un invitado anulado. El invitado NO se borra:
  /// queda el registro (trazabilidad), pero su QR deja de ser válido.
  static Map<String, dynamic> _datosAnulacion(String motivo) => {
        'estado': 'anulado',
        'anuladoMotivo': motivo,
        'fechaAnulacion': FieldValue.serverTimestamp(),
      };

  /// Anula UN invitado y le devuelve su cupo al graduando en UNA transacción.
  ///
  /// Por qué todo junto: si se anulara primero y el cupo se liberara después,
  /// una caída a mitad dejaría el cupo ocupado para siempre (nadie más podría
  /// usarlo). Aquí o pasan las dos cosas o no pasa ninguna.
  ///
  /// Al liberarse un cupo del medio (1, 2 o 3), los restantes se **renumeran**
  /// para que no quede ningún hueco sin usar: se reescriben los documentos de
  /// `cupos` (su ID lleva el número dentro) y se actualiza el `cupo` que
  /// declara cada invitado afectado, en la misma transacción.
  ///
  /// Devuelve la cantidad de cupos ocupados después de anular.
  static Future<int> anularInvitado({
    required String invitadoId,
    required String motivo,
  }) {
    return _db.runTransaction((tx) async {
      final snap = await tx.get(_invitados.doc(invitadoId));
      if (!snap.exists) throw StateError('El invitado ya no existe.');
      final datos = snap.data() as Map<String, dynamic>;
      // Ya estaba anulado: no se repite la operación ni se tocan los cupos.
      if (datos['estado'] == 'anulado') return 0;

      final graduandoId = (datos['graduandoId'] as String?) ?? '';
      if (graduandoId.isEmpty) {
        throw StateError('El invitado no tiene graduando asociado.');
      }
      final cupoAnulado = datos['cupo'] is int ? datos['cupo'] as int : 0;

      // RF-11a: como máximo hay 3 cupos, se leen directamente por ID (1, 2 y
      // 3) en vez de hacer una consulta: la transacción queda con lecturas
      // deterministas y reintentos limpios.
      final cupos = <int, String>{}; // número de cupo -> invitado que lo usa
      for (var n = 1; n <= 3; n++) {
        final c = await tx.get(_cupos.doc('${graduandoId}_$n'));
        if (!c.exists) continue;
        final usadoPor =
            (c.data() as Map<String, dynamic>)['invitadoId'] as String? ?? '';
        // El cupo del que se va queda vacío; los demás se van a renumerar.
        if (usadoPor.isEmpty || usadoPor == invitadoId) continue;
        cupos[n] = usadoPor;
      }

      // Se cierran los huecos: cada cupo existente baja al primer número
      // libre, en orden.
      final numeros = cupos.keys.toList()..sort();
      final mover = <int, int>{}; // número actual -> número nuevo
      var destino = 1;
      for (final origen in numeros) {
        if (origen != destino) mover[origen] = destino;
        destino++;
      }
      final ocupados = destino - 1;
      final destinos = mover.values.toSet();

      for (final e in mover.entries) {
        final nuevoRef = _cupos.doc('${graduandoId}_${e.value}');
        // Si ese número acaba de liberarse, el `set` lo reescribe; si no,
        // lo crea. Nunca se escribe y se borra el mismo ID en una transacción.
        tx.set(nuevoRef, {
          'graduandoId': graduandoId,
          'invitadoId': cupos[e.key]!,
          'numero': e.value,
        });
        // Cada invitado tiene que saber en qué cupo quedó.
        tx.update(_invitados.doc(cupos[e.key]!), {'cupo': e.value});
      }
      // Los números que quedaron sin dueño y que nadie reutilizó, se borran.
      for (final origen in mover.keys.where((o) => !destinos.contains(o))) {
        tx.delete(_cupos.doc('${graduandoId}_$origen'));
      }
      // El cupo que dejó libre el invitado anulado: si nadie lo tomó, se borra.
      if (cupoAnulado >= 1 && !destinos.contains(cupoAnulado)) {
        tx.delete(_cupos.doc('${graduandoId}_$cupoAnulado'));
      }

      tx.update(_invitados.doc(invitadoId), _datosAnulacion(motivo));

      // El contador público queda en el número REAL de cupos ocupados; es lo
      // que la página pública usa para decir cuántos cupos siguen libres.
      final pub = await tx.get(_graduandosPublico.doc(graduandoId));
      if (pub.exists) {
        tx.update(_graduandosPublico.doc(graduandoId), {'cuposUsados': ocupados});
      }
      return ocupados;
    });
  }

  /// Elimina el graduando y su espejo, y ANULA a sus invitados.
  static Future<int> eliminarGraduando(String id) async {
    final invitados = await _invitados.where('graduandoId', isEqualTo: id).get();
    final lote = _db.batch();
    lote.delete(_graduandos.doc(id));
    lote.delete(_graduandosPublico.doc(id));
    for (final inv in invitados.docs) {
      lote.update(inv.reference, _datosAnulacion('graduando_eliminado'));
    }
    await lote.commit();
    return invitados.docs.length;
  }

  /// Elimina TODOS los graduandos (y sus espejos) y anula a todos los
  /// invitados. En lotes de 400 porque Firestore admite máximo 500 por lote.
  static Future<int> eliminarTodosGraduandos() async {
    final graduandos = await _graduandos.get();
    final invitados = await _invitados.get();

    final operaciones = <void Function(WriteBatch)>[
      for (final g in graduandos.docs) ...[
        (b) => b.delete(g.reference),
        (b) => b.delete(_graduandosPublico.doc(g.id)),
      ],
      for (final inv in invitados.docs)
        if ((inv.data() as Map<String, dynamic>)['estado'] != 'anulado')
          (b) => b.update(inv.reference, _datosAnulacion('graduandos_eliminados')),
    ];

    for (var i = 0; i < operaciones.length; i += 400) {
      final lote = _db.batch();
      for (final op in operaciones.skip(i).take(400)) {
        op(lote);
      }
      await lote.commit();
    }
    return graduandos.docs.length;
  }

  static Future<List<Map<String, dynamic>>> obtenerGraduandos() async {
    final snapshot = await _graduandos.get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  // ---------------------------------------------------------------------------
  // Invitado adicional (RF-11a)
  // ---------------------------------------------------------------------------

  /// IDs de los graduandos que tienen autorizado un invitado adicional.
  static Stream<Set<String>> escucharGraduandosConExtra() {
    return _graduandos
        .where('invitadosPermitidos', isGreaterThan: invitadosBase)
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  /// Autoriza un invitado adicional: el límite pasa de 2 a 3.
  static Future<void> autorizarInvitadoExtra({
    required String graduandoId,
    required String motivo,
    required String autorCorreo,
  }) async {
    final lote = _db.batch();
    lote.update(_graduandos.doc(graduandoId), {
      'invitadosPermitidos': invitadosBase + 1,
      'extraMotivo': motivo,
      'extraAutorizadoPor': autorCorreo,
      'extraFecha': FieldValue.serverTimestamp(),
    });
    lote.set(
      _graduandosPublico.doc(graduandoId),
      {'invitadosPermitidos': invitadosBase + 1},
      SetOptions(merge: true),
    );
    await lote.commit();
  }

  /// Revoca el invitado adicional. Devuelve `false` si el tercer cupo ya está
  /// ocupado.
  static Future<bool> revocarInvitadoExtra(String graduandoId) async {
    final cupoExtra = _cupos.doc('${graduandoId}_${invitadosBase + 1}');
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(cupoExtra);
      if (snap.exists) return false;

      tx.update(_graduandos.doc(graduandoId), {
        'invitadosPermitidos': invitadosBase,
        'extraMotivo': FieldValue.delete(),
        'extraAutorizadoPor': FieldValue.delete(),
        'extraFecha': FieldValue.delete(),
      });
      tx.set(
        _graduandosPublico.doc(graduandoId),
        {'invitadosPermitidos': invitadosBase},
        SetOptions(merge: true),
      );
      return true;
    });
  }

  // ---------------------------------------------------------------------------
  // Invitados
  // ---------------------------------------------------------------------------

  static Stream<QuerySnapshot> escucharInvitados(String graduandoId) {
    return _invitados.where('graduandoId', isEqualTo: graduandoId).snapshots();
  }

  static Stream<QuerySnapshot> escucharTodosInvitados() {
    return _invitados.orderBy('fechaRegistro', descending: true).snapshots();
  }

  static Stream<QuerySnapshot> escucharConfirmaciones() {
    return _invitados
        .where('confirmacion', whereIn: ['confirmado', 'rechazado']).snapshots();
  }

  static Future<void> confirmarAsistencia({
    required String graduandoId,
    required String nombreInvitado,
    required String documento,
    required String correoInvitado,
    required String tipo,
  }) async {
    // V-08: ID aleatorio de Firestore (antes 'INV' + milisegundos).
    final ref = _invitados.doc();
    await ref.set({
      'id': ref.id,
      'graduandoId': graduandoId,
      'nombreInvitado': nombreInvitado,
      'documento': documento,
      'correoInvitado': correoInvitado,
      'tipo': tipo,
      'estado': 'pendiente',
      'fechaRegistro': FieldValue.serverTimestamp(),
      'codigoQr': generarCodigoAcceso(),
    });
  }

  /// Asigna el código de acceso a un invitado registrado desde la página
  /// pública. El código lo genera la aplicación administrativa, nunca el
  /// cliente.
  static Future<String> asignarCodigoQr(String invitadoId) async {
    final codigo = generarCodigoAcceso();
    await _invitados.doc(invitadoId).update({'codigoQr': codigo});
    return codigo;
  }
}
