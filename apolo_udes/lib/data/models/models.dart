// ============================================================
// MODELS - Apolo UDES
// ============================================================

// ----- Enums -----

enum EstadoGraduando { activo, pendiente, inactivo }

// `anulada` NO es lo mismo que `rechazada`: la rechaza el invitado (él no va),
// la anula la universidad (le quitan el cupo y su QR deja de servir). Estar
// separadas evita contar mal en los indicadores y evita reenviar correos a
// alguien ya anulado.
enum EstadoInvitacion { confirmada, pendiente, enviada, rechazada, anulada }

enum EstadoConfirmacion { confirmado, pendiente, rechazado }

enum EstadoDirectivo { confirmado, pendiente, rechazado }

enum TipoInvitacion { principal, secundaria }

enum RolUsuario { administrador, operador }

enum EstadoUsuario { activo, inactivo }

// Los estados de `solicitudes_correo` que escribe el servidor de correos:
// pendiente (creada) → en_proceso (va a medio camino o le faltó cupo de
// Gmail) → terminada (ya se enviaron todos).
enum EstadoNotificacion { enviado, pendiente, rechazado, enProceso, terminada }

// ----- Extension helpers -----

extension EstadoGraduandoExt on EstadoGraduando {
  String get label {
    switch (this) {
      case EstadoGraduando.activo: return 'Activo';
      case EstadoGraduando.pendiente: return 'Pendiente';
      case EstadoGraduando.inactivo: return 'Inactivo';
    }
  }
}

extension EstadoInvitacionExt on EstadoInvitacion {
  String get label {
    switch (this) {
      case EstadoInvitacion.confirmada: return 'Confirmada';
      case EstadoInvitacion.pendiente: return 'Pendiente';
      case EstadoInvitacion.enviada: return 'Enviada';
      case EstadoInvitacion.rechazada: return 'Rechazada';
      case EstadoInvitacion.anulada: return 'Anulada';
    }
  }
}

extension EstadoConfirmacionExt on EstadoConfirmacion {
  String get label {
    switch (this) {
      case EstadoConfirmacion.confirmado: return 'Confirmado';
      case EstadoConfirmacion.pendiente: return 'Pendiente';
      case EstadoConfirmacion.rechazado: return 'Rechazado';
    }
  }
}

extension EstadoDirectivoExt on EstadoDirectivo {
  String get label {
    switch (this) {
      case EstadoDirectivo.confirmado: return 'Confirmado';
      case EstadoDirectivo.pendiente: return 'Pendiente';
      case EstadoDirectivo.rechazado: return 'Rechazado';
    }
  }
}

extension RolUsuarioExt on RolUsuario {
  String get label {
    switch (this) {
      case RolUsuario.administrador: return 'Administrador';
      case RolUsuario.operador: return 'Operador';
    }
  }

  String get description {
    switch (this) {
      case RolUsuario.administrador: return 'Acceso completo al sistema';
      case RolUsuario.operador: return 'Control de acceso y confirmación en sitio';
    }
  }
}

// ----- Models -----

class Graduando {
  final String id;
  final String codigoEstudiantil;
  final String documento;
  final String nombres;
  final String apellidos;
  final String programa;
  final String facultad;
  final String telefono;
  final String correo;
  final String horaCeremonia;
  final EstadoGraduando estado;
  final String? avatarUrl;

  /// Estado del correo con el enlace de registro que envía el servidor
  /// (Apps Script): 'pendiente' = en cola, 'enviado', 'error'.
  /// `null` cuando el documento todavía no trae el campo (registros
  /// antiguos) y entonces no se pinta ningún badge, para no dar por
  /// enviado un correo que nadie pidió. Solo el servidor lo cambia; la
  /// app únicamente lo devuelve a 'pendiente' para pedir un reenvío.
  final String? correoRegistro;

  Graduando({
    required this.id,
    required this.codigoEstudiantil,
    required this.documento,
    required this.nombres,
    required this.apellidos,
    required this.programa,
    required this.facultad,
    required this.telefono,
    required this.correo,
    required this.horaCeremonia,
    required this.estado,
    this.avatarUrl,
    this.correoRegistro,
  });

  String get nombreCompleto => '$nombres $apellidos';

  Graduando copyWith({
    String? id, String? codigoEstudiantil, String? documento,
    String? nombres, String? apellidos, String? programa,
    String? facultad, String? telefono, String? correo,
    String? horaCeremonia, EstadoGraduando? estado, String? avatarUrl,
    String? correoRegistro,
  }) {
    return Graduando(
      id: id ?? this.id, codigoEstudiantil: codigoEstudiantil ?? this.codigoEstudiantil,
      documento: documento ?? this.documento, nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos, programa: programa ?? this.programa,
      facultad: facultad ?? this.facultad, telefono: telefono ?? this.telefono,
      correo: correo ?? this.correo, horaCeremonia: horaCeremonia ?? this.horaCeremonia,
      estado: estado ?? this.estado, avatarUrl: avatarUrl ?? this.avatarUrl,
      correoRegistro: correoRegistro ?? this.correoRegistro,
    );
  }
}

class Invitacion {
  final String id;
  final String invitado;
  final String graduandoId;
  final String graduandoNombre;
  final TipoInvitacion tipo;
  final EstadoInvitacion estado;
  final DateTime? fechaEnvio;
  final String? codigoQr;

  Invitacion({
    required this.id, required this.invitado, required this.graduandoId,
    required this.graduandoNombre, required this.tipo, required this.estado,
    this.fechaEnvio, this.codigoQr,
  });
}

class Confirmacion {
  final String id;
  final String invitado;
  final String documento;
  final String graduandoNombre;
  final EstadoConfirmacion estado;
  final String? codigoQr;

  Confirmacion({
    required this.id, required this.invitado, required this.documento,
    required this.graduandoNombre, required this.estado, this.codigoQr,
  });
}

class Directivo {
  final String id;
  final String nombre;
  final String cargo;
  final String correo;
  final String? facultad;
  final String? telefono;
  final EstadoDirectivo estado;
  final DateTime? fechaConfirmacion;
  final String? codigoQr; // 🆕 QR para acceso

  /// Estado del correo de invitación que envía el servidor (Apps Script):
  /// 'pendiente' = en cola, 'enviado', 'error'. `null` si el documento aún
  /// no lo trae (registros antiguos): en ese caso no se pinta badge.
  final String? correoInvitacion;

  Directivo({
    required this.id,
    required this.nombre,
    required this.cargo,
    required this.correo,
    this.facultad,
    this.telefono,
    required this.estado,
    this.fechaConfirmacion,
    this.codigoQr,
    this.correoInvitacion,
  });

  Directivo copyWith({
    String? id, String? nombre, String? cargo, String? correo,
    String? facultad, String? telefono, EstadoDirectivo? estado,
    DateTime? fechaConfirmacion, String? codigoQr, String? correoInvitacion,
  }) {
    return Directivo(
      id: id ?? this.id, nombre: nombre ?? this.nombre,
      cargo: cargo ?? this.cargo, correo: correo ?? this.correo,
      facultad: facultad ?? this.facultad, telefono: telefono ?? this.telefono,
      estado: estado ?? this.estado, fechaConfirmacion: fechaConfirmacion ?? this.fechaConfirmacion,
      codigoQr: codigoQr ?? this.codigoQr,
      correoInvitacion: correoInvitacion ?? this.correoInvitacion,
    );
  }
}

class RegistroAcceso {
  final String id;
  final String nombre;
  final String documento;
  final DateTime horaAcceso;
  final bool valido;

  RegistroAcceso({
    required this.id, required this.nombre, required this.documento,
    required this.horaAcceso, required this.valido,
  });
}

class CampanaNotificacion {
  final String id;
  final String titulo;
  final String descripcion;
  final EstadoNotificacion estado;
  final DateTime? fechaEnvio;
  final double tasaEntrega;
  final int totalDestinatarios;

  // Copia exacta de los campos que la petición de correo tiene en Firestore.
  // Se conservan para poder REINTENTAR una solicitud fallida: las reglas no
  // dejan editar `solicitudes_correo` (solo el servidor avanza su estado),
  // así que el reintento crea otra solicitud idéntica en la cola.
  final String tipo;
  final String destinatarios;
  final String mensaje;
  final String? invitadoId;
  final String? correoOpcional;

  CampanaNotificacion({
    required this.id, required this.titulo, required this.descripcion,
    required this.estado, this.fechaEnvio, required this.tasaEntrega,
    required this.totalDestinatarios,
    this.tipo = 'campana', this.destinatarios = 'todos', this.mensaje = '',
    this.invitadoId, this.correoOpcional,
  });
}

class Usuario {
  final String id;
  final String nombre;
  final String correo;
  final String password;
  final RolUsuario rol;
  final EstadoUsuario estado;
  final DateTime ultimoAcceso;
  final String? puntoValidacion;

  Usuario({
    required this.id, required this.nombre, required this.correo,
    required this.password, required this.rol, required this.estado,
    required this.ultimoAcceso, this.puntoValidacion,
  });

  Usuario copyWith({
    String? id, String? nombre, String? correo, String? password,
    RolUsuario? rol, EstadoUsuario? estado, DateTime? ultimoAcceso,
    String? puntoValidacion,
  }) {
    return Usuario(
      id: id ?? this.id, nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo, password: password ?? this.password,
      rol: rol ?? this.rol, estado: estado ?? this.estado,
      ultimoAcceso: ultimoAcceso ?? this.ultimoAcceso,
      puntoValidacion: puntoValidacion ?? this.puntoValidacion,
    );
  }
}

class ActividadReciente {
  final String id;
  final String detalle;
  final String usuario;
  final DateTime hora;
  final String tipo;

  ActividadReciente({
    required this.id, required this.detalle, required this.usuario,
    required this.hora, required this.tipo,
  });
}