import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('apolo_udes.db');
    return _database!;
  }

  /// Inicializa SQLite (compatible con desktop, mobile y web)
  static Future<void> initialize() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  /// Crea las tablas al iniciar la BD por primera vez
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE graduandos (
        id TEXT PRIMARY KEY,
        codigoEstudiantil TEXT NOT NULL,
        documento TEXT NOT NULL,
        nombres TEXT NOT NULL,
        apellidos TEXT NOT NULL,
        programa TEXT NOT NULL,
        facultad TEXT NOT NULL,
        telefono TEXT,
        correo TEXT,
        horaCeremonia TEXT,
        estado INTEGER NOT NULL
      )
    ''');
  }

  // ── CRUD GRADUANDOS ──

  /// Inserta un graduando
  Future<void> insertGraduando(Graduando g) async {
    final db = await database;
    await db.insert(
      'graduandos',
      _toMap(g),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserta varios graduandos en una transacción (más rápido)
  Future<int> insertGraduandosBulk(List<Graduando> graduandos) async {
    final db = await database;
    int inserted = 0;
    await db.transaction((txn) async {
      for (final g in graduandos) {
        try {
          final existe = await txn.query(
            'graduandos',
            where: 'documento = ? OR codigoEstudiantil = ?',
            whereArgs: [g.documento, g.codigoEstudiantil],
          );
          if (existe.isEmpty) {
            await txn.insert('graduandos', _toMap(g));
            inserted++;
          }
        } catch (_) {}
      }
    });
    return inserted;
  }

  /// Obtiene todos los graduandos
  Future<List<Graduando>> getAllGraduandos() async {
    final db = await database;
    final maps = await db.query('graduandos', orderBy: 'apellidos ASC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  /// Actualiza un graduando
  Future<void> updateGraduando(Graduando g) async {
    final db = await database;
    await db.update(
      'graduandos',
      _toMap(g),
      where: 'id = ?',
      whereArgs: [g.id],
    );
  }

  /// Elimina un graduando por id
  Future<void> deleteGraduando(String id) async {
    final db = await database;
    await db.delete('graduandos', where: 'id = ?', whereArgs: [id]);
  }

  /// Elimina TODOS los graduandos
  Future<int> deleteAllGraduandos() async {
    final db = await database;
    return await db.delete('graduandos');
  }

  /// Cuenta total de graduandos
  Future<int> countGraduandos() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as total FROM graduandos');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Helpers de mapeo ──

  Map<String, dynamic> _toMap(Graduando g) {
    return {
      'id': g.id,
      'codigoEstudiantil': g.codigoEstudiantil,
      'documento': g.documento,
      'nombres': g.nombres,
      'apellidos': g.apellidos,
      'programa': g.programa,
      'facultad': g.facultad,
      'telefono': g.telefono,
      'correo': g.correo,
      'horaCeremonia': g.horaCeremonia,
      'estado': g.estado.index,
    };
  }

  Graduando _fromMap(Map<String, dynamic> m) {
    return Graduando(
      id: m['id'] as String,
      codigoEstudiantil: m['codigoEstudiantil'] as String,
      documento: m['documento'] as String,
      nombres: m['nombres'] as String,
      apellidos: m['apellidos'] as String,
      programa: m['programa'] as String,
      facultad: m['facultad'] as String,
      telefono: m['telefono'] as String? ?? '',
      correo: m['correo'] as String? ?? '',
      horaCeremonia: m['horaCeremonia'] as String? ?? '08:00 AM',
      estado: EstadoGraduando.values[m['estado'] as int],
    );
  }

  /// Cierra la BD
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}