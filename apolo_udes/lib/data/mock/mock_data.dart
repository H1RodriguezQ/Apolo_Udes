import '../models/models.dart';

class MockData {
  // ---- Graduandos (datos de ejemplo, se reemplazan con Firestore) ----
  static List<Graduando> graduandos = [];

  // ---- Invitaciones y confirmaciones vienen de Firestore ----
  static List<Invitacion> invitaciones = [];
  static List<Confirmacion> confirmaciones = [];
  static List<RegistroAcceso> registrosAcceso = [];

  // ---- Notificaciones ----
  static List<CampanaNotificacion> notificaciones = [];

  // ---- Usuarios ----
  static List<Usuario> usuarios = [
    Usuario(
      id: 'USR000',
      nombre: 'Administrador UDES',
      correo: 'admin@udes.edu.co',
      password: 'Admin2026*',
      rol: RolUsuario.administrador,
      estado: EstadoUsuario.activo,
      ultimoAcceso: DateTime(2026, 5, 14, 8, 0),
    ),
    Usuario(
      id: 'USR001',
      nombre: 'Dr. Ricardo Mendoza',
      correo: 'r.mendoza@udes.edu.co',
      password: 'Admin2026*',
      rol: RolUsuario.administrador,
      estado: EstadoUsuario.activo,
      ultimoAcceso: DateTime(2026, 5, 14, 8, 0),
    ),
    Usuario(
      id: 'USR002',
      nombre: 'Ing. Laura García',
      correo: 'l.garcia@udes.edu.co',
      password: 'Admin2026*',
      rol: RolUsuario.administrador,
      estado: EstadoUsuario.activo,
      ultimoAcceso: DateTime(2026, 5, 14, 7, 45),
    ),
    Usuario(
      id: 'USR003',
      nombre: 'Sra. Patricia Rueda',
      correo: 'p.rueda@udes.edu.co',
      password: 'Oper2026*',
      rol: RolUsuario.operador,
      estado: EstadoUsuario.activo,
      ultimoAcceso: DateTime(2026, 5, 14, 8, 15),
    ),
    Usuario(
      id: 'USR004',
      nombre: 'Sr. Jhon Quintero',
      correo: 'j.quintero@udes.edu.co',
      password: 'Oper2026*',
      rol: RolUsuario.operador,
      estado: EstadoUsuario.activo,
      ultimoAcceso: DateTime(2026, 5, 13, 16, 30),
    ),
    Usuario(
      id: 'USR005',
      nombre: 'Sra. Mónica Sandoval',
      correo: 'm.sandoval@udes.edu.co',
      password: 'Oper2026*',
      rol: RolUsuario.operador,
      estado: EstadoUsuario.inactivo,
      ultimoAcceso: DateTime(2026, 5, 1, 12, 0),
    ),
  ];

  // ---- Actividades Recientes ----
  static List<ActividadReciente> actividades = [];

  // ---- Dashboard stats (se calculan desde Firestore) ----
  static Map<String, int> graduandosPorFacultad = {};
  static Map<String, int> estadoConfirmaciones = {};
}