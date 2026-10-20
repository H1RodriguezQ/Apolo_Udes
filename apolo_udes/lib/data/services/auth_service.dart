import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../firebase_options.dart';
import '../models/models.dart';

/// Autenticacion contra Firebase Auth.
///
/// El rol NO se decide en el cliente: se lee del documento `usuarios/{uid}`,
/// que solo un administrador puede escribir (lo garantizan las reglas de
/// Firestore). Una cuenta sin perfil, o con perfil inactivo, no puede entrar.
class AuthService {
  AuthService._();

  static final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static fb.User? get usuarioFirebase => _auth.currentUser;

  static Stream<fb.User?> get cambiosDeSesion => _auth.authStateChanges();

  /// Autentica al usuario y devuelve su perfil con el rol tomado de Firestore.
  static Future<Usuario> iniciarSesion(String correo, String password) async {
    fb.UserCredential credencial;

    try {
      credencial = await _auth.signInWithEmailAndPassword(
        email: correo.trim().toLowerCase(),
        password: password,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mensajeDeError(e.code));
    } catch (e) {
      debugPrint('Error de autenticacion: $e');
      throw AuthException('No fue posible iniciar sesion. Intenta mas tarde.');
    }

    final user = credencial.user;
    if (user == null) {
      throw AuthException('No fue posible iniciar sesion.');
    }

    try {
      return await _perfilDesdeFirestore(user);
    } on AuthException {
      await _auth.signOut();
      rethrow;
    }
  }

  /// Reconstruye el perfil de una sesion existente al reabrir la app.
  static Future<Usuario?> sesionActual() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      return await _perfilDesdeFirestore(user);
    } on AuthException {
      await _auth.signOut();
      return null;
    } catch (e) {
      debugPrint('Sesion no recuperable: $e');
      return null;
    }
  }

  static Future<Usuario> _perfilDesdeFirestore(fb.User user) async {
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _db.collection('usuarios').doc(user.uid).get();
    } catch (e) {
      debugPrint('Error leyendo perfil: $e');
      throw AuthException('No fue posible verificar tu cuenta. Intenta mas tarde.');
    }

    if (!doc.exists) {
      throw AuthException(
        'Tu cuenta no tiene un rol asignado. Solicita acceso al administrador.',
      );
    }

    final data = doc.data()!;

    final estado = data['estado'] as String? ?? 'activo';
    if (estado != 'activo') {
      throw AuthException('Tu cuenta esta desactivada. Contacta al administrador.');
    }

    final rol = _rolDesdeTexto(data['rol'] as String? ?? '');
    if (rol == null) {
      throw AuthException('Tu cuenta tiene un rol no reconocido.');
    }

    final nombreDoc = (data['nombre'] as String?)?.trim() ?? '';
    final correo = user.email ?? (data['correo'] as String? ?? '');

    return Usuario(
      id: user.uid,
      nombre: nombreDoc.isNotEmpty ? nombreDoc : correo.split('@').first,
      correo: correo,
      password: '',
      rol: rol,
      estado: EstadoUsuario.activo,
      ultimoAcceso: DateTime.now(),
      puntoValidacion: data['puntoValidacion'] as String?,
    );
  }

  /// Punto de validacion asignado al usuario actual.
  static Future<String?> puntoValidacion() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _db.collection('usuarios').doc(user.uid).get();
      return doc.data()?['puntoValidacion'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> cerrarSesion() => _auth.signOut();

  /// Envia el correo de restablecimiento. No revela si la cuenta existe.
  static Future<void> recuperarContrasena(String correo) async {
    try {
      await _auth.setLanguageCode('es');
      await _auth.sendPasswordResetEmail(email: correo.trim().toLowerCase());
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      throw AuthException(_mensajeDeError(e.code));
    }
  }

  /// Crea una cuenta en Firebase Auth SIN cerrar la sesion del administrador.
  ///
  /// Usa una instancia secundaria de Firebase: crear un usuario con la
  /// instancia principal iniciaria sesion con la cuenta nueva y sacaria al
  /// administrador. La contrasena es aleatoria y nadie la conoce; el usuario
  /// define la suya con el correo de activacion.
  static Future<String> crearCuenta(String correo) async {
    final email = correo.trim().toLowerCase();
    final app = await Firebase.initializeApp(
      name: 'registro-${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final authSecundaria = fb.FirebaseAuth.instanceFor(app: app);
      final cred = await authSecundaria.createUserWithEmailAndPassword(
        email: email,
        password: _contrasenaAleatoria(),
      );
      final uid = cred.user!.uid;
      await authSecundaria.signOut();
      return uid;
    } on fb.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw AuthException('Ya existe una cuenta con ese correo.');
        case 'invalid-email':
          throw AuthException('El correo no es valido.');
        default:
          throw AuthException('No fue posible crear la cuenta (${e.code}).');
      }
    } finally {
      await app.delete();
    }
  }

  /// Envia al usuario el correo para que defina su propia contrasena.
  static Future<void> enviarCorreoActivacion(String correo) async {
    await _auth.setLanguageCode('es');
    await _auth.sendPasswordResetEmail(email: correo.trim().toLowerCase());
  }

  static String _contrasenaAleatoria() {
    const alfabeto =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!#%*+-_';
    final r = Random.secure();
    return List.generate(32, (_) => alfabeto[r.nextInt(alfabeto.length)]).join();
  }

  static RolUsuario? _rolDesdeTexto(String rol) {
    switch (rol) {
      case 'admin':
        return RolUsuario.administrador;
      case 'operador':
      case 'consulta':
        return RolUsuario.operador;
      default:
        return null;
    }
  }

  /// Mensajes genericos: no distinguen correo inexistente de contrasena
  /// incorrecta, para no facilitar la enumeracion de cuentas.
  static String _mensajeDeError(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'Correo o contrasena incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta esta deshabilitada. Contacta al administrador.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Intenta de nuevo en unos minutos.';
      case 'network-request-failed':
        return 'Sin conexion. Verifica tu red e intenta de nuevo.';
      default:
        return 'No fue posible iniciar sesion. Intenta mas tarde.';
    }
  }
}

class AuthException implements Exception {
  final String mensaje;
  AuthException(this.mensaje);

  @override
  String toString() => mensaje;
}