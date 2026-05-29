// ============================================================
// MODELS - Apolo UDES
// ============================================================

// ----- Enums -----

enum EstadoGraduando { activo, pendiente, inactivo }

enum EstadoInvitacion { confirmada, pendiente, enviada, rechazada }

enum EstadoConfirmacion { confirmado, pendiente, rechazado }

enum EstadoDirectivo { confirmado, pendiente, rechazado }

enum TipoInvitacion { principal, secundaria }

enum RolUsuario { administrador, operador }

enum EstadoUsuario { activo, inactivo }

enum EstadoNotificacion { enviado, pendiente, rechazado }

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
  });

  String get nombreCompleto => '$nombres $apellidos';

  Graduando copyWith({
    String? id, String? codigoEstudiantil, String? documento,
    String? nombres, String? apellidos, String? programa,
    String? facultad, String? telefono, String? correo,
    String? horaCeremonia, EstadoGraduando? estado, String? avatarUrl,
  }) {
    return Graduando(
      id: id ?? this.id, codigoEstudiantil: codigoEstudiantil ?? this.codigoEstudiantil,
      documento: documento ?? this.documento, nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos, programa: programa ?? this.programa,
      facultad: facultad ?? this.facultad, telefono: telefono ?? this.telefono,
      correo: correo ?? this.correo, horaCeremonia: horaCeremonia ?? this.horaCeremonia,
      estado: estado ?? this.estado, avatarUrl: avatarUrl ?? this.avatarUrl,
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
  });

  Directivo copyWith({
    String? id, String? nombre, String? cargo, String? correo,
    String? facultad, String? telefono, EstadoDirectivo? estado,
    DateTime? fechaConfirmacion, String? codigoQr,
  }) {
    return Directivo(
      id: id ?? this.id, nombre: nombre ?? this.nombre,
      cargo: cargo ?? this.cargo, correo: correo ?? this.correo,
      facultad: facultad ?? this.facultad, telefono: telefono ?? this.telefono,
      estado: estado ?? this.estado, fechaConfirmacion: fechaConfirmacion ?? this.fechaConfirmacion,
      codigoQr: codigoQr ?? this.codigoQr,
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

  CampanaNotificacion({
    required this.id, required this.titulo, required this.descripcion,
    required this.estado, this.fechaEnvio, required this.tasaEntrega,
    required this.totalDestinatarios,
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

  Usuario({
    required this.id, required this.nombre, required this.correo,
    required this.password, required this.rol, required this.estado,
    required this.ultimoAcceso,
  });

  Usuario copyWith({
    String? id, String? nombre, String? correo, String? password,
    RolUsuario? rol, EstadoUsuario? estado, DateTime? ultimoAcceso,
  }) {
    return Usuario(
      id: id ?? this.id, nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo, password: password ?? this.password,
      rol: rol ?? this.rol, estado: estado ?? this.estado,
      ultimoAcceso: ultimoAcceso ?? this.ultimoAcceso,
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