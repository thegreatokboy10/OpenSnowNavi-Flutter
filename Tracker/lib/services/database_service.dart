import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/session.dart';
import '../models/location_point.dart';
import '../models/motion_data.dart';

/// 数据库服务 - 使用 SQLite 本地存储
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'snownavi_tracker.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Sessions 表
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        state INTEGER NOT NULL DEFAULT 0,
        total_distance REAL NOT NULL DEFAULT 0,
        skiing_distance REAL NOT NULL DEFAULT 0,
        max_speed REAL NOT NULL DEFAULT 0,
        total_elevation_gain REAL NOT NULL DEFAULT 0,
        total_elevation_loss REAL NOT NULL DEFAULT 0,
        paused_duration REAL NOT NULL DEFAULT 0
      )
    ''');

    // Location Points 表
    await db.execute('''
      CREATE TABLE location_points (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL NOT NULL DEFAULT 0,
        horizontal_accuracy REAL NOT NULL DEFAULT 0,
        vertical_accuracy REAL NOT NULL DEFAULT 0,
        speed REAL NOT NULL DEFAULT -1,
        heading REAL NOT NULL DEFAULT -1,
        is_moving INTEGER NOT NULL DEFAULT 1,
        is_auto_paused INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');

    // Motion Data 表
    await db.execute('''
      CREATE TABLE motion_data (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        accel_x REAL NOT NULL DEFAULT 0,
        accel_y REAL NOT NULL DEFAULT 0,
        accel_z REAL NOT NULL DEFAULT 0,
        gyro_x REAL NOT NULL DEFAULT 0,
        gyro_y REAL NOT NULL DEFAULT 0,
        gyro_z REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');

    // 创建索引
    await db.execute(
        'CREATE INDEX idx_location_session ON location_points (session_id)');
    await db.execute(
        'CREATE INDEX idx_motion_session ON motion_data (session_id)');
  }

  // ==================== Session CRUD ====================

  Future<void> insertSession(Session session) async {
    final db = await database;
    await db.insert('sessions', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSession(Session session) async {
    final db = await database;
    await db.update('sessions', session.toMap(),
        where: 'id = ?', whereArgs: [session.id]);
  }

  Future<List<Session>> getAllSessions() async {
    final db = await database;
    final maps = await db.query('sessions', orderBy: 'start_time DESC');
    return maps.map((map) => Session.fromMap(map)).toList();
  }

  Future<Session?> getSession(String id) async {
    final db = await database;
    final maps = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Session.fromMap(maps.first);
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete('location_points', where: 'session_id = ?', whereArgs: [id]);
    await db.delete('motion_data', where: 'session_id = ?', whereArgs: [id]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== LocationPoint CRUD ====================

  Future<void> insertLocationPoint(LocationPoint point) async {
    final db = await database;
    await db.insert('location_points', point.toMap());
  }

  Future<List<LocationPoint>> getLocationPoints(String sessionId) async {
    final db = await database;
    final maps = await db.query('location_points',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'timestamp ASC');
    return maps.map((map) => LocationPoint.fromMap(map)).toList();
  }

  // ==================== MotionData CRUD ====================

  Future<void> insertMotionData(MotionData data) async {
    final db = await database;
    await db.insert('motion_data', data.toMap());
  }

  Future<List<MotionData>> getMotionData(String sessionId) async {
    final db = await database;
    final maps = await db.query('motion_data',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'timestamp ASC');
    return maps.map((map) => MotionData.fromMap(map)).toList();
  }
}

