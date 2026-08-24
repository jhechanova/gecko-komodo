import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_message.dart';
import '../models/app_user.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'notif_app.db';
  static const _dbVersion = 1;

  static const settingsKeyBaseUrl = 'base_url';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, _dbName),
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE user (
            id TEXT PRIMARY KEY,
            email TEXT,
            first_name TEXT,
            last_name TEXT,
            username TEXT,
            fcm_token TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            body TEXT,
            data TEXT,
            received_at TEXT NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<String?> getBaseUrl() async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [settingsKeyBaseUrl],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setBaseUrl(String url) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': settingsKeyBaseUrl, 'value': url},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppUser?> getUser() async {
    final db = await database;
    final rows = await db.query('user', limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<void> saveUser(AppUser user) async {
    final db = await database;
    await db.delete('user');
    await db.insert('user', user.toMap());
  }

  Future<void> clearUser() async {
    final db = await database;
    await db.delete('user');
  }

  Future<int> insertMessage(AppMessage message) async {
    final db = await database;
    final map = message.toMap()..remove('id');
    return db.insert('messages', map);
  }

  Future<List<AppMessage>> getMessages() async {
    final db = await database;
    final rows = await db.query(
      'messages',
      orderBy: 'received_at DESC',
    );
    return rows.map(AppMessage.fromMap).toList();
  }

  Future<void> markMessageRead(int id) async {
    final db = await database;
    await db.update(
      'messages',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
