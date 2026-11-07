import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../../navegacion.dart';
import '../../widgets/common/apolo_ui.dart';
import '../../widgets/common/widgets.dart';

/// Un registro de la coleccion `auditoria` (solo insercion).
class BitacoraEntrada {
  final String id;
  final String accion;
  final String autorCorreo;
  final String autorRol;
  final String tipo;
  final DateTime? fecha;

  BitacoraEntrada({
    required this.id,
    required this.accion,
    required this.autorCorreo,
    required this.autorRol,
    required this.tipo,
    required this.fecha,
  });

  factory BitacoraEntrada.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final ts = d['fecha'];
    return BitacoraEntrada(
      id: doc.id,
      accion: d['accion'] as String? ?? '',
      autorCorreo: d['autorCorreo'] as String? ?? 'desconocido',
      autorRol: d['autorRol'] as String? ?? '',
      tipo: d['tipo'] as String? ?? 'otro',
      fecha: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

/// Ultimos registros de la bitacora, en tiempo real.
Stream<List<BitacoraEntrada>> streamBitacora({int limite = 100}) {
  return FirebaseFirestore.instance
      .collection('auditoria')
      .orderBy('fecha', descending: true)
      .limit(limite)
      .snapshots()
      .map((s) => s.docs.map(BitacoraEntrada.fromDoc).toList());
}

/// Fila reutilizable (dashboard y pantalla completa).
class BitacoraRow extends StatelessWidget {
  final BitacoraEntrada entrada;
  const BitacoraRow({super.key, required this.entrada});

  bool get _esEliminacion {
    final a = entrada.accion.toLowerCase();
    return a.startsWith('elimino') || a.contains('limpi');
  }

  IconData get _icono {
    if (_esEliminacion) return Icons.delete_outline_rounded;
    switch (entrada.tipo) {
      case 'usuario':
        return Icons.manage_accounts_rounded;
      case 'directivo':
        return Icons.person_outline_rounded;
      case 'graduando':
        return Icons.school_rounded;
      case 'ceremonia':
        return Icons.event_rounded;
      case 'email':
        return Icons.mail_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color get _color {
    if (_esEliminacion) return AppColors.error;
    switch (entrada.tipo) {
      case 'usuario':
        return AppColors.primaryLight;
      case 'directivo':
        return AppColors.pending;
      case 'graduando':
        return AppColors.success;
      case 'email':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _rolTexto {
    switch (entrada.autorRol) {
      case 'admin':
        return 'Administrador';
      case 'operador':
        return 'Operador';
      default:
        return entrada.autorRol;
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = entrada.fecha;
    final fechaTxt =
        f == null ? 'ahora' : DateFormat('dd/MM/yyyy HH:mm').format(f);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icono, color: _color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entrada.accion,
                    style: AppTextStyles.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                    _rolTexto.isEmpty
                        ? entrada.autorCorreo
                        : '${entrada.autorCorreo} · $_rolTexto',
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(fechaTxt, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// Pantalla completa de la bitacora. Solo administradores.
class BitacoraScreen extends StatefulWidget {
  const BitacoraScreen({super.key});

  @override
  State<BitacoraScreen> createState() => _BitacoraScreenState();
}

class _BitacoraScreenState extends State<BitacoraScreen> {
  static const _filtros = <String, String>{
    'todos': 'Todos',
    'usuario': 'Usuarios',
    'directivo': 'Directivos',
    'graduando': 'Graduandos',
    'otro': 'Otros',
  };

  String _filtro = 'todos';
  String _fecha = 'todo'; // 'hoy', '7dias' o 'todo'
  String _busqueda = '';
  int _limite = 200;
  late Stream<List<BitacoraEntrada>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = streamBitacora(limite: _limite);
  }

  void _cargarMas() {
    setState(() {
      _limite += 200;
      _stream = streamBitacora(limite: _limite);
    });
  }

  List<BitacoraEntrada> _filtrar(List<BitacoraEntrada> todas) {
    const conocidos = ['usuario', 'directivo', 'graduando'];
    final q = _busqueda.trim().toLowerCase();
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    return todas.where((e) {
      final f = e.fecha;
      if (_fecha == 'hoy' && (f == null || f.isBefore(inicioHoy))) return false;
      if (_fecha == '7dias' && (f == null || f.isBefore(inicioHoy.subtract(const Duration(days: 6))))) return false;
      if (_filtro == 'otro' && conocidos.contains(e.tipo)) return false;
      if (_filtro != 'todos' && _filtro != 'otro' && e.tipo != _filtro) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.accion.toLowerCase().contains(q) ||
          e.autorCorreo.toLowerCase().contains(q);
    }).toList();
  }

  static String _nombreTipo(String tipo) => switch (tipo) {
        'usuario' => 'Usuarios',
        'directivo' => 'Directivos',
        'graduando' || 'graduandos' => 'Graduandos',
        'invitados' || 'invitado' => 'Invitados',
        'importacion' => 'Importación',
        'sesion' => 'Sesión',
        'usuarios' => 'Usuarios',
        'mantenimiento' => 'Mantenimiento',
        'email' || 'correo' => 'Correos',
        _ => tipo.isEmpty ? 'Otro' : tipo[0].toUpperCase() + tipo.substring(1),
      };

  int _cuenta(List<BitacoraEntrada> todas, String filtro) {
    const conocidos = ['usuario', 'directivo', 'graduando'];
    if (filtro == 'todos') return todas.length;
    if (filtro == 'otro') return todas.where((e) => !conocidos.contains(e.tipo)).length;
    return todas.where((e) => e.tipo == filtro).length;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return StreamBuilder<List<BitacoraEntrada>>(
      stream: _stream,
      builder: (context, snap) {
        final todas = snap.data ?? const <BitacoraEntrada>[];
        final lista = _filtrar(todas);
        return PantallaApolo(
          encabezado: EncabezadoPantalla(
            titulo: 'Bitácora',
            detalle: 'Registro permanente de lo que se hace en Apolo',
            alVolver: () => provider.setSelectedIndex(Nav.inicio),
          ),
          cuerpo: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: FiltroSegmentado<String>(
                        valor: _filtro,
                        onChanged: (v) => setState(() => _filtro = v),
                        opciones: [
                          for (final f in _filtros.entries) (f.key, f.value == 'Todos' ? 'Todo' : f.value, _cuenta(todas, f.key)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 170,
                    child: CampoConEtiqueta(
                      etiqueta: 'Fecha',
                      campo: DropdownButtonFormField<String>(
                        initialValue: _fecha,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13)),
                        items: const [
                          DropdownMenuItem(value: 'hoy', child: Text('Hoy')),
                          DropdownMenuItem(value: '7dias', child: Text('Últimos 7 días')),
                          DropdownMenuItem(value: 'todo', child: Text('Todo')),
                        ],
                        onChanged: (v) => setState(() => _fecha = v ?? 'todo'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 240,
                    child: CampoConEtiqueta(
                      etiqueta: 'Buscar',
                      campo: CampoBusqueda(hint: 'Acción o correo', onChanged: (v) => setState(() => _busqueda = v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: snap.hasError
                    ? Center(child: Text('No fue posible cargar la bitácora.', style: AppTextStyles.label))
                    : !snap.hasData
                        ? const Center(child: CircularProgressIndicator())
                        : TablaApolo(
                            porPagina: 12,
                            vacio: 'No hay acciones que coincidan con el filtro.',
                            columnas: const [
                              ColumnaTabla('Hora', flex: 2),
                              ColumnaTabla('Quién', flex: 3),
                              ColumnaTabla('Qué hizo', flex: 6),
                              ColumnaTabla('Tipo', flex: 2),
                            ],
                            filas: [
                              for (final e in lista)
                                [
                                  CeldaTexto(e.fecha == null ? '' : DateFormat('HH:mm').format(e.fecha!),
                                      debajo: e.fecha == null ? null : DateFormat('dd/MM/yyyy').format(e.fecha!), mono: true),
                                  CeldaTexto(e.autorCorreo, debajo: e.autorRol),
                                  Text(e.accion, style: AppTextStyles.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  Etiqueta(_nombreTipo(e.tipo), tono: TonoEtiqueta.info),
                                ],
                            ],
                          ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Los registros no se pueden editar ni borrar desde la aplicación. Se muestran los últimos ${todas.length}.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                  if (todas.length >= _limite) TextButton(onPressed: _cargarMas, child: const Text('Cargar más')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
