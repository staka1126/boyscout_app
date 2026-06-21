import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../core/supabase_config.dart';

/// event_stats テーブルへの統計計算・保存を担うサービス
class EventStatsService {
  EventStatsService._();
  static final instance = EventStatsService._();

  /// 指定イベント1件の統計を計算してローカル保存 → Supabase同期
  Future<void> saveForEvent(String eventId) async {
    final db = await DatabaseHelper.instance.database;
    await _save(db, eventId);
    await _uploadOne(eventId);
  }

  /// 指定イベント複数件を一括再計算
  Future<void> saveForEvents(List<String> eventIds) async {
    final db = await DatabaseHelper.instance.database;
    for (final id in eventIds) {
      await _save(db, id);
    }
    await _uploadMany(eventIds);
  }

  /// 団配下の確定済みイベントをすべて再計算 → Supabase同期
  Future<void> rebuildAllForTroop(String troopId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'events',
      columns: ['id'],
      where: 'troop_id = ? AND status = ?',
      whereArgs: [troopId, 'completed'],
    );
    final eventIds = rows.map((r) => r['id'] as String).toList();
    for (final id in eventIds) {
      await _save(db, id);
    }
    await _uploadMany(eventIds);
  }

  // ─── Supabase アップロード ────────────────────────────────

  Future<void> _uploadOne(String eventId) async {
    if (!SupabaseConfig.isSignedIn) return;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('event_stats',
          where: 'event_id = ?', whereArgs: [eventId]);
      if (rows.isEmpty) return;
      await SupabaseConfig.client
          .from('event_stats')
          .upsert(Map<String, dynamic>.from(rows.first));
    } catch (e) {
      debugPrint('EventStatsService._uploadOne error: $e');
    }
  }

  Future<void> _uploadMany(List<String> eventIds) async {
    if (!SupabaseConfig.isSignedIn || eventIds.isEmpty) return;
    try {
      final db = await DatabaseHelper.instance.database;
      final placeholder = eventIds.map((_) => '?').join(',');
      final rows = await db.query('event_stats',
          where: 'event_id IN ($placeholder)', whereArgs: eventIds);
      if (rows.isEmpty) return;
      await SupabaseConfig.client
          .from('event_stats')
          .upsert(rows.map((r) => Map<String, dynamic>.from(r)).toList());
    } catch (e) {
      debugPrint('EventStatsService._uploadMany error: $e');
    }
  }

  // ─── 統計計算・ローカル保存 ───────────────────────────────

  Future<void> _save(Database db, String eventId) async {
    // 出席者
    final presentRows = await db.rawQuery(
      "SELECT member_type, member_id FROM attendances WHERE event_id = ? AND status = 'present'",
      [eventId],
    );
    // 欠席者（指導者・スカウト対象）
    final absentRows = await db.rawQuery(
      "SELECT member_type, member_id FROM attendances WHERE event_id = ? AND status = 'absent'",
      [eventId],
    );

    // 出席カウンター
    int leaderMale = 0, leaderFemale = 0;
    int guardianMale = 0, guardianFemale = 0;
    int committeeMale = 0, committeeFemale = 0;
    int bigBeaverMale = 0, bigBeaverFemale = 0;
    int beaverMale = 0, beaverFemale = 0;
    int provisionalMale = 0, provisionalFemale = 0;
    int experienceMale = 0, experienceFemale = 0;
    int siblingMale = 0, siblingFemale = 0;
    int otherChildMale = 0, otherChildFemale = 0;

    // 欠席カウンター
    int leaderMaleAbsent = 0, leaderFemaleAbsent = 0;
    int bigBeaverMaleAbsent = 0, bigBeaverFemaleAbsent = 0;
    int beaverMaleAbsent = 0, beaverFemaleAbsent = 0;
    int provisionalMaleAbsent = 0, provisionalFemaleAbsent = 0;

    bool isMale(String? gender) => gender == 'male';

    // 出席集計
    for (final row in presentRows) {
      final type = row['member_type'] as String? ?? '';
      final memberId = row['member_id'] as String?;
      if (memberId == null) continue;

      if (type == 'user') {
        final r = await db.query('leaders', columns: ['gender'], where: 'id = ?', whereArgs: [memberId]);
        final m = isMale(r.isNotEmpty ? r.first['gender'] as String? : null);
        if (m) leaderMale++; else leaderFemale++;
      } else if (type == 'guardian') {
        final r = await db.query('guardians', columns: ['gender'], where: 'id = ?', whereArgs: [memberId]);
        final m = isMale(r.isNotEmpty ? r.first['gender'] as String? : null);
        if (m) guardianMale++; else guardianFemale++;
      } else if (type == 'committee') {
        final r = await db.query('committee_members', columns: ['gender'], where: 'id = ?', whereArgs: [memberId]);
        final m = isMale(r.isNotEmpty ? r.first['gender'] as String? : null);
        if (m) committeeMale++; else committeeFemale++;
      } else if (type == 'scout') {
        final r = await db.query('scouts', columns: ['gender', 'category'], where: 'id = ?', whereArgs: [memberId]);
        if (r.isEmpty) continue;
        final m = isMale(r.first['gender'] as String?);
        switch (r.first['category'] as String? ?? '') {
          case 'big_beaver':  if (m) bigBeaverMale++;  else bigBeaverFemale++;
          case 'beaver':      if (m) beaverMale++;     else beaverFemale++;
          case 'provisional': if (m) provisionalMale++; else provisionalFemale++;
          case 'experience':  if (m) experienceMale++; else experienceFemale++;
          case 'sibling':     if (m) siblingMale++;    else siblingFemale++;
          default:            if (m) otherChildMale++; else otherChildFemale++;
        }
      }
    }

    // 欠席集計（指導者・BBV・BV・仮入隊のみ）
    for (final row in absentRows) {
      final type = row['member_type'] as String? ?? '';
      final memberId = row['member_id'] as String?;
      if (memberId == null) continue;

      if (type == 'user') {
        final r = await db.query('leaders', columns: ['gender'], where: 'id = ?', whereArgs: [memberId]);
        final m = isMale(r.isNotEmpty ? r.first['gender'] as String? : null);
        if (m) leaderMaleAbsent++; else leaderFemaleAbsent++;
      } else if (type == 'scout') {
        final r = await db.query('scouts', columns: ['gender', 'category'], where: 'id = ?', whereArgs: [memberId]);
        if (r.isEmpty) continue;
        final m = isMale(r.first['gender'] as String?);
        switch (r.first['category'] as String? ?? '') {
          case 'big_beaver':  if (m) bigBeaverMaleAbsent++;  else bigBeaverFemaleAbsent++;
          case 'beaver':      if (m) beaverMaleAbsent++;     else beaverFemaleAbsent++;
          case 'provisional': if (m) provisionalMaleAbsent++; else provisionalFemaleAbsent++;
        }
      }
    }

    await db.insert('event_stats', {
      'event_id': eventId,
      // 出席
      'leader_male': leaderMale,
      'leader_female': leaderFemale,
      'guardian_male': guardianMale,
      'guardian_female': guardianFemale,
      'committee_male': committeeMale,
      'committee_female': committeeFemale,
      'big_beaver_male': bigBeaverMale,
      'big_beaver_female': bigBeaverFemale,
      'beaver_male': beaverMale,
      'beaver_female': beaverFemale,
      'provisional_male': provisionalMale,
      'provisional_female': provisionalFemale,
      'experience_male': experienceMale,
      'experience_female': experienceFemale,
      'sibling_male': siblingMale,
      'sibling_female': siblingFemale,
      'other_child_male': otherChildMale,
      'other_child_female': otherChildFemale,
      // 欠席
      'leader_male_absent': leaderMaleAbsent,
      'leader_female_absent': leaderFemaleAbsent,
      'big_beaver_male_absent': bigBeaverMaleAbsent,
      'big_beaver_female_absent': bigBeaverFemaleAbsent,
      'beaver_male_absent': beaverMaleAbsent,
      'beaver_female_absent': beaverFemaleAbsent,
      'provisional_male_absent': provisionalMaleAbsent,
      'provisional_female_absent': provisionalFemaleAbsent,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
