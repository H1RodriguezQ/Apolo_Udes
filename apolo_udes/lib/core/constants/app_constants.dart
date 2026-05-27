class AppConstants {
  static const String appName = 'Apolo UDES';
  static const String appSubtitle = 'Sistema de Gestión de Ceremonia de Grado';
  static const String appVersion = 'v2.4.1 - 2026';
  static const String accessRestricted = 'ACCESO RESTRINGIDO';

  // Routes
  static const String routeLogin = '/login';
  static const String routeDashboard = '/dashboard';
  static const String routeGraduandos = '/graduandos';
  static const String routeInvitaciones = '/invitaciones';
  static const String routeConfirmacion = '/confirmacion';
  static const String routeControlAcceso = '/control-acceso';
  static const String routeNotificaciones = '/notificaciones';
  static const String routeUsuarios = '/usuarios';

  // Sidebar items
  static const List<Map<String, dynamic>> sidebarItems = [
    {'label': 'Dashboard', 'icon': 'dashboard', 'route': routeDashboard},
    {'label': 'Graduandos', 'icon': 'school', 'route': routeGraduandos},
    {'label': 'Invitaciones', 'icon': 'mail', 'route': routeInvitaciones},
    {'label': 'Confirmación', 'icon': 'check_circle', 'route': routeConfirmacion},
    {'label': 'Control de Acceso', 'icon': 'qr_code_scanner', 'route': routeControlAcceso},
    {'label': 'Notificaciones', 'icon': 'notifications', 'route': routeNotificaciones},
    {'label': 'Usuarios', 'icon': 'people', 'route': routeUsuarios},
  ];

  // ── Facultades y programas reales UDES ──
  static const List<String> facultades = [
    'Ciencias Médicas y de la Salud',
    'Ingenierías y Tecnologías',
    'Ciencias Económicas, Administrativas y Contables',
    'Ciencias Exactas, Naturales y Agropecuarias',
    'Ciencias Sociales, Políticas y Humanidades',
  ];

  static const Map<String, List<String>> programasPorFacultad = {
    'Ciencias Médicas y de la Salud': [
      'Medicina',
      'Enfermería',
      'Fisioterapia',
      'Fonoaudiología',
      'Bacteriología y Laboratorio Clínico',
      'Instrumentación Quirúrgica',
      'Terapia Ocupacional',
    ],
    'Ingenierías y Tecnologías': [
      'Ingeniería Civil',
      'Ingeniería Industrial',
      'Ingeniería de Software',
      'Ingeniería Ambiental',
      'Ingeniería en Ciencias de la Computación e Inteligencia Artificial',
      'Ingeniería Agroindustrial',
      'Ingeniería Petroquímica',
    ],
    'Ciencias Económicas, Administrativas y Contables': [
      'Administración de Negocios Internacionales',
      'Administración Financiera',
      'Contaduría Pública',
      'Mercadeo y Publicidad',
    ],
    'Ciencias Exactas, Naturales y Agropecuarias': [
      'Medicina Veterinaria',
      'Microbiología Industrial',
      'Geología',
    ],
    'Ciencias Sociales, Políticas y Humanidades': [
      'Psicología',
      'Derecho',
      'Comunicación Social y Periodismo',
      'Antropología',
      'Licenciatura en Educación Infantil',
    ],
  };

  // Lista plana de todos los programas (para compatibilidad)
  static List<String> get programas => programasPorFacultad.values
      .expand((p) => p)
      .toList()
    ..sort();

  // ── Horas de ceremonia (08:30 AM a 06:00 PM, cada 30 min) ──
  static const List<String> horasCeremonia = [
    '08:30 AM',
    '09:00 AM',
    '09:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '01:00 PM',
    '01:30 PM',
    '02:00 PM',
    '02:30 PM',
    '03:00 PM',
    '03:30 PM',
    '04:00 PM',
    '04:30 PM',
    '05:00 PM',
    '05:30 PM',
    '06:00 PM',
  ];

  // ── Configuración de correo (Gmail SMTP) ──
  static const String emailRemitente = 'apolo.udes@gmail.com';
  static const String emailPassword = 'uaqwqjiwbktuxhky';
  static const String emailNombre = 'Apolo UDES - Universidad de Santander';

  // ── Datos del evento ──
  static const String eventoLugar = 'Auditorio Mayor, Campus Lagos del Cacique';
  static const String eventoDireccion = 'Calle 70 No. 55-210, Bucaramanga';
  static const String eventoCiudad = 'Bucaramanga, Santander';
  static const String eventoInstitucion = 'Universidad de Santander - UDES';
  static const int maxInvitadosPorGraduando = 4;
}