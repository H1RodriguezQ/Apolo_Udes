import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
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
    return todas.where((e) {
      if (_filtro == 'otro' && conocidos.contains(e.tipo)) return false;
      if (_filtro != 'todos' && _filtro != 'otro' && e.tipo != _filtro) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.accion.toLowerCase().contains(q) ||
          e.autorCorreo.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Bitácora',
            subtitle: 'Registro permanente de acciones del sistema',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.lock_outline_rounded, color: AppColors.info, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Los registros no se pueden modificar ni eliminar, ni siquiera por un administrador.',
                  style: TextStyle(color: AppColors.info, fontSize: 12),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filtros.entries
                .map((f) => ChoiceChip(
                      label: Text(f.value),
                      selected: _filtro == f.key,
                      onSelected: (_) => setState(() => _filtro = f.key),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por acción o correo',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (v) => setState(() => _busqueda = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: StreamBuilder<List<BitacoraEntrada>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Center(
                        child: Text('No fue posible cargar la bitácora.'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final todas = snap.data!;
                  final lista = _filtrar(todas);

                  if (lista.isEmpty) {
                    return const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'Sin registros',
                      subtitle: 'No hay acciones que coincidan con el filtro',
                    );
                  }

                  return Column(children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: lista.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => BitacoraRow(entrada: lista[i]),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                              'Mostrando ${lista.length} de los últimos ${todas.length} registros',
                              style: AppTextStyles.caption),
                        ),
                        if (todas.length >= _limite)
                          TextButton(
                              onPressed: _cargarMas,
                              child: const Text('Cargar más')),
                      ]),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}