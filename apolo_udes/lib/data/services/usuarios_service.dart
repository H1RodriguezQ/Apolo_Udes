import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'auth_service.dart';

/// Gestion de usuarios desde la aplicacion (plan Spark, sin Cloud Functions).
///
/// - La cuenta se crea en Firebase Auth con una contrasena aleatoria que nadie
///   conoce; el usuario define la suya con el correo de activacion.
/// - El rol vive en usuarios/{uid}. Solo un administrador puede escribirlo.
/// - "Eliminar" marca el perfil como 'eliminado': pierde el acceso de
///   inmediato y el correo puede reactivarse despues.
/// - Cada accion queda en la coleccion `auditoria` (solo insercion).
class UsuariosService {
  UsuariosService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _usuarios =>
      _db.collection('usuarios');

  static String rolATexto(RolUsuario rol) =>
      rol == RolUsuario.administrador ? 'admin' : 'operador';

  /// Crea (o reactiva) un usuario. Devuelve true si fue una reactivacion.
  static Future<bool> crear({
    required String nombre,
    required String correo,
    required RolUsuario rol,
    String? puntoValidacion,
    required Usuario autor,
  }) async {
    final email = correo.trim().toLowerCase();
    final rolTexto = rolATexto(rol);
    final perfil = <String, dynamic>{
      'nombre': nombre.trim(),
      'correo': email,
      'rol': rolTexto,
      'puntoValidacion': rol == RolUsuario.operador ? puntoValidacion?.trim() : null,
      'estado': 'activo',
      'ultimaActualizacion': FieldValue.serverTimestamp(),
      'actualizadoPor': autor.id,
    };

    // Si el correo ya tuvo un perfil que fue eliminado, se reactiva.
    final existentes =
        await _usuarios.where('correo', isEqualTo: email).limit(1).get();
    if (existentes.docs.isNotEmpty) {
      final doc = existentes.docs.first;
      final estado = doc.data()['estado'] as String? ?? 'activo';
      if (estado != 'eliminado') {
        throw AuthException('Ya existe un usuario con ese correo.');
      }
      await doc.reference.set(perfil, SetOptions(merge: true));
      await AuthService.enviarCorreoActivacion(email);
      await auditar(autor, 'Reactivo usuario $email como $rolTexto');
      return true;
    }

    final uid = await AuthService.crearCuenta(email);
    await _usuarios.doc(uid).set({
      ...perfil,
      'uid': uid,
      'creadoEn': FieldValue.serverTimestamp(),
      'creadoPor': autor.id,
    });
    await AuthService.enviarCorreoActivacion(email);
    await auditar(autor, 'Creo usuario $email como $rolTexto');
    return false;
  }

  static Future<void> editar({
    required Usuario usuario,
    required String nombre,
    required RolUsuario rol,
    String? puntoValidacion,
    required EstadoUsuario estado,
    required Usuario autor,
  }) async {
    final rolTexto = rolATexto(rol);
    await _usuarios.doc(usuario.id).set({
      'nombre': nombre.trim(),
      'correo': usuario.correo,
      'rol': rolTexto,
      'puntoValidacion': rol == RolUsuario.operador ? puntoValidacion?.trim() : null,
      'estado': estado == EstadoUsuario.activo ? 'activo' : 'inactivo',
      'ultimaActualizacion': FieldValue.serverTimestamp(),
      'actualizadoPor': autor.id,
    }, SetOptions(merge: true));
    await auditar(autor,
        'Edito usuario ${usuario.correo}: rol $rolTexto, ${estado == EstadoUsuario.activo ? 'activo' : 'inactivo'}');
  }

  static Future<void> eliminar({
    required Usuario usuario,
    required Usuario autor,
  }) async {
    if (usuario.id == autor.id) {
      throw AuthException('No puedes eliminar tu propia cuenta.');
    }
    await _usuarios.doc(usuario.id).set({
      'correo': usuario.correo,
      'rol': usuario.rol == RolUsuario.administrador ? 'admin' : 'operador',
      'puntoValidacion': usuario.puntoValidacion,
      'estado': 'eliminado',
      'ultimaActualizacion': FieldValue.serverTimestamp(),
      'actualizadoPor': autor.id,
    }, SetOptions(merge: true));
    await auditar(autor, 'Elimino usuario ${usuario.correo}');
  }

  static Future<void> reenviarActivacion({
    required Usuario usuario,
    required Usuario autor,
  }) async {
    await AuthService.enviarCorreoActivacion(usuario.correo);
    await auditar(autor, 'Reenvio correo de activacion a ${usuario.correo}');
  }

  /// Registro en la bitacora. Autor y fecha los verifica la regla.
  static Future<void> auditar(Usuario autor, String accion,
      {String tipo = 'usuario', String detalle = ''}) async {
    try {
      await _db.collection('auditoria').add({
        'autorId': autor.id,
        'autorCorreo': autor.correo,
        'autorRol': rolATexto(autor.rol),
        'accion': accion.length > 200 ? accion.substring(0, 200) : accion,
        'detalle': detalle,
        'tipo': tipo,
        'fecha': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // La bitacora nunca debe impedir la operacion principal.
    }
  }
}