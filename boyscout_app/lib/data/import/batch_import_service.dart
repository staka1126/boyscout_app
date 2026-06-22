/// バッチ登録用 Excel インポートサービス
/// 既存データへの追記型インポート（上書きなし）
library;

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

// ─── 結果クラス ─────────────────────────────────────────────
class BatchImportResult {
  final int leaders;
  final int scouts;
  final int committees;
  final int guardians;
  final List<String> warnings;
  final List<String> skipped; // 重複スキップ

  const BatchImportResult({
    required this.leaders,
    required this.scouts,
    required this.committees,
    required this.guardians,
    required this.warnings,
    required this.skipped,
  });

  int get total => leaders + scouts + committees + guardians;
}

// ─── サービス本体 ────────────────────────────────────────────
class BatchImportService {
  BatchImportService._();
  static final instance = BatchImportService._();

  static const _uuid = Uuid();

  // リーダー役割マッピング（テンプレートの表示値 → DB値）
  static const _roleMap = {
    '隊長': 'leader',
    '副長': 'assistant_leader',
    '副長補': 'support',
    'リーダー': 'leader',
  };

  // 団委員区分マッピング
  static const _committeeMap = {
    '団委員': 'committee',
    '他隊指導者': 'other_leader',
    '育成会': 'other',
    'OB': 'ob',
    'その他': 'other',
  };

  // スカウト分類マッピング
  static const _categoryMap = {
    'ビーバー': 'beaver',
    'ビッグビーバー': 'big_beaver',
    '仮入隊': 'provisional',
    '体験': 'experience',
    '兄弟姉妹': 'sibling',
    '上進': 'promoted',
    '退団': 'withdrawn',
    '入隊せず': 'not_joined',
  };

  // アレルギーマッピング
  static const _allergyMap = {
    '鶏卵': 'egg',
    '牛乳': 'dairy',
    '乳製品': 'dairy',
    '牛乳・乳製品': 'dairy',
    '小麦': 'wheat',
    'ソバ': 'soba',
    'そば': 'soba',
    'ピーナッツ': 'peanut',
    '甲殻類': 'shellfish',
    '木の実類': 'tree_nut',
    '果物類': 'fruit',
    '魚類': 'fish',
    '肉類': 'meat',
    'その他': 'other',
  };

  Future<BatchImportResult> importFromBytes({
    required Uint8List bytes,
    required String troopId,
    required Database db,
  }) async {
    final excel = Excel.decodeBytes(bytes);
    final now = DateTime.now().toIso8601String();
    final warnings = <String>[];
    final skipped = <String>[];

    int leaderCount = 0, scoutCount = 0, committeeCount = 0, guardianCount = 0;

    await db.transaction((txn) async {
      // ── 1. リーダー ──────────────────────────────────────
      final leaderSheet = excel.tables['リーダー'];
      if (leaderSheet != null) {
        // 既存リーダー名一覧（重複チェック用）
        final existing = await txn.query('leaders',
            columns: ['name'], where: 'troop_id = ?', whereArgs: [troopId]);
        final existingNames = existing.map((r) => r['name'] as String).toSet();

        for (var i = 2; i < leaderSheet.maxRows; i++) {
          final row = leaderSheet.row(i);
          final lastName = _str(row.length > 0 ? row[0] : null);
          final firstName = _str(row.length > 1 ? row[1] : null);
          if (lastName == null && firstName == null) continue; // 空行スキップ

          final name = [lastName ?? '', firstName ?? ''].where((s) => s.isNotEmpty).join(' ');
          if (name.trim().isEmpty) continue;

          final gender = _gender(_str(row.length > 2 ? row[2] : null));
          final roleRaw = _str(row.length > 3 ? row[3] : null) ?? '';
          final email = _str(row.length > 4 ? row[4] : null) ?? '';
          final phone = _str(row.length > 5 ? row[5] : null);
          final retiredRaw = _str(row.length > 6 ? row[6] : null);
          final isRetired = (retiredRaw != null && retiredRaw.contains('〇')) ? 1 : 0;

          final role = _roleMap[roleRaw] ?? 'support';

          if (existingNames.contains(name)) {
            skipped.add('リーダー「$name」は既に登録済みのためスキップ');
            continue;
          }
          if (!_roleMap.containsKey(roleRaw) && roleRaw.isNotEmpty) {
            warnings.add('リーダー「$name」の役割「$roleRaw」は不明。補助者として登録');
          }

          await txn.insert('leaders', {
            'id': _uuid.v4(),
            'troop_id': troopId,
            'name': name,
            'gender': gender,
            'email': email,
            'phone': phone,
            'role': role,
            'is_active': 1,
            'is_retired': isRetired,
            'created_at': now,
            'updated_at': now,
          });
          existingNames.add(name);
          leaderCount++;
        }
      }

      // ── 2. スカウト ──────────────────────────────────────
      final scoutSheet = excel.tables['スカウト'];
      if (scoutSheet != null) {
        final existing = await txn.query('scouts',
            columns: ['name'], where: 'troop_id = ?', whereArgs: [troopId]);
        final existingNames = existing.map((r) => r['name'] as String).toSet();

        for (var i = 2; i < scoutSheet.maxRows; i++) {
          final row = scoutSheet.row(i);
          final lastName = _str(row.length > 0 ? row[0] : null);
          final firstName = _str(row.length > 1 ? row[1] : null);
          if (lastName == null && firstName == null) continue;

          final name = [lastName ?? '', firstName ?? ''].where((s) => s.isNotEmpty).join(' ');
          if (name.trim().isEmpty) continue;

          final gender = _gender(_str(row.length > 2 ? row[2] : null));
          final gradeRaw = _str(row.length > 3 ? row[3] : null);
          final grade = _normalizeGrade(gradeRaw);
          final categoryRaw = _str(row.length > 4 ? row[4] : null) ?? '';
          final category = _categoryMap[categoryRaw] ?? 'beaver';
          final birthdayRaw = _str(row.length > 5 ? row[5] : null);
          final birthday = _normalizeDate(birthdayRaw);
          final allergyRaw = _str(row.length > 6 ? row[6] : null);
          final allergies = _parseAllergies(allergyRaw);
          final specialNotes = _str(row.length > 7 ? row[7] : null);

          if (existingNames.contains(name)) {
            skipped.add('スカウト「$name」は既に登録済みのためスキップ');
            continue;
          }
          if (!_categoryMap.containsKey(categoryRaw) && categoryRaw.isNotEmpty) {
            warnings.add('スカウト「$name」の分類「$categoryRaw」は不明。ビーバーとして登録');
          }

          final isActive = ['promoted', 'withdrawn', 'not_joined'].contains(category) ? 0 : 1;

          await txn.insert('scouts', {
            'id': _uuid.v4(),
            'troop_id': troopId,
            'name': name,
            'gender': gender,
            'grade': grade,
            'category': category,
            'birthday': birthday,
            'allergies': allergies.isEmpty ? null : allergies.join(','),
            'special_notes': specialNotes,
            'leaf_badges': 0,
            'leaf_badge_offset': 0,
            'twig_badges': 0,
            'is_active': isActive,
            'created_at': now,
            'updated_at': now,
          });
          existingNames.add(name);
          scoutCount++;
        }
      }

      // ── 3. 団委員ほか ─────────────────────────────────────
      final committeeSheet = excel.tables['団委員ほか'];
      if (committeeSheet != null) {
        final existing = await txn.query('committee_members',
            columns: ['name'], where: 'troop_id = ?', whereArgs: [troopId]);
        final existingNames = existing.map((r) => r['name'] as String).toSet();

        for (var i = 2; i < committeeSheet.maxRows; i++) {
          final row = committeeSheet.row(i);
          final lastName = _str(row.length > 0 ? row[0] : null);
          final firstName = _str(row.length > 1 ? row[1] : null);
          if (lastName == null && firstName == null) continue;

          final name = [lastName ?? '', firstName ?? ''].where((s) => s.isNotEmpty).join(' ');
          if (name.trim().isEmpty) continue;

          final gender = _gender(_str(row.length > 2 ? row[2] : null));
          final categoryRaw = _str(row.length > 3 ? row[3] : null) ?? '';
          final category = _committeeMap[categoryRaw] ?? 'other';
          final email = _str(row.length > 4 ? row[4] : null);
          final phone = _str(row.length > 5 ? row[5] : null);
          final retiredRaw = _str(row.length > 6 ? row[6] : null);
          final isRetired = (retiredRaw != null && retiredRaw.contains('〇')) ? 1 : 0;

          if (existingNames.contains(name)) {
            skipped.add('団委員「$name」は既に登録済みのためスキップ');
            continue;
          }
          if (!_committeeMap.containsKey(categoryRaw) && categoryRaw.isNotEmpty) {
            warnings.add('団委員「$name」の区分「$categoryRaw」は不明。その他として登録');
          }

          await txn.insert('committee_members', {
            'id': _uuid.v4(),
            'troop_id': troopId,
            'name': name,
            'gender': gender,
            'category': category,
            'email': email,
            'phone': phone,
            'is_retired': isRetired,
            'created_at': now,
            'updated_at': now,
          });
          existingNames.add(name);
          committeeCount++;
        }
      }

      // ── 4. 保護者 ─────────────────────────────────────────
      final guardianSheet = excel.tables['保護者'];
      if (guardianSheet != null) {
        final existing = await txn.query('guardians',
            columns: ['name'], where: 'troop_id = ?', whereArgs: [troopId]);
        final existingNames = existing.map((r) => r['name'] as String).toSet();

        for (var i = 2; i < guardianSheet.maxRows; i++) {
          final row = guardianSheet.row(i);
          final lastName = _str(row.length > 0 ? row[0] : null);
          final firstName = _str(row.length > 1 ? row[1] : null);
          if (lastName == null && firstName == null) continue;

          final name = [lastName ?? '', firstName ?? ''].where((s) => s.isNotEmpty).join(' ');
          if (name.trim().isEmpty) continue;

          final gender = _gender(_str(row.length > 2 ? row[2] : null));
          final email = _str(row.length > 3 ? row[3] : null);
          final phone = _str(row.length > 4 ? row[4] : null);

          if (existingNames.contains(name)) {
            skipped.add('保護者「$name」は既に登録済みのためスキップ');
            continue;
          }

          await txn.insert('guardians', {
            'id': _uuid.v4(),
            'troop_id': troopId,
            'name': name,
            'gender': gender,
            'email': email,
            'phone': phone,
            'created_at': now,
            'updated_at': now,
          });
          existingNames.add(name);
          guardianCount++;
        }
      }
    });

    debugPrint('BatchImport: leaders=$leaderCount scouts=$scoutCount '
        'committees=$committeeCount guardians=$guardianCount '
        'warnings=${warnings.length} skipped=${skipped.length}');

    return BatchImportResult(
      leaders: leaderCount,
      scouts: scoutCount,
      committees: committeeCount,
      guardians: guardianCount,
      warnings: warnings,
      skipped: skipped,
    );
  }

  // ─── ユーティリティ ─────────────────────────────────────────

  static String _gender(String? raw) {
    if (raw == null) return 'other';
    if (raw.contains('男')) return 'male';
    if (raw.contains('女')) return 'female';
    return 'other';
  }

  static String _normalizeGrade(String? raw) {
    if (raw == null) return 'other';
    final s = raw.trim()
        .replaceAll('１', '1')
        .replaceAll('２', '2')
        .replaceAll('３', '3')
        .replaceAll('４', '4');
    switch (s) {
      case '小1': return '小1';
      case '小2': return '小2';
      case '小3': return '小3';
      case '小4': return '小4';
      case '年長': return '年長';
      case '年中': return '年中';
      case '年少': return '年少';
      case '未就学': return '未就学';
      default: return 'other';
    }
  }

  /// YYYY-MM-DD 形式に正規化（Excelの日付型も対応）
  static String? _normalizeDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();
    // すでに YYYY-MM-DD
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;
    // YYYY/MM/DD
    if (RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(s)) {
      return s.replaceAll('/', '-');
    }
    return null;
  }

  /// カンマ区切りのアレルギー文字列をDB値リストへ変換
  static List<String> _parseAllergies(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => _allergyMap[s] ?? 'other')
        .toSet() // 重複排除
        .toList();
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
      // 日付シリアル値の場合は変換
      raw = v.value.toString();
    } else if (v is DateCellValue) {
      raw = '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    } else if (v is BoolCellValue) {
      raw = v.value ? '〇' : '';
    } else {
      raw = v.toString();
    }
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }

  static String _spanText(dynamic span) {
    if (span == null) return '';
    String result = '';
    try {
      final t = (span as dynamic).text;
      if (t != null) result += t.toString();
    } catch (_) {}
    try {
      final children = (span as dynamic).children;
      if (children != null) {
        for (final c in children) result += _spanText(c);
      }
    } catch (_) {}
    if (result.isEmpty) {
      final s = span.toString();
      if (!s.startsWith('Instance of')) result = s;
    }
    return result;
  }
}
