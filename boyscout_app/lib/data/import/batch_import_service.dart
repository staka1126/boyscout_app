/// バッチ登録用 Excel インポートサービス
/// xlsx を archive + 正規表現で直接パース（名前空間問題を回避）
library;

import 'dart:convert';
import 'package:archive/archive.dart';
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
  final List<String> skipped;

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

// ─── xlsx パーサ（正規表現ベース） ──────────────────────────
class _XlsxParser {
  final Map<String, List<List<String?>>> sheets = {};

  _XlsxParser(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final sst = _readSharedStrings(archive);
    final sheetMeta = _readSheetMeta(archive);
    debugPrint('_XlsxParser: sst=${sst.length} entries, sheets=${sheetMeta.map((m) => m['name']).toList()}');
    for (final meta in sheetMeta) {
      final path = 'xl/${meta['path']}';
      final file = archive.findFile(path);
      if (file == null) {
        debugPrint('  sheet file not found: $path');
        continue;
      }
      final xml = utf8.decode(file.content as List<int>, allowMalformed: true);
      final rows = _parseSheet(xml, sst);
      sheets[meta['name']!] = rows;
      debugPrint('  sheet[${meta['name']}]: ${rows.length} rows');
    }
  }

  // sharedStrings: <si>...<t>TEXT</t>...</si>
  List<String> _readSharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    if (file == null) return [];
    final xml = utf8.decode(file.content as List<int>, allowMalformed: true);
    final result = <String>[];
    final siRe = RegExp(r'<si[^>]*>(.*?)</si>', dotAll: true);
    final tRe = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);
    for (final si in siRe.allMatches(xml)) {
      final buf = StringBuffer();
      for (final t in tRe.allMatches(si.group(1)!)) {
        buf.write(_unescape(t.group(1)!));
      }
      result.add(buf.toString());
    }
    return result;
  }

  // workbook.xml から sheet name / rid, rels から path
  List<Map<String, String>> _readSheetMeta(Archive archive) {
    final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
    final ridToPath = <String, String>{};
    if (relsFile != null) {
      final xml = utf8.decode(relsFile.content as List<int>, allowMalformed: true);
      final re = RegExp(r'<Relationship[^>]+Id="([^"]+)"[^>]+Target="([^"]+)"', dotAll: true);
      for (final m in re.allMatches(xml)) {
        ridToPath[m.group(1)!] = m.group(2)!;
      }
    }

    final wbFile = archive.findFile('xl/workbook.xml');
    if (wbFile == null) return [];
    final xml = utf8.decode(wbFile.content as List<int>, allowMalformed: true);

final result = <Map<String, String>>[];
    // name="..." と r:id="..." を個別に抽出（xmlns:r 属性に / が含まれるため <sheet\b[^>]*> は使えない）
    final nameRe = RegExp(r'\bname="([^"]*)"');
    final ridRe  = RegExp(r'\br:id="([^"]*)"');
    // <sheet で始まり /> または </sheet> で終わるブロックを探す
    int start = 0;
    while (true) {
      final si = xml.indexOf('<sheet', start);
      if (si < 0) break;
      final ei = xml.indexOf('>', si);
      if (ei < 0) break;
      final tag = xml.substring(si, ei + 1);
      if (!tag.startsWith('<sheets')) {
        final name = nameRe.firstMatch(tag)?.group(1) ?? '';
        final rid  = ridRe.firstMatch(tag)?.group(1) ?? '';
        final path = ridToPath[rid] ?? 'worksheets/sheet${result.length + 1}.xml';
        if (name.isNotEmpty) result.add({'name': _unescape(name), 'path': path});
      }
      start = ei + 1;
    }
    return result;
  }

  // sheet XML → 2次元リスト
  List<List<String?>> _parseSheet(String xml, List<String> sst) {
    final rows = <List<String?>>[];
    final rowRe = RegExp(r'<row\b[^>]*>(.*?)</row>', dotAll: true);
    final cellRe = RegExp(r'<c\b([^>]*)>(.*?)</c>', dotAll: true);
    final vRe = RegExp(r'<v[^>]*>(.*?)</v>', dotAll: true);
    final isRe = RegExp(r'<is[^>]*>(.*?)</is>', dotAll: true);
    final tRe = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);

    for (final rowM in rowRe.allMatches(xml)) {
      final cells = <String?>[];
      int prevCol = -1;

      for (final cM in cellRe.allMatches(rowM.group(1)!)) {
        final attrs = cM.group(1)!;
        final inner = cM.group(2)!;
        final ref = RegExp(r'r="([^"]*)"').firstMatch(attrs)?.group(1) ?? '';
        final t   = RegExp(r'\bt="([^"]*)"').firstMatch(attrs)?.group(1) ?? '';
        final colIdx = _colIndex(ref);

        while (prevCol + 1 < colIdx) {
          cells.add(null);
          prevCol++;
        }

        String? value;
        if (t == 's') {
          final v = vRe.firstMatch(inner)?.group(1) ?? '';
          final idx = int.tryParse(v);
          value = (idx != null && idx < sst.length) ? sst[idx] : null;
        } else if (t == 'inlineStr') {
          value = tRe.allMatches(isRe.firstMatch(inner)?.group(1) ?? '')
              .map((m) => _unescape(m.group(1)!))
              .join();
        } else {
          final v = vRe.firstMatch(inner)?.group(1) ?? '';
          value = v.isEmpty ? null : v;
        }

        cells.add(value == null || value.isEmpty ? null : value);
        prevCol = colIdx;
      }

      rows.add(cells);
    }
    return rows;
  }

  int _colIndex(String ref) {
    int col = 0;
    for (final r in ref.runes) {
      final c = String.fromCharCode(r);
      if (RegExp(r'[A-Z]').hasMatch(c)) {
        col = col * 26 + (r - 'A'.codeUnitAt(0) + 1);
      } else break;
    }
    return col - 1;
  }

  String _unescape(String s) {
    // 命名実体参照
    var r = s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
    // 数値文字参照 &#xHHHH; および &#DDDD;
    r = r.replaceAllMapped(RegExp(r'&#x([0-9A-Fa-f]+);'), (m) {
      return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
    });
    r = r.replaceAllMapped(RegExp(r'&#([0-9]+);'), (m) {
      return String.fromCharCode(int.parse(m.group(1)!));
    });
    return r;
  }
}

// ─── サービス本体 ────────────────────────────────────────────
class BatchImportService {
  BatchImportService._();
  static final instance = BatchImportService._();

  static const _uuid = Uuid();

  static const _roleMap = {
    '隊長': 'leader',
    '副長': 'assistant_leader',
    '副長補': 'support',
    '補助者': 'support',
    'リーダー': 'leader',
  };

  static const _committeeMap = {
    '団委員': 'committee',
    '他隊指導者': 'other_leader',
    '他隊リーダー': 'other_leader',
    '他団': 'other_troop',
    '育成会': 'other',
    'OB': 'ob',
    'その他': 'other',
  };

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
    late final _XlsxParser xlsx;
    try {
      xlsx = _XlsxParser(bytes);
    } catch (e, st) {
      debugPrint('xlsx parse error: $e\n$st');
      throw Exception('Excelファイルの読み込みに失敗しました: $e');
    }
    debugPrint('xlsx sheets: ${xlsx.sheets.keys.toList()}');

    final now = DateTime.now().toIso8601String();
    final warnings = <String>[];
    final skipped = <String>[];
    int leaderCount = 0, scoutCount = 0, committeeCount = 0, guardianCount = 0;

    try {
      await db.transaction((txn) async {
        // ── 1. リーダー ────────────────────────────────────
        final leaderRows = xlsx.sheets['リーダー'];
        if (leaderRows != null && leaderRows.length > 1) {
          final existing = await txn.query('leaders',
              columns: ['name'], where: 'troop_id = ?', whereArgs: [troopId]);
          final existingNames = existing.map((r) => r['name'] as String).toSet();

          for (var i = 1; i < leaderRows.length; i++) {
            final row = leaderRows[i];
            final lastName = _col(row, 0);
            final firstName = _col(row, 1);
            if (lastName == null && firstName == null) continue;
            final name = [lastName ?? '', firstName ?? ''].where((s) => s.isNotEmpty).join(' ');
            if (name.trim().isEmpty) continue;

            final gender = _gender(_col(row, 2));
            final roleRaw = _col(row, 3) ?? '';
            final email = _col(row, 4) ?? '';
            final phone = _col(row, 5);
            final retiredRaw = _col(row, 6);
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
              'id': _uuid.v4(), 'troop_id': troopId, 'name': name,
              'gender': gender, 'email': email, 'phone': phone,
              'role': role, 'is_active': 1, 'is_retired': isRetired,
              'created_at': now, 'updated_at': now,
            });
            existingNames.add(name);
            leaderCount++;
          }
        }

        // ── 2. スカウト ────────────────────────────────────
        final scoutRows = xlsx.sheets['スカウト'];
        if (scoutRows != null && scoutRows.length > 1) {
          final existing = await txn.query('scouts',
              columns: ['name'], where: 'troop_id = ?', whereArgs: [troopId]);
          final existingNames = existing.map((r) => r['name'] as String).toSet();

          for (var i = 1; i < scoutRows.length; i++) {
            final row = scoutRows[i];
            final lastName = _col(row, 0);
            final firstName = _col(row, 1);
            if (lastName == null && firstName == null) continue;
            final name = [lastName ?? '', firstName ?? ''].where((s) => s.isNotEmpty).join(' ');
            if (name.trim().isEmpty) continue;

            final gender = _gender(_col(row, 2));
            final grade = _normalizeGrade(_col(row, 3));
            final categoryRaw = _col(row, 4) ?? '';
            final category = _categoryMap[categoryRaw] ?? 'beaver';
            final birthday = _normalizeDate(_col(row, 5));
            final allergies = _parseAllergies(_col(row, 6));
            final specialNotes = _col(row, 7);

            if (existingNames.contains(name)) {
              skipped.add('スカウト「$name」は既に登録済みのためスキップ');
              continue;
            }
            if (!_categoryMap.containsKey(categoryRaw) && categoryRaw.isNotEmpty) {
              warnings.add('スカウト「$name」の分類「$categoryRaw」は不明。ビーバーとして登録');
            }
            final isActive = ['promoted', 'withdrawn', 'not_joined'].contains(category) ? 0 : 1;
            await txn.insert('scouts', {
              'id': _uuid.v4(), 'troop_id': troopId, 'name': name,
              'gender': gender, 'grade': grade, 'category': category,
              'birthday': birthday,
              'allergies': allergies.isEmpty ? null : allergies.join(','),
              'special_notes': specialNotes,
              'leaf_badges': 0, 'leaf_badge_offset': 0, 'twig_badges': 0,
              'is_active': isActive, 'created_at': now, 'updated_at': now,
            });
            existingNames.add(name);
            scoutCount++;
          }
        }

        // ── 3. 団委員ほか ──────────────────────────────────
        final committeeRows = xlsx.sheets['団委員ほか'];
        if (committeeRows != null && committeeRows.length > 1) {
          final existing = await txn.query('committee_members',
              columns: ['name'], where: 'troop_id = ?', whereArgs: [troopId]);
          final existingNames = existing.map((r) => r['name'] as String).toSet();

          for (var i = 1; i < committeeRows.length; i++) {
            final row = committeeRows[i];
            final lastName = _col(row, 0);
            final firstName = _col(row, 1);
            if (lastName == null && firstName == null) continue;
            final name = [lastName ?? '', firstName ?? ''].where((s) => s.isNotEmpty).join(' ');
            if (name.trim().isEmpty) continue;

            final gender = _gender(_col(row, 2));
            final categoryRaw = _col(row, 3) ?? '';
            final category = _committeeMap[categoryRaw] ?? 'other';
            final email = _col(row, 4);
            final phone = _col(row, 5);
            final retiredRaw = _col(row, 6);
            final isRetired = (retiredRaw != null && retiredRaw.contains('〇')) ? 1 : 0;

            if (existingNames.contains(name)) {
              skipped.add('団委員「$name」は既に登録済みのためスキップ');
              continue;
            }
            if (!_committeeMap.containsKey(categoryRaw) && categoryRaw.isNotEmpty) {
              warnings.add('団委員「$name」の区分「$categoryRaw」は不明。その他として登録');
            }
            await txn.insert('committee_members', {
              'id': _uuid.v4(), 'troop_id': troopId, 'name': name,
              'gender': gender, 'category': category,
              'email': email, 'phone': phone, 'is_retired': isRetired,
              'created_at': now, 'updated_at': now,
            });
            existingNames.add(name);
            committeeCount++;
          }
        }

        // ── 4. 保護者 ──────────────────────────────────────
        final guardianRows = xlsx.sheets['保護者'];
        if (guardianRows != null && guardianRows.length > 1) {
          final existing = await txn.query('guardians',
              columns: ['name'], where: 'troop_id = ?', whereArgs: [troopId]);
          final existingNames = existing.map((r) => r['name'] as String).toSet();

          for (var i = 1; i < guardianRows.length; i++) {
            final row = guardianRows[i];
            final lastName = _col(row, 0);
            final firstName = _col(row, 1);
            if (lastName == null && firstName == null) continue;
            final name = [lastName ?? '', firstName ?? ''].where((s) => s.isNotEmpty).join(' ');
            if (name.trim().isEmpty) continue;

            final gender = _gender(_col(row, 2));
            final email = _col(row, 3);
            final phone = _col(row, 4);

            if (existingNames.contains(name)) {
              skipped.add('保護者「$name」は既に登録済みのためスキップ');
              continue;
            }
            await txn.insert('guardians', {
              'id': _uuid.v4(), 'troop_id': troopId, 'name': name,
              'gender': gender, 'email': email, 'phone': phone,
              'created_at': now, 'updated_at': now,
            });
            existingNames.add(name);
            guardianCount++;
          }
        }
      });
    } catch (e, st) {
      debugPrint('BatchImport transaction error: $e\n$st');
      rethrow;
    }

    debugPrint('BatchImport: leaders=$leaderCount scouts=$scoutCount '
        'committees=$committeeCount guardians=$guardianCount '
        'warnings=${warnings.length} skipped=${skipped.length}');

    return BatchImportResult(
      leaders: leaderCount, scouts: scoutCount,
      committees: committeeCount, guardians: guardianCount,
      warnings: warnings, skipped: skipped,
    );
  }

  static String? _col(List<String?> row, int index) {
    if (index >= row.length) return null;
    final v = row[index]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static String _gender(String? raw) {
    if (raw == null) return 'other';
    if (raw.contains('男')) return 'male';
    if (raw.contains('女')) return 'female';
    return 'other';
  }

  static String _normalizeGrade(String? raw) {
    if (raw == null) return 'other';
    final s = raw.trim()
        .replaceAll('１', '1').replaceAll('２', '2')
        .replaceAll('３', '3').replaceAll('４', '4');
    const valid = ['小1', '小2', '小3', '小4', '年長', '年中', '年少', '未就学'];
    return valid.contains(s) ? s : 'other';
  }

  static String? _normalizeDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;
    if (RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(s)) return s.replaceAll('/', '-');
    final serial = double.tryParse(s);
    if (serial != null && serial > 1000) {
      final date = DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    return null;
  }

  static List<String> _parseAllergies(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)
        .map((s) => _allergyMap[s] ?? 'other').toSet().toList();
  }
}
