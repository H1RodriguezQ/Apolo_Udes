import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static const _imgbbApiKey = 'e5f826226fdb48b453aa5b245d76a864';

  static CollectionReference get _graduandos => _db.collection('graduandos');
  static CollectionReference get _invitados => _db.collection('invitados');

  // ── Sube QR a ImgBB y retorna URL pública ──
  static Future<String> subirQrStorage({
    required String codigoQr,
    required Uint8List qrBytes,
  }) async {
    final base64Image = base64Encode(qrBytes);
    final response = await http.post(
      Uri.parse('https://api.imgbb.com/1/upload?key=$_imgbbApiKey'),
      body: {
        'image': base64Image,
        'name': codigoQr,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final url = data['data']['url'] as String;
      return url;
    } else {
      throw Exception('Error subiendo QR a ImgBB: ${response.statusCode}');
    }
  }

  // ── Guarda graduando en Firestore ──
  static Future<void> guardarGraduando(Graduando g) async {
    await _graduandos.doc(g.id).set({
      'id': g.id,
      'nombres': g.nombres,
      'apellidos': g.apellidos,
      'nombreCompleto': g.nombreCompleto,
      'documento': g.documento,
      'codigoEstudiantil': g.codigoEstudiantil,
      'programa': g.programa,
      'facultad': g.facultad,
      'correo': g.correo,
      'telefono': g.telefono,
      'horaCeremonia': g.horaCeremonia,
      'estado': g.estado.name,
      'fechaRegistro': FieldValue.serverTimestamp(),
      'invitadosRegistrados': false,
    });
  }

  // ── Escucha invitados de un graduando ──
  static Stream<QuerySnapshot> escucharInvitados(String graduandoId) {
    return _invitados
        .where('graduandoId', isEqualTo: graduandoId)
        .snapshots();
  }

  // ── Escucha todos los invitados ──
  static Stream<QuerySnapshot> escucharTodosInvitados() {
    return _invitados
        .orderBy('fechaRegistro', descending: true)
        .snapshots();
  }

  // ── Escucha confirmaciones ──
  static Stream<QuerySnapshot> escucharConfirmaciones() {
    return _invitados
        .where('confirmacion', whereIn: ['confirmado', 'rechazado']).snapshots();
  }

  // ── Guarda invitado en Firestore ──
  static Future<void> confirmarAsistencia({
    required String graduandoId,
    required String nombreInvitado,
    required String documento,
    required String correoInvitado,
    required String tipo,
  }) async {
    final id = 'INV${DateTime.now().millisecondsSinceEpoch}';
    await _invitados.doc(id).set({
      'id': id,
      'graduandoId': graduandoId,
      'nombreInvitado': nombreInvitado,
      'documento': documento,
      'correoInvitado': correoInvitado,
      'tipo': tipo,
      'estado': 'pendiente',
      'fechaRegistro': FieldValue.serverTimestamp(),
      'codigoQr': 'QR-$id',
    });
  }

  // ── Obtiene todos los graduandos ──
  static Future<List<Map<String, dynamic>>> obtenerGraduandos() async {
    final snapshot = await _graduandos.get();
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  // ── Elimina graduando ──
  static Future<void> eliminarGraduando(String id) async {
    await _graduandos.doc(id).delete();
  }
}