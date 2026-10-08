import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/app_message.dart';
import '../models/app_user.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'notif_app.db';
  static const _dbVersion = 2;

  static const settingsKeyBaseUrl = 'base_url';
  static const settingsKeyDeviceId = 'device_id';
  static const deviceIdMaxLength = 50;

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
            message_id TEXT,
            title TEXT,
            body TEXT,
            data TEXT,
            received_at TEXT NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN message_id TEXT');
        }
      },
    );
  }

  Future<String?> _getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getBaseUrl() => _getSetting(settingsKeyBaseUrl);

  Future<void> setBaseUrl(String url) => _setSetting(settingsKeyBaseUrl, url);

  /// Stable per-install id (max [deviceIdMaxLength] chars) for multi-device FCM.
  Future<String> getOrCreateDeviceId() async {
    final existing = await _getSetting(settingsKeyDeviceId);
    if (existing != null && existing.isNotEmpty) {
      if (existing.length <= deviceIdMaxLength) return existing;
      final truncated = existing.substring(0, deviceIdMaxLength);
      await _setSetting(settingsKeyDeviceId, truncated);
      return truncated;
    }

    final generated = const Uuid().v4().replaceAll('-', '');
    final deviceId = generated.length <= deviceIdMaxLength
        ? generated
        : generated.substring(0, deviceIdMaxLength);
    await _setSetting(settingsKeyDeviceId, deviceId);
    return deviceId;
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

  /// Returns false when [messageId] was already stored.
  Future<bool> insertMessage(AppMessage message, {String? messageId}) async {
    final db = await database;
    if (messageId != null && messageId.isNotEmpty) {
      final existing = await db.query(
        'messages',
        columns: ['id'],
        where: 'message_id = ?',
        whereArgs: [messageId],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;
    }
    final map = message.toMap()..remove('id');
    if (messageId != null && messageId.isNotEmpty) {
      map['message_id'] = messageId;
    }
    await db.insert('messages', map);
    return true;
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
