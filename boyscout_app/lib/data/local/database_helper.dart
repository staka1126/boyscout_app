import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../../core/constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String dbDir;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      dbDir = '$home/.local/share/boyscout_app';
      await Directory(dbDir).create(recursive: true);
    } else {
      dbDir = await getDatabasesPath();
    }

    final path = join(dbDir, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final sql in [
        'ALTER TABLE users ADD COLUMN is_retired INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE committee_members ADD COLUMN is_retired INTEGER NOT NULL DEFAULT 0',
      ]) {
        try { await db.execute(sql); } catch (_) {}
      }
    }
    if (oldVersion < 3) {
      for (final sql in [
        'ALTER TABLE scouts ADD COLUMN birthday TEXT',
        'ALTER TABLE scouts ADD COLUMN allergies TEXT',
        'ALTER TABLE scouts ADD COLUMN special_notes TEXT',
      ]) {
        try { await db.execute(sql); } catch (_) {}
      }
    }
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE troops (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        location TEXT,
        contact TEXT,
        troop_code TEXT UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // email は UNIQUE 制約なし・NULL 許容に変更
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        troop_id TEXT NOT NULL,
        name TEXT NOT NULL,
        gender TEXT,
        email TEXT,
        phone TEXT,
        role TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (troop_id) REFERENCES troops(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE scouts (
        id TEXT PRIMARY KEY,
        troop_id TEXT NOT NULL,
        name TEXT NOT NULL,
        gender TEXT,
        grade TEXT,
        category TEXT NOT NULL,
        enrollment_year INTEGER,
        joined_at TEXT,
        birthday TEXT,
        allergies TEXT,
        special_notes TEXT,
        leaf_badges INTEGER NOT NULL DEFAULT 0,
        leaf_badge_offset INTEGER NOT NULL DEFAULT 0,
        twig_badges INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (troop_id) REFERENCES troops(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE guardians (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        gender TEXT,
        email TEXT,
        phone TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE scout_guardians (
        id TEXT PRIMARY KEY,
        scout_id TEXT NOT NULL,
        guardian_id TEXT NOT NULL,
        relationship TEXT,
        UNIQUE(scout_id, guardian_id),
        FOREIGN KEY (scout_id) REFERENCES scouts(id),
        FOREIGN KEY (guardian_id) REFERENCES guardians(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE committee_members (
        id TEXT PRIMARY KEY,
        troop_id TEXT NOT NULL,
        name TEXT NOT NULL,
        gender TEXT,
        category TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (troop_id) REFERENCES troops(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        troop_id TEXT NOT NULL,
        title TEXT NOT NULL,
        event_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'planned',
        event_date TEXT NOT NULL,
        location TEXT,
        start_time TEXT,
        end_time TEXT,
        notes TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (troop_id) REFERENCES troops(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE event_leaf_badges (
        id TEXT PRIMARY KEY,
        event_id TEXT NOT NULL,
        badge_type TEXT NOT NULL,
        count INTEGER NOT NULL DEFAULT 0,
        UNIQUE(event_id, badge_type),
        FOREIGN KEY (event_id) REFERENCES events(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE attendances (
        id TEXT PRIMARY KEY,
        event_id TEXT NOT NULL,
        member_type TEXT NOT NULL,
        member_id TEXT,
        member_name TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        is_default INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        UNIQUE(event_id, member_type, member_id),
        FOREIGN KEY (event_id) REFERENCES events(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE twig_badge_history (
        id TEXT PRIMARY KEY,
        scout_id TEXT NOT NULL,
        scout_name TEXT NOT NULL,
        event_id TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        awarded_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (scout_id) REFERENCES scouts(id),
        FOREIGN KEY (event_id) REFERENCES events(id)
      )
    ''');
  }
}
