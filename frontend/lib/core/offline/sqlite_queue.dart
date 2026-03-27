import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:developer';

/// Provides SQLite Persistence for the Offline Action Queue
class SQLiteQueueHelper {
  static const String tableName = 'offline_queue';
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'splitease_offline.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT NOT NULL,
            payload TEXT NOT NULL,
            idempotency_key TEXT UNIQUE,
            status TEXT DEFAULT 'pending',
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Enqueue a POST/PUT mutation when the app is offline
  static Future<void> enqueueAction(String actionType, Map<String, dynamic> payload, String idempotencyKey) async {
    final db = await database;
    try {
      await db.insert(
        tableName,
        {
          'action_type': actionType,
          'payload': jsonEncode(payload),
          'idempotency_key': idempotencyKey,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore, // Idempotency protection native to SQLite
      );
      log('Encueued offline action: $actionType', name: 'OfflineQueue');
    } catch (e) {
      log('Failed to enqueue: $e', error: true, name: 'OfflineQueue');
    }
  }

  /// Retrieve all pending actions to replay to the API
  static Future<List<Map<String, dynamic>>> getPendingActions() async {
    final db = await database;
    return await db.query(
      tableName,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC', // Strict FIFO chronological order
    );
  }

  static Future<void> markCompleted(int id) async {
    final db = await database;
    await db.update(tableName, {'status': 'completed'}, where: 'id = ?', whereArgs: [id]);
  }
}
