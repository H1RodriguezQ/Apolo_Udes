import '../models/models.dart';

class MockData {
  // ---- Graduandos se cargan SOLO de Firestore ----
  static List<Graduando> graduandos = [];

  // ---- Directivos se cargan desde Firestore ----
  static List<Directivo> directivos = [];

  // ---- Invitaciones y confirmaciones vienen de Firestore ----
  static List<Invitacion> invitaciones = [];
  static List<Confirmacion> confirmaciones = [];
  static List<RegistroAcceso> registrosAcceso = [];

  // ---- Notificaciones ----
  static List<CampanaNotificacion> notificaciones = [];

  // ---- Usuarios se cargan desde Firestore ----
  static List<Usuario> usuarios = [];

  // ---- Actividades Recientes ----
  static List<ActividadReciente> actividades = [];

  // ---- Dashboard stats (se calculan desde Firestore) ----
  static Map<String, int> graduandosPorFacultad = {};
  static Map<String, int> estadoConfirmaciones = {};
}