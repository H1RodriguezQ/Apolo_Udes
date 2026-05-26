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

  // ── Facultades y programas reales UDES Bucaramanga ──
  static const List<String> facultades = [
    'Ciencias de la Salud',
    'Ciencias Económicas y Administrativas',
    'Ingenierías',
    'Ciencias Jurídicas y Sociales',
    'Ciencias Naturales',
  ];

  static const Map<String, List<String>> programasPorFacultad = {
    'Ciencias de la Salud': [
      'Bacteriología y Laboratorio Clínico',
      'Enfermería',
      'Fisioterapia',
      'Fonoaudiología',
      'Instrumentación Quirúrgica',
      'Medicina',
      'Odontología',
      'Psicología',
    ],
    'Ciencias Económicas y Administrativas': [
      'Administración de Empresas',
      'Administración de Negocios Internacionales',
      'Administración Financiera',
      'Contaduría Pública',
      'Economía',
    ],
    'Ingenierías': [
      'Ingeniería Agroindustrial',
      'Ingeniería Ambiental',
      'Ingeniería Civil',
      'Ingeniería en Ciencias de la Computación e Inteligencia Artificial',
      'Ingeniería en Energías',
      'Ingeniería Industrial',
      'Ingeniería Petroquímica',
      'Ingeniería en Software',
    ],
    'Ciencias Jurídicas y Sociales': [
      'Antropología',
      'Comunicación Social y Periodismo',
      'Derecho',
    ],
    'Ciencias Naturales': [
      'Geología',
    ],
  };

  // Lista plana de todos los programas (para compatibilidad)
  static List<String> get programas => programasPorFacultad.values
      .expand((p) => p)
      .toList()
    ..sort();

  // ── Horas de ceremonia (configurables por el admin) ──
  static const List<String> horasCeremonia = [
    '07:00 AM',
    '08:00 AM',
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
  ];

  // ── Configuración de correo (Gmail SMTP) ──
  // IMPORTANTE: reemplaza emailPassword con tu contraseña de aplicación de Google
  // Ve a: myaccount.google.com → Seguridad → Contraseñas de aplicaciones
  static const String emailRemitente = 'apolo.udes@gmail.com';
  static const String emailPassword = 'uaqwqjiwbktuxhky'; //
  static const String emailNombre = 'Apolo UDES - Universidad de Santander';

  // ── Datos del evento ──
  static const String eventoLugar = 'Auditorio Mayor, Campus Lagos del Cacique';
  static const String eventoDireccion = 'Calle 70 No. 55-210, Bucaramanga';
  static const String eventoCiudad = 'Bucaramanga, Santander';
  static const String eventoInstitucion = 'Universidad de Santander - UDES';
  static const int maxInvitadosPorGraduando = 2;
}