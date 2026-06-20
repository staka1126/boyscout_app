/// BVS隊務管理 Excel → ビーバーログ SQLite インポートスクリプト
///
/// 使い方:
///   dart run import_excel.dart <Excelファイルパス> [出力DBパス]
///
/// 依存パッケージ（pubspec.yaml参照）:
///   excel: ^4.0.6
///   sqflite_common_ffi: ^2.3.3
///   path: ^1.9.0
///   uuid: ^4.4.0

import 'dart:io';
import 'dart:math';
import 'package:excel/excel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

// ============================================================
// 定数・マッピング
// ============================================================

const _uuid = Uuid();

const _categoryMap = {
  'BVS': 'beaver',
  'BBVS': 'big_beaver',
  '体験中': 'experience',
  '兄弟': 'sibling',
  '未入隊': 'not_joined',
  '上進': 'promoted',
  '退団': 'withdrawn',
};

const _leaderRoleMap = {
  'BVS隊': 'leader',
  'CS隊': 'leader',
  'BS隊': 'leader',
  'VS隊': 'leader',
};

const _committeeCategories = {
  '団委員': 'committee',
  '育成会': 'other',
  'その他': 'other',
};

String _normalizeGrade(String? raw) {
  if (raw == null) return 'other';
  final s = raw.trim()
      .replaceAll('１', '1').replaceAll('２', '2')
      .replaceAll('３', '3').replaceAll('４', '4');
  switch (s) {
    case '小1': return '小1';
    case '小2': return '小2';
    case '小3': return '小3';
    case '小4': return '小4';
    case '年長': return '年長';
    case '年少': return '年少';
    case '年中': return '年中';
    case '幼稚園': return '年長';
    case '未就学': return '未就学';
    case '3歳': return '未就学';
    default: return 'other';
  }
}

List<String> _selectLeafTypes(int count) {
  const priority = ['society', 'nature'];
  const others = ['health', 'expression', 'life'];
  final selected = <String>[];
  for (final t in priority) {
    if (selected.length < count) selected.add(t);
  }
  final shuffled = List<String>.from(others)..shuffle(Random(42));
  for (final t in shuffled) {
    if (selected.length >= count) break;
    selected.add(t);
  }
  return selected;
}

// ============================================================
// Excelユーティリティ
// excel 4.x では TextCellValue.value が TextSpan 型。
// TextSpan には .text プロパティ（String?）と .children がある。
// _textSpanToString() で再帰的に文字列化する。
// ============================================================

/// TextSpan（excel独自型）を再帰的に文字列化
String _textSpanToString(dynamic span) {
  if (span == null) return '';
  // .text プロパティがあれば取得
  String result = '';
  try {
    final t = (span as dynamic).text;
    if (t != null) result += t.toString();
  } catch (_) {}
  // .children があれば再帰
  try {
    final children = (span as dynamic).children;
    if (children != null) {
      for (final child in children) {
        result += _textSpanToString(child);
      }
    }
  } catch (_) {}
  // どちらも取れなければ toString() でフォールバック
  if (result.isEmpty) {
    final s = span.toString();
    // "Instance of 'TextSpan'" のような無意味な文字列は除外
    if (!s.startsWith('Instance of')) result = s;
  }
  return result;
}

/// セルの値を文字列として取得（空文字・空白のみはnull）
String? _str(Data? cell) {
  if (cell == null || cell.value == null) return null;
  final v = cell.value!;
  String raw;
  if (v is TextCellValue) {
    raw = _textSpanToString(v.value);
  } else if (v is IntCellValue) {
    raw = v.value.toString();
  } else if (v is DoubleCellValue) {
    raw = v.value.toString();
  } else if (v is DateCellValue) {
    raw = '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  } else if (v is BoolCellValue) {
    raw = v.value.toString();
  } else {
    raw = v.toString();
  }
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// セルの値を整数として取得
int? _int(Data? cell) {
  if (cell == null || cell.value == null) return null;
  final v = cell.value!;
  if (v is IntCellValue) return v.value;
  if (v is DoubleCellValue) return v.value.round();
  if (v is TextCellValue) return int.tryParse(_textSpanToString(v.value).trim());
  return null;
}

/// セルの値をdoubleとして取得
double? _double(Data? cell) {
  if (cell == null || cell.value == null) return null;
  final v = cell.value!;
  if (v is DoubleCellValue) return v.value;
  if (v is IntCellValue) return v.value.toDouble();
  if (v is TextCellValue) return double.tryParse(_textSpanToString(v.value).trim());
  return null;
}

/// セルの値を日付文字列（yyyy-MM-dd）として取得
String? _date(Data? cell) {
  if (cell == null || cell.value == null) return null;
  final v = cell.value!;
  if (v is DateCellValue) {
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  }
  if (v is TextCellValue) {
    final s = _textSpanToString(v.value).trim();
    return s.isEmpty ? null : s;
  }
  return null;
}

String _now() => DateTime.now().toIso8601String();

// ============================================================
// DBスキーマ作成（アプリと同一 v5）
// ============================================================

Future<void> _createSchema(Database db) async {
  // アプリの database_helper.dart (_create) と完全に同一のスキーマ
  await db.execute('''
    CREATE TABLE IF NOT EXISTS troops (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      location TEXT,
      contact TEXT,
      troop_code TEXT UNIQUE,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS leaders (
      id TEXT PRIMARY KEY,
      troop_id TEXT NOT NULL,
      name TEXT NOT NULL,
      gender TEXT,
      email TEXT,
      phone TEXT,
      role TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_retired INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (troop_id) REFERENCES troops(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS scouts (
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
    CREATE TABLE IF NOT EXISTS guardians (
      id TEXT PRIMARY KEY,
      troop_id TEXT,
      name TEXT NOT NULL,
      gender TEXT,
      email TEXT,
      phone TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS scout_guardians (
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
    CREATE TABLE IF NOT EXISTS committee_members (
      id TEXT PRIMARY KEY,
      troop_id TEXT NOT NULL,
      name TEXT NOT NULL,
      gender TEXT,
      category TEXT NOT NULL,
      email TEXT,
      phone TEXT,
      is_retired INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (troop_id) REFERENCES troops(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS events (
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
    CREATE TABLE IF NOT EXISTS event_leaf_badges (
      id TEXT PRIMARY KEY,
      event_id TEXT NOT NULL,
      badge_type TEXT NOT NULL,
      count INTEGER NOT NULL DEFAULT 0,
      UNIQUE(event_id, badge_type),
      FOREIGN KEY (event_id) REFERENCES events(id)
    )
  ''');
  // attendances: アプリ版は member_name・is_default・notes カラムあり、created_at/updated_at なし
  await db.execute('''
    CREATE TABLE IF NOT EXISTS attendances (
      id TEXT PRIMARY KEY,
      event_id TEXT NOT NULL,
      member_type TEXT NOT NULL,
      member_id TEXT,
      member_name TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'present',
      is_default INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      UNIQUE(event_id, member_type, member_id),
      FOREIGN KEY (event_id) REFERENCES events(id)
    )
  ''');
  // twig_badge_history: アプリ版は scout_name・created_at・updated_at カラムあり
  await db.execute('''
    CREATE TABLE IF NOT EXISTS twig_badge_history (
      id TEXT PRIMARY KEY,
      scout_id TEXT NOT NULL,
      scout_name TEXT NOT NULL DEFAULT '',
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

// ============================================================
// メイン処理
// ============================================================

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('使い方: dart run import_excel.dart <Excelファイルパス> [出力DBパス]');
    exit(1);
  }

  final excelPath = args[0];
  final dbPath = args.length > 1
      ? args[1]
      : p.join(p.dirname(excelPath), 'beaverlog_import.db');

  final file = File(excelPath);
  if (!file.existsSync()) {
    stderr.writeln('ファイルが見つかりません: $excelPath');
    exit(1);
  }
  print('📖 Excelを読み込み中: $excelPath');
  final bytes = file.readAsBytesSync();
  final excel = Excel.decodeBytes(bytes);

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  if (File(dbPath).existsSync()) File(dbPath).deleteSync();
  print('🗄️  DBを作成中: $dbPath');
  // version: 5 を指定することでアプリ起動時に onCreate が呼ばれず onUpgrade のみになる
  final db = await databaseFactory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 5,
      onCreate: (db, _) async => await _createSchema(db),
    ),
  );

  final now = _now();
  const troopId = 'import-troop-00000000-0000-0000-0000-000000000001';

  // 1. 団レコード
  await db.insert('troops', {
    'id': troopId, 'name': '杉並第3団', 'location': '', 'contact': '',
    'created_at': now, 'updated_at': now,
  });
  print('✅ 団レコード挿入');

  // 2. リーダー / 団委員マスタ
  final leaderIdMap = <String, String>{};
  final committeeIdMap = <String, String>{};
  final leaderSheet = excel.tables['リーダーマスタ']!;
  int leaderCount = 0, committeeCount = 0;
  for (var i = 1; i < leaderSheet.maxRows; i++) {
    final row = leaderSheet.row(i);
    final excelId = _str(row[0]); if (excelId == null) continue;
    final name = _str(row[1]) ?? '不明';
    final roleRaw = _str(row[2]) ?? '';
    final genderRaw = _str(row[3]);
    final gender = genderRaw == '男' ? 'male' : (genderRaw == '女' ? 'female' : 'other');
    final phone = _str(row[4]);
    final email = _str(row[5]);
    // 帰着報告送付先がTrueの列 = is_active扱い（Boolean or null）
    final boolVal = row.length > 6 ? row[6]?.value : null;
    final isActive = boolVal is BoolCellValue && boolVal.value ? 1 : 0;

    if (_leaderRoleMap.containsKey(roleRaw)) {
      final dbId = _uuid.v4();
      leaderIdMap[excelId] = dbId;
      await db.insert('leaders', {
        'id': dbId, 'troop_id': troopId, 'name': name, 'gender': gender,
        'email': email, 'phone': phone, 'role': _leaderRoleMap[roleRaw]!,
        'is_active': 1, 'is_retired': isActive == 0 ? 1 : 0,
        'created_at': now, 'updated_at': now,
      });
      leaderCount++;
    } else if (_committeeCategories.containsKey(roleRaw)) {
      final dbId = _uuid.v4();
      committeeIdMap[excelId] = dbId;
      await db.insert('committee_members', {
        'id': dbId, 'troop_id': troopId, 'name': name, 'gender': gender,
        'category': _committeeCategories[roleRaw]!, 'email': email, 'phone': phone,
        'is_retired': isActive == 0 ? 1 : 0,
        'created_at': now, 'updated_at': now,
      });
      committeeCount++;
    }
  }
  print('✅ リーダー: $leaderCount件, 団委員ほか: $committeeCount件');

  // 3. 保護者マスタ
  final guardianIdMap = <String, String>{};
  final familyToGuardians = <String, List<String>>{};
  final guardianSheet = excel.tables['保護者マスタ']!;
  int guardianCount = 0;
  for (var i = 1; i < guardianSheet.maxRows; i++) {
    final row = guardianSheet.row(i);
    final excelId = _str(row[0]); if (excelId == null) continue;
    final name = _str(row[1]) ?? '不明';
    final email = _str(row[2]);
    final phone = _str(row[3]);
    final familyId = _str(row[4]);
    final dbId = _uuid.v4();
    guardianIdMap[excelId] = dbId;
    if (familyId != null) familyToGuardians.putIfAbsent(familyId, () => []).add(excelId);
    await db.insert('guardians', {
      'id': dbId, 'troop_id': troopId, 'name': name,
      'email': email, 'phone': phone, 'created_at': now, 'updated_at': now,
    });
    guardianCount++;
  }
  print('✅ 保護者: $guardianCount件');

  // 4. スカウトマスタ
  final scoutIdMap = <String, String>{};
  final scoutSheet = excel.tables['スカウトマスタ']!;
  int scoutCount = 0;
  for (var i = 1; i < scoutSheet.maxRows; i++) {
    final row = scoutSheet.row(i);
    final excelId = _str(row[0]); if (excelId == null) continue;
    final name = _str(row[1]) ?? '不明';
    final genderRaw = _str(row[2]);
    final gender = genderRaw == '男' ? 'male' : (genderRaw == '女' ? 'female' : 'other');
    final categoryRaw = _str(row[4]) ?? '';
    final category = _categoryMap[categoryRaw] ?? 'not_joined';
    final grade = _normalizeGrade(_str(row[6]));
    final initialLeaf = _double(row[7])?.round() ?? 0;
    final initialTwig = _double(row[8])?.round() ?? 0;
    final allergies = _str(row[9]);
    final familyId = _str(row[10]);
    final notes = _str(row[11]);
    final joinedAt = _date(row[12]);
    final isActive = ['promoted', 'withdrawn', 'not_joined'].contains(category) ? 0 : 1;
    final dbId = _uuid.v4();
    scoutIdMap[excelId] = dbId;

    await db.insert('scouts', {
      'id': dbId, 'troop_id': troopId, 'name': name, 'gender': gender,
      'grade': grade, 'category': category, 'joined_at': joinedAt,
      'allergies': allergies, 'special_notes': notes,
      'leaf_badges': 0,
      'leaf_badge_offset': -initialLeaf, // 符号反転：プラス補正 → offsetを負値に
      'twig_badges': initialTwig,
      'is_active': isActive, 'created_at': now, 'updated_at': now,
    });

    if (familyId != null && familyToGuardians.containsKey(familyId)) {
      for (final gExcelId in familyToGuardians[familyId]!) {
        final gDbId = guardianIdMap[gExcelId]; if (gDbId == null) continue;
        try {
          await db.insert('scout_guardians', {
            'id': _uuid.v4(), 'scout_id': dbId, 'guardian_id': gDbId, 'relationship': 'other',
          });
        } catch (_) {}
      }
    }
    scoutCount++;
  }
  print('✅ スカウト: $scoutCount件');

  // 5. 活動マスタ
  final eventIdMap = <String, String>{};
  final eventSheet = excel.tables['活動マスタ']!;
  int eventCount = 0;
  for (var i = 1; i < eventSheet.maxRows; i++) {
    final row = eventSheet.row(i);
    final excelId = _str(row[0]); if (excelId == null) continue;
    final eventDate = _date(row[1]) ?? '2000-01-01';
    final title = _str(row[2]) ?? '活動';
    final location = _str(row[3]);
    final leafCount = _double(row[4])?.round() ?? 0;
    final startTime = _str(row[5]);
    final endTime = _str(row[6]);
    final notes = _str(row[7]);
    final dbId = _uuid.v4();
    eventIdMap[excelId] = dbId;
    await db.insert('events', {
      'id': dbId, 'troop_id': troopId, 'title': title, 'event_type': 'other',
      'status': 'completed', 'event_date': eventDate,
      'location': location, 'start_time': startTime, 'end_time': endTime,
      'notes': notes, 'completed_at': '$eventDate 12:00:00',
      'created_at': now, 'updated_at': now,
    });
    if (leafCount > 0) {
      for (final t in _selectLeafTypes(leafCount)) {
        await db.insert('event_leaf_badges', {
          'id': _uuid.v4(), 'event_id': dbId, 'badge_type': t, 'count': 1,
        });
      }
    }
    eventCount++;
  }
  print('✅ 活動: $eventCount件');

  // 6. リーダー出欠
  final leaderAttSheet = excel.tables['リーダー出欠テーブル']!;
  int leaderAttCount = 0;
  for (var i = 1; i < leaderAttSheet.maxRows; i++) {
    final row = leaderAttSheet.row(i);
    final excelEventId = _str(row[0]); final excelLeaderId = _str(row[1]);
    if (excelEventId == null || excelLeaderId == null) continue;
    final dbEventId = eventIdMap[excelEventId]; if (dbEventId == null) continue;
    final dbLeaderId = leaderIdMap[excelLeaderId] ?? committeeIdMap[excelLeaderId];
    if (dbLeaderId == null) continue;
    final memberType = leaderIdMap.containsKey(excelLeaderId) ? 'user' : 'committee';
    await db.insert('attendances', {
      'id': _uuid.v4(), 'event_id': dbEventId, 'member_id': dbLeaderId,
      'member_type': memberType,
      'member_name': '',
      'status': 'present', 'is_default': 0,
    });
    leaderAttCount++;
  }
  print('✅ リーダー出欠: $leaderAttCount件');

  // 7. スカウト出欠 + leaf_badges加算
  final scoutLeafAccum = <String, int>{};
  final scoutAttSheet = excel.tables['スカウト出欠テーブル']!;
  int scoutAttCount = 0;
  for (var i = 1; i < scoutAttSheet.maxRows; i++) {
    final row = scoutAttSheet.row(i);
    final excelEventId = _str(row[0]); final excelScoutId = _str(row[1]);
    if (excelEventId == null || excelScoutId == null) continue;
    final dbEventId = eventIdMap[excelEventId]; final dbScoutId = scoutIdMap[excelScoutId];
    if (dbEventId == null || dbScoutId == null) continue;
    final earnedLeaf = _double(row[3])?.round() ?? 0;
    await db.insert('attendances', {
      'id': _uuid.v4(), 'event_id': dbEventId, 'member_id': dbScoutId,
      'member_type': 'scout',
      'member_name': '',
      'status': 'present', 'is_default': 0,
    });
    scoutLeafAccum[dbScoutId] = (scoutLeafAccum[dbScoutId] ?? 0) + earnedLeaf;
    scoutAttCount++;
  }
  for (final entry in scoutLeafAccum.entries) {
    await db.update('scouts', {'leaf_badges': entry.value, 'updated_at': now},
        where: 'id = ?', whereArgs: [entry.key]);
  }
  print('✅ スカウト出欠: $scoutAttCount件 (木の葉章更新: ${scoutLeafAccum.length}名)');

  // 8. 保護者出欠
  final guardianAttSheet = excel.tables['保護者出欠テーブル']!;
  int guardianAttCount = 0;
  for (var i = 1; i < guardianAttSheet.maxRows; i++) {
    final row = guardianAttSheet.row(i);
    final excelEventId = _str(row[0]); final excelGuardianId = _str(row[1]);
    if (excelEventId == null || excelGuardianId == null) continue;
    final dbEventId = eventIdMap[excelEventId]; final dbGuardianId = guardianIdMap[excelGuardianId];
    if (dbEventId == null || dbGuardianId == null) continue;
    await db.insert('attendances', {
      'id': _uuid.v4(), 'event_id': dbEventId, 'member_id': dbGuardianId,
      'member_type': 'guardian',
      'member_name': '',
      'status': 'present', 'is_default': 0,
    });
    guardianAttCount++;
  }
  print('✅ 保護者出欠: $guardianAttCount件');

  // 9. 表彰テーブル → twig_badge_history
  final scoutNameMap = <String, String>{};
  for (final r in await db.query('scouts', columns: ['id', 'name'])) {
    scoutNameMap[r['name'] as String] = r['id'] as String;
  }
  final awardSheet = excel.tables['表彰テーブル']!;
  int awardCount = 0, awardSkip = 0;
  for (var i = 1; i < awardSheet.maxRows; i++) {
    final row = awardSheet.row(i);
    if (_str(row[0]) == null) continue;
    if (_str(row[1]) != '小枝章') continue;
    final awardedAt = _date(row[2]);
    final targetName = _str(row[3]) ?? '';
    String? dbScoutId = scoutNameMap[targetName];
    if (dbScoutId == null) {
      final lastName = targetName.split(RegExp(r'[\s　]')).last;
      for (final entry in scoutNameMap.entries) {
        if (entry.key.contains(lastName) || targetName.contains(entry.key.split(RegExp(r'[\s　]')).last)) {
          dbScoutId = entry.value;
          break;
        }
      }
    }
    if (dbScoutId == null) {
      stderr.writeln('  ⚠️  表彰: スカウト名「$targetName」が見つかりません（スキップ）');
      awardSkip++;
      continue;
    }
    await db.insert('twig_badge_history', {
      'id': _uuid.v4(), 'scout_id': dbScoutId,
      'scout_name': '',
      'awarded_at': awardedAt ?? now, 'status': 'awarded',
      'created_at': now, 'updated_at': now,
    });
    awardCount++;
  }
  print('✅ 小枝章授与履歴: $awardCount件 (スキップ: $awardSkip件)');

  await db.close();
  print('');
  print('🎉 インポート完了！');
  print('   出力DB: $dbPath');
}
