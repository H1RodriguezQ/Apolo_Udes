import '../models/models.dart';

class MockData {
  // ---- Graduandos se cargan SOLO de Firestore ----
  static List<Graduando> graduandos = [];

  // ---- Directivos ----
  static List<Directivo> directivos = [
    Directivo(
      id: 'DIR001',
      nombre: 'Dr. Jaime Ramírez Gómez',
      cargo: 'Rector General',
      correo: 'j.ramirez@udes.edu.co',
      facultad: null,
      telefono: '3001111111',
      estado: EstadoDirectivo.pendiente,
      fechaConfirmacion: null,
    ),
    Directivo(
      id: 'DIR002',
      nombre: 'Dra. Sandra Martínez López',
      cargo: 'Vicerrectora Académica',
      correo: 's.martinez@udes.edu.co',
      facultad: null,
      telefono: '3002222222',
      estado: EstadoDirectivo.pendiente,
      fechaConfirmacion: null,
    ),
    Directivo(
      id: 'DIR003',
      nombre: 'Ing. Roberto Soto Silva',
      cargo: 'Vicerrector de Administración',
      correo: 'r.soto@udes.edu.co',
      facultad: null,
      telefono: '3003333333',
      estado: EstadoDirectivo.pendiente,
      fechaConfirmacion: null,
    ),
    Directivo(
      id: 'DIR004',
      nombre: 'Dr. Carlos Mendez Ruiz',
      cargo: 'Decano',
      correo: 'c.mendez@udes.edu.co',
      facultad: 'Ingenierías y Tecnologías',
      telefono: '3004444444',
      estado: EstadoDirectivo.confirmado,
      fechaConfirmacion: DateTime(2026, 5, 20),
    ),
    Directivo(
      id: 'DIR005',
      nombre: 'Dra. María Rodríguez Torres',
      cargo: 'Decana',
      correo: 'm.rodriguez@udes.edu.co',
      facultad: 'Ciencias Médicas y de la Salud',
      telefono: '3005555555',
      estado: EstadoDirectivo.pendiente,
      fechaConfirmacion: null,
    ),
    Directivo(
      id: 'DIR006',
      nombre: 'Ing. Fernando García Pérez',
      cargo: 'Decano',
      correo: 'f.garcia@udes.edu.co',
      facultad: 'Ciencias Económicas, Administrativas y Contables',
      telefono: '3006666666',
      estado: EstadoDirectivo.rechazado,
      fechaConfirmacion: DateTime(2026, 5, 21),
    ),
    Directivo(
      id: 'DIR007',
      nombre: 'Dra. Luz Elena Sánchez Vega',
      cargo: 'Decana',
      correo: 'l.sanchez@udes.edu.co',
      facultad: 'Ciencias Sociales, Humanidades y Educación',
      telefono: '3007777777',
      estado: EstadoDirectivo.pendiente,
      fechaConfirmacion: null,
    ),
  ];

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