/// BVS隊務管理 Excel → ビーバーログ インポートサービス
library;

import 'dart:math';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class ImportResult {
  final int scouts;
  final int leaders;
  final int committees;
  final int guardians;
  final int events;
  final int attendances;
  final int twigHistories;
  final List<String> warnings;

  const ImportResult({
    required this.scouts,
    required this.leaders,
    required this.committees,
    required this.guardians,
    required this.events,
    required this.attendances,
    required this.twigHistories,
    required this.warnings,
  });
}

class ExcelImportService {
  ExcelImportService._();
  static final instance = ExcelImportService._();

  static const _uuid = Uuid();

  static const _categoryMap = {
    'BVS': 'beaver',
    'BBVS': 'big_beaver',
    '体験中': 'experience',
    '兄弟': 'sibling',
    '未入隊': 'not_joined',
    '上進': 'promoted',
    '退団': 'withdrawn',
  };

  static const _leaderRoleMap = {
    'BVS隊': 'leader',
  };

  // 他隊リーダー → committee_members (category: other_leader)
  static const _otherTroopLeaders = {
    'CS隊', 'BS隊', 'VS隊', 'RS隊',
  };

  static const _committeeCategories = {
    '団委員': 'committee',
    '育成会': 'other',
    'その他': 'other',
  };

  Future<ImportResult> importFromBytes({
    required Uint8List bytes,
    required String troopId,
    required Database db,
  }) async {
    final excel = Excel.decodeBytes(bytes);
    final now = DateTime.now().toIso8601String();
    final warnings = <String>[];

    int scoutCount = 0, leaderCount = 0, committeeCount = 0,
        guardianCount = 0, eventCount = 0, attCount = 0, twigCount = 0;

    await db.transaction((txn) async {
      await _clearTroopData(txn, troopId);

      // 1. リーダー / 団委員
      final leaderIdMap = <String, String>{};
      final committeeIdMap = <String, String>{};
      final leaderSheet = excel.tables['リーダーマスタ'];
      if (leaderSheet != null) {
        for (var i = 1; i < leaderSheet.maxRows; i++) {
          final row = leaderSheet.row(i);
          final excelId = _str(row[0]); if (excelId == null) continue;
          final name = _str(row[1]) ?? '不明';
          final roleRaw = _str(row[2]) ?? '';
          final gender = _genderStr(_str(row[3]));
          final phone = _str(row[4]);
          final email = _str(row[5]);
          final boolVal = row.length > 6 ? row[6]?.value : null;
          final isRetired = (boolVal is BoolCellValue && boolVal.value) ? 0 : 1;

          if (_leaderRoleMap.containsKey(roleRaw)) {
            final dbId = _uuid.v4();
            leaderIdMap[excelId] = dbId;
            await txn.insert('leaders', {
              'id': dbId, 'troop_id': troopId, 'name': name, 'gender': gender,
              'email': email ?? '', 'phone': phone, 'role': _leaderRoleMap[roleRaw]!,
              'is_active': 1, 'is_retired': isRetired,
              'created_at': now, 'updated_at': now,
            });
            leaderCount++;
          } else if (_otherTroopLeaders.contains(roleRaw)) {
            // CS/BS/VS/RS隊 → committee_members (other_leader)
            final dbId = _uuid.v4();
            committeeIdMap[excelId] = dbId;
            await txn.insert('committee_members', {
              'id': dbId, 'troop_id': troopId, 'name': name, 'gender': gender,
              'category': 'other_leader', 'email': email, 'phone': phone,
              'is_retired': 0, 'created_at': now, 'updated_at': now,
            });
            committeeCount++;
          } else if (_committeeCategories.containsKey(roleRaw)) {
            final dbId = _uuid.v4();
            committeeIdMap[excelId] = dbId;
            await txn.insert('committee_members', {
              'id': dbId, 'troop_id': troopId, 'name': name, 'gender': gender,
              'category': _committeeCategories[roleRaw]!, 'email': email, 'phone': phone,
              'is_retired': 0, 'created_at': now, 'updated_at': now,
            });
            committeeCount++;
          }
        }
      }

      // 2. 保護者
      final guardianIdMap = <String, String>{};
      final familyToGuardians = <String, List<String>>{};
      final guardianSheet = excel.tables['保護者マスタ'];
      if (guardianSheet != null) {
        for (var i = 1; i < guardianSheet.maxRows; i++) {
          final row = guardianSheet.row(i);
          final excelId = _str(row[0]); if (excelId == null) continue;
          final name = _str(row[1]) ?? '不明';
          final email = _str(row[2]);
          final phone = _str(row[3]);
          final familyId = _str(row[4]);
          final dbId = _uuid.v4();
          guardianIdMap[excelId] = dbId;
          if (familyId != null) {
            familyToGuardians.putIfAbsent(familyId, () => []).add(excelId);
          }
          await txn.insert('guardians', {
            'id': dbId, 'troop_id': troopId, 'name': name,
            'email': email, 'phone': phone, 'created_at': now, 'updated_at': now,
          });
          guardianCount++;
        }
      }

      // 3. スカウト + scout_guardians
      final scoutIdMap = <String, String>{};
      final scoutSheet = excel.tables['スカウトマスタ'];
      if (scoutSheet != null) {
        for (var i = 1; i < scoutSheet.maxRows; i++) {
          final row = scoutSheet.row(i);
          final excelId = _str(row[0]); if (excelId == null) continue;
          final name = _str(row[1]) ?? '不明';
          final gender = _genderStr(_str(row[2]));
          final categoryRaw = _str(row[4]) ?? '';
          final category = _categoryMap[categoryRaw] ?? 'not_joined';
          final grade = _normalizeGrade(_str(row[6]));
          final initialLeaf = _dbl(row[7])?.round() ?? 0;
          final initialTwig = _dbl(row[8])?.round() ?? 0;
          final allergies = _str(row[9]);
          final familyId = _str(row[10]);
          final notes = _str(row[11]);
          final joinedAt = _date(row[12]);
          final isActive = ['promoted', 'withdrawn', 'not_joined'].contains(category) ? 0 : 1;
          final dbId = _uuid.v4();
          scoutIdMap[excelId] = dbId;

          await txn.insert('scouts', {
            'id': dbId, 'troop_id': troopId, 'name': name, 'gender': gender,
            'grade': grade, 'category': category, 'joined_at': joinedAt,
            'allergies': allergies, 'special_notes': notes,
            'leaf_badges': 0,
            'leaf_badge_offset': -initialLeaf,
            'twig_badges': initialTwig,
            'is_active': isActive, 'created_at': now, 'updated_at': now,
          });

          if (familyId != null && familyToGuardians.containsKey(familyId)) {
            for (final gExcelId in familyToGuardians[familyId]!) {
              final gDbId = guardianIdMap[gExcelId]; if (gDbId == null) continue;
              try {
                await txn.insert('scout_guardians', {
                  'id': _uuid.v4(), 'scout_id': dbId, 'guardian_id': gDbId,
                  'relationship': 'other',
                });
              } catch (_) {}
            }
          }
          scoutCount++;
        }
      }

      // 4. 活動マスタ
      final eventIdMap = <String, String>{};
      final today = DateTime.now().toIso8601String().split('T').first;
      final eventSheet = excel.tables['活動マスタ'];
      if (eventSheet != null) {
        for (var i = 1; i < eventSheet.maxRows; i++) {
          final row = eventSheet.row(i);
          final excelId = _str(row[0]); if (excelId == null) continue;
          final eventDate = _date(row[1]) ?? '2000-01-01';
          final title = _str(row[2]) ?? '活動';
          final location = _str(row[3]);
          final leafCount = _dbl(row[4])?.round() ?? 0;
          final startTime = _str(row[5]);
          final endTime = _str(row[6]);
          final notes = _str(row[7]);
          final dbId = _uuid.v4();
          eventIdMap[excelId] = dbId;

          // 今日以降は「予定」、過去は「確定」
          final isFuture = eventDate.compareTo(today) >= 0;
          final status = isFuture ? 'planned' : 'completed';
          final completedAt = isFuture ? null : '$eventDate 12:00:00';

          await txn.insert('events', {
            'id': dbId, 'troop_id': troopId, 'title': title, 'event_type': 'other',
            'status': status, 'event_date': eventDate,
            'location': location, 'start_time': startTime, 'end_time': endTime,
            'notes': notes, 'completed_at': completedAt,
            'created_at': now, 'updated_at': now,
          });

          // 木の葉章設定（確定イベントのみ）
          if (!isFuture && leafCount > 0) {
            for (final t in _selectLeafTypes(leafCount)) {
              try {
                await txn.insert('event_leaf_badges', {
                  'id': _uuid.v4(), 'event_id': dbId, 'badge_type': t, 'count': 1,
                });
              } catch (_) {}
            }
          }
          eventCount++;
        }
      }

      // 5. リーダー出欠
      // leaderIdMap: excelId → dbId、名前も引けるようにnameMapを持つ
      final leaderNameMap = <String, String>{}; // dbId → name
      final committeeNameMap = <String, String>{}; // dbId → name
      // leaders/committee_membersから名前を取得
      for (final row in (await txn.query('leaders', columns: ['id','name'],
          where: 'troop_id = ?', whereArgs: [troopId]))) {
        leaderNameMap[row['id'] as String] = row['name'] as String;
      }
      for (final row in (await txn.query('committee_members', columns: ['id','name'],
          where: 'troop_id = ?', whereArgs: [troopId]))) {
        committeeNameMap[row['id'] as String] = row['name'] as String;
      }

      // 予定イベントのデフォルト出欠者を生成（リーダー全員 + デフォルト出席カテゴリのスカウト）
      // リーダーの名前リスト（引退者を除く）
      final activeLeaderRows = await txn.query('leaders',
          columns: ['id', 'name'],
          where: 'troop_id = ? AND is_retired = 0', whereArgs: [troopId]);
      final activeLeaderIds = activeLeaderRows
          .map((r) => MapEntry(r['id'] as String, r['name'] as String))
          .toList();

      // デフォルト出席スカウト：ビッグビーバー・ビーバー・仮入隊
      final defaultScoutRows = await txn.query('scouts', columns: ['id','name','category'],
          where: 'troop_id = ? AND is_active = 1', whereArgs: [troopId]);
      const defaultAttendeeCategories = ['big_beaver', 'beaver', 'provisional'];
      final defaultScouts = defaultScoutRows
          .where((r) => defaultAttendeeCategories.contains(r['category'] as String))
          .toList();

      // デフォルト出席対象スカウト（保護者取得用）のid一覧
      const guardianTargetCategories = ['big_beaver', 'beaver', 'provisional'];
      final guardianTargetScoutIds = defaultScoutRows
          .where((r) => guardianTargetCategories.contains(r['category'] as String))
          .map((r) => r['id'] as String)
          .toList();

      // 各スカウトの保護者を取得（重複除去）
      final defaultGuardianIds = <String>{};
      final defaultGuardianNames = <String, String>{}; // id → name
      for (final scoutId in guardianTargetScoutIds) {
        final sgRows = await txn.rawQuery('''
          SELECT g.id, g.name FROM guardians g
          JOIN scout_guardians sg ON sg.guardian_id = g.id
          WHERE sg.scout_id = ?
        ''', [scoutId]);
        for (final row in sgRows) {
          final gId = row['id'] as String;
          defaultGuardianIds.add(gId);
          defaultGuardianNames[gId] = row['name'] as String;
        }
      }

      // 各イベントのステータスを確認して予定のみデフォルト出欠者を生成
      final allEventRows = await txn.query('events',
          columns: ['id', 'status'], where: 'troop_id = ?', whereArgs: [troopId]);
      for (final eventRow in allEventRows) {
        final dbEventId = eventRow['id'] as String;
        if (eventRow['status'] != 'planned') continue;
        // リーダー（引退者除く）をpendingで登録
        for (final entry in activeLeaderIds) {
          try {
            await txn.insert('attendances', {
              'id': _uuid.v4(), 'event_id': dbEventId,
              'member_id': entry.key, 'member_type': 'user',
              'member_name': entry.value, 'status': 'pending', 'is_default': 1,
            });
          } catch (_) {}
        }
        // デフォルト出席スカウトをpendingで登録
        for (final sr in defaultScouts) {
          try {
            await txn.insert('attendances', {
              'id': _uuid.v4(), 'event_id': dbEventId,
              'member_id': sr['id'] as String, 'member_type': 'scout',
              'member_name': sr['name'] as String, 'status': 'pending', 'is_default': 1,
            });
          } catch (_) {}
        }
        // デフォルト保護者をpendingで登録
        for (final gId in defaultGuardianIds) {
          try {
            await txn.insert('attendances', {
              'id': _uuid.v4(), 'event_id': dbEventId,
              'member_id': gId, 'member_type': 'guardian',
              'member_name': defaultGuardianNames[gId] ?? '', 'status': 'pending', 'is_default': 1,
            });
          } catch (_) {}
        }
      }

      final leaderAttSheet = excel.tables['リーダー出欠テーブル'];
      if (leaderAttSheet != null) {
        for (var i = 1; i < leaderAttSheet.maxRows; i++) {
          final row = leaderAttSheet.row(i);
          final excelEventId = _str(row[0]); final excelLeaderId = _str(row[1]);
          if (excelEventId == null || excelLeaderId == null) continue;
          final dbEventId = eventIdMap[excelEventId]; if (dbEventId == null) continue;
          final dbLeaderId = leaderIdMap[excelLeaderId] ?? committeeIdMap[excelLeaderId];
          if (dbLeaderId == null) continue;
          final memberType = leaderIdMap.containsKey(excelLeaderId) ? 'user' : 'committee';
          final memberName = leaderNameMap[dbLeaderId] ?? committeeNameMap[dbLeaderId] ?? '';
          try {
            await txn.insert('attendances', {
              'id': _uuid.v4(), 'event_id': dbEventId, 'member_id': dbLeaderId,
              'member_type': memberType, 'member_name': memberName, 'status': 'present', 'is_default': 0,
            });
            attCount++;
          } catch (_) {}
        }
      }

      // 6. スカウト出欠 + leaf_badges加算
      // scoutIdMap: excelId → dbId、名前も引けるようにnameMapを持つ
      final scoutNameMap2 = <String, String>{}; // dbId → name
      for (final row in (await txn.query('scouts', columns: ['id','name'],
          where: 'troop_id = ?', whereArgs: [troopId]))) {
        scoutNameMap2[row['id'] as String] = row['name'] as String;
      }

      final scoutLeafAccum = <String, int>{};
      final scoutAttSheet = excel.tables['スカウト出欠テーブル'];
      if (scoutAttSheet != null) {
        for (var i = 1; i < scoutAttSheet.maxRows; i++) {
          final row = scoutAttSheet.row(i);
          final excelEventId = _str(row[0]); final excelScoutId = _str(row[1]);
          if (excelEventId == null || excelScoutId == null) continue;
          final dbEventId = eventIdMap[excelEventId]; final dbScoutId = scoutIdMap[excelScoutId];
          if (dbEventId == null || dbScoutId == null) continue;
          final earnedLeaf = _dbl(row[3])?.round() ?? 0;
          final memberName = scoutNameMap2[dbScoutId] ?? '';
          try {
            await txn.insert('attendances', {
              'id': _uuid.v4(), 'event_id': dbEventId, 'member_id': dbScoutId,
              'member_type': 'scout', 'member_name': memberName, 'status': 'present', 'is_default': 0,
            });
            scoutLeafAccum[dbScoutId] = (scoutLeafAccum[dbScoutId] ?? 0) + earnedLeaf;
            attCount++;
          } catch (_) {}
        }
      }
      for (final entry in scoutLeafAccum.entries) {
        await txn.update('scouts', {'leaf_badges': entry.value, 'updated_at': now},
            where: 'id = ?', whereArgs: [entry.key]);
      }

      // 今年度（4月始まり）の確定イベントについて、
      // BBVS・BVSで出席登録がないスカウトを欠席で登録
      final importYear = DateTime.now();
      final fiscalYearStart = DateTime(importYear.month >= 4 ? importYear.year : importYear.year - 1, 4, 1)
          .toIso8601String().split('T').first;
      final fiscalYearEnd = DateTime(importYear.month >= 4 ? importYear.year + 1 : importYear.year, 3, 31)
          .toIso8601String().split('T').first;

      // 今年度の確定イベントを取得
      final thisYearCompletedEvents = await txn.query('events',
          columns: ['id'],
          where: 'troop_id = ? AND status = ? AND event_date >= ? AND event_date <= ?',
          whereArgs: [troopId, 'completed', fiscalYearStart, fiscalYearEnd]);

      // BBVS・BVSのスカウト一覧（is_active不問）
      final bbvsBvsScouts = await txn.query('scouts',
          columns: ['id', 'name'],
          where: 'troop_id = ? AND category IN (?, ?)',
          whereArgs: [troopId, 'big_beaver', 'beaver']);

      for (final eventRow in thisYearCompletedEvents) {
        final dbEventId = eventRow['id'] as String;
        // このイベントの既存出席者IDを取得
        final existingAttRows = await txn.query('attendances',
            columns: ['member_id'],
            where: 'event_id = ? AND member_type = ?',
            whereArgs: [dbEventId, 'scout']);
        final existingMemberIds = existingAttRows
            .map((r) => r['member_id'] as String?)
            .whereType<String>()
            .toSet();

        // 出席登録がないスカウトを欠席で登録
        for (final sr in bbvsBvsScouts) {
          final sid = sr['id'] as String;
          if (existingMemberIds.contains(sid)) continue;
          try {
            await txn.insert('attendances', {
              'id': _uuid.v4(), 'event_id': dbEventId,
              'member_id': sid, 'member_type': 'scout',
              'member_name': sr['name'] as String,
              'status': 'absent', 'is_default': 1,
            });
            attCount++;
          } catch (_) {}
        }
      }

      // 7. 保護者出欠
      final guardianNameMap = <String, String>{}; // dbId → name
      for (final row in (await txn.query('guardians', columns: ['id','name'],
          where: 'troop_id = ?', whereArgs: [troopId]))) {
        guardianNameMap[row['id'] as String] = row['name'] as String;
      }

      final guardianAttSheet = excel.tables['保護者出欠テーブル'];
      if (guardianAttSheet != null) {
        for (var i = 1; i < guardianAttSheet.maxRows; i++) {
          final row = guardianAttSheet.row(i);
          final excelEventId = _str(row[0]); final excelGuardianId = _str(row[1]);
          if (excelEventId == null || excelGuardianId == null) continue;
          final dbEventId = eventIdMap[excelEventId]; final dbGuardianId = guardianIdMap[excelGuardianId];
          if (dbEventId == null || dbGuardianId == null) continue;
          final memberName = guardianNameMap[dbGuardianId] ?? '';
          try {
            await txn.insert('attendances', {
              'id': _uuid.v4(), 'event_id': dbEventId, 'member_id': dbGuardianId,
              'member_type': 'guardian', 'member_name': memberName, 'status': 'present', 'is_default': 0,
            });
            attCount++;
          } catch (_) {}
        }
      }

      // 8. 表彰テーブル → スキップ（twig_badgesは計算式で設定するため不要）

      // 全処理完了後: 全スカウトのtwig_badgesを計算式で上書き
      // BBVS・BVS: (leaf_badges - leaf_badge_offset) ~/ 10
      // その他:    leaf_badges ~/ 10
      final allScoutRows = await txn.query('scouts',
          columns: ['id', 'category', 'leaf_badges', 'leaf_badge_offset'],
          where: 'troop_id = ?', whereArgs: [troopId]);
      for (final r in allScoutRows) {
        final category = r['category'] as String;
        final leafBadges = (r['leaf_badges'] as int? ?? 0);
        final leafBadgeOffset = (r['leaf_badge_offset'] as int? ?? 0);
        if (category == 'big_beaver' || category == 'beaver') {
          final totalLeaf = leafBadges - leafBadgeOffset;
          final twig = totalLeaf >= 0 ? totalLeaf ~/ 10 : 0;
          await txn.update('scouts', {'twig_badges': twig, 'other_badges': 0, 'updated_at': now},
              where: 'id = ?', whereArgs: [r['id'] as String]);
        } else {
          final other = leafBadges >= 0 ? leafBadges ~/ 10 : 0;
          await txn.update('scouts', {'twig_badges': 0, 'other_badges': other, 'updated_at': now},
              where: 'id = ?', whereArgs: [r['id'] as String]);
        }
      }
    });

    return ImportResult(
      scouts: scoutCount,
      leaders: leaderCount,
      committees: committeeCount,
      guardians: guardianCount,
      events: eventCount,
      attendances: attCount,
      twigHistories: twigCount,
      warnings: warnings,
    );
  }

  Future<void> _clearTroopData(DatabaseExecutor txn, String troopId) async {
    final eventIds = (await txn.query('events', columns: ['id'],
        where: 'troop_id = ?', whereArgs: [troopId]))
        .map((r) => r['id'] as String).toList();
    if (eventIds.isNotEmpty) {
      final ph = eventIds.map((_) => '?').join(',');
      await txn.delete('event_stats', where: 'event_id IN ($ph)', whereArgs: eventIds);
      await txn.delete('event_leaf_badges', where: 'event_id IN ($ph)', whereArgs: eventIds);
      await txn.delete('attendances', where: 'event_id IN ($ph)', whereArgs: eventIds);
    }
    final scoutIds = (await txn.query('scouts', columns: ['id'],
        where: 'troop_id = ?', whereArgs: [troopId]))
        .map((r) => r['id'] as String).toList();
    if (scoutIds.isNotEmpty) {
      final ph = scoutIds.map((_) => '?').join(',');
      await txn.delete('twig_badge_history', where: 'scout_id IN ($ph)', whereArgs: scoutIds);
      await txn.delete('scout_guardians', where: 'scout_id IN ($ph)', whereArgs: scoutIds);
    }
    await txn.delete('events', where: 'troop_id = ?', whereArgs: [troopId]);
    await txn.delete('scouts', where: 'troop_id = ?', whereArgs: [troopId]);
    await txn.delete('leaders', where: 'troop_id = ?', whereArgs: [troopId]);
    await txn.delete('committee_members', where: 'troop_id = ?', whereArgs: [troopId]);
    await txn.delete('guardians', where: 'troop_id = ?', whereArgs: [troopId]);
  }

  static List<String> _selectLeafTypes(int count) {
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

  static String _normalizeGrade(String? raw) {
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

  static String _genderStr(String? raw) {
    if (raw == '男') return 'male';
    if (raw == '女') return 'female';
    return 'other';
  }

  static String _spanText(dynamic span) {
    if (span == null) return '';
    String result = '';
    try { final t = (span as dynamic).text; if (t != null) result += t.toString(); } catch (_) {}
    try {
      final children = (span as dynamic).children;
      if (children != null) { for (final c in children) result += _spanText(c); }
    } catch (_) {}
    if (result.isEmpty) {
      final s = span.toString();
      if (!s.startsWith('Instance of')) result = s;
    }
    return result;
  }

  static String? _str(Data? cell) {
    if (cell == null || cell.value == null) return null;
    final v = cell.value!;
    String raw;
    if (v is TextCellValue) {
      raw = _spanText(v.value);
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
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }

  static double? _dbl(Data? cell) {
    if (cell == null || cell.value == null) return null;
    final v = cell.value!;
    if (v is DoubleCellValue) return v.value;
    if (v is IntCellValue) return v.value.toDouble();
    if (v is TextCellValue) return double.tryParse(_spanText(v.value).trim());
    return null;
  }

  static String? _date(Data? cell) {
    if (cell == null || cell.value == null) return null;
    final v = cell.value!;
    if (v is DateCellValue) {
      return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    }
    if (v is TextCellValue) {
      final s = _spanText(v.value).trim();
      return s.isEmpty ? null : s;
    }
    return null;
  }
}
