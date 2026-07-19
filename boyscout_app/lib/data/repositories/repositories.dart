import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/database_helper.dart';
import '../models/models.dart';
import '../sync/sync_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/supabase_config.dart';

// ─── Providers ───────────────────────────────────────────────
final troopRepositoryProvider = Provider((_) => TroopRepository());
final userRepositoryProvider = Provider((_) => UserRepository());
final scoutRepositoryProvider = Provider((_) => ScoutRepository());
final guardianRepositoryProvider = Provider((_) => GuardianRepository());
final committeeRepositoryProvider = Provider((_) => CommitteeRepository());
final eventRepositoryProvider = Provider((_) => EventRepository());
final attendanceRepositoryProvider = Provider((_) => AttendanceRepository());

const _uuid = Uuid();

/// ログイン済みかつ団IDがある場合にSupabaseへアップロード同期する
Future<void> _syncIfNeeded(String troopId) async {
  if (!SupabaseConfig.isSignedIn) return;
  try {
    await SyncService.instance.syncToSupabase(troopId);
  } catch (e) {
    debugPrint('_syncIfNeeded error: $e');
  }
}

// ─── TroopRepository ─────────────────────────────────────────
class TroopRepository {
  final _db = DatabaseHelper.instance;

  Future<List<Troop>> getAll() async {
    final db = await _db.database;
    return (await db.query('troops', orderBy: 'name')).map(Troop.fromMap).toList();
  }

  Future<Troop?> getFirst() async {
    final db = await _db.database;
    final rows = await db.query('troops', limit: 1);
    return rows.isEmpty ? null : Troop.fromMap(rows.first);
  }

  Future<Troop> upsert({
    String? id,
    required String name,
    String? location,
    String? contact,
    String? troopCode,
  }) async {
    final now = DateTime.now();
    final troop = Troop(
      id: id ?? _uuid.v4(),
      name: name,
      location: location,
      contact: contact,
      troopCode: troopCode,
      createdAt: now,
      updatedAt: now,
    );
    final db = await _db.database;
    await db.insert('troops', troop.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return troop;
  }
}

// ─── UserRepository ──────────────────────────────────────────
class UserRepository {
  final _db = DatabaseHelper.instance;

  Future<List<AppUser>> getByTroop(String troopId) async {
    final db = await _db.database;
    return (await db.query('leaders', where: 'troop_id = ?', whereArgs: [troopId], orderBy: 'name'))
        .map(AppUser.fromMap).toList();
  }

  Future<AppUser?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('leaders', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<AppUser> create({
    required String troopId, required String name, required String email,
    required UserRole role, String? gender, String? phone,
  }) async {
    final now = DateTime.now();
    final u = AppUser(id: _uuid.v4(), troopId: troopId, name: name, email: email,
        role: role, gender: gender, phone: phone, createdAt: now, updatedAt: now);
    final db = await _db.database;
    await db.insert('leaders', u.toMap());
    await _syncIfNeeded(troopId);
    return u;
  }

  Future<void> update(AppUser u) async {
    final db = await _db.database;
    await db.update('leaders', u.toMap(), where: 'id = ?', whereArgs: [u.id]);
    await _syncIfNeeded(u.troopId);
  }

  Future<bool> canDelete(String id) async {
    final db = await _db.database;
    final rows = await db.query('attendances',
        where: 'member_id = ? AND member_type = "user"', whereArgs: [id]);
    return rows.isEmpty;
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    // troopId を取得してから削除
    final rows = await db.query('leaders', where: 'id = ?', whereArgs: [id]);
    final troopId = rows.isNotEmpty ? rows.first['troop_id'] as String? : null;
    await db.delete('leaders', where: 'id = ?', whereArgs: [id]);
    // Supabaseからも削除
    if (SupabaseConfig.isSignedIn) {
      try {
        await SupabaseConfig.client.from('leaders').delete().eq('id', id);
      } catch (e) {
        debugPrint('UserRepository.delete Supabase error: $e');
      }
    }
    if (troopId != null) await _syncIfNeeded(troopId);
  }
}

// ─── ScoutRepository ─────────────────────────────────────────
class ScoutRepository {
  final _db = DatabaseHelper.instance;

  Future<List<Scout>> getByTroop(String troopId) async {
    final db = await _db.database;
    return (await db.query('scouts', where: 'troop_id = ?', whereArgs: [troopId], orderBy: 'name'))
        .map(Scout.fromMap).toList();
  }

  Future<Scout?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('scouts', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Scout.fromMap(rows.first);
  }

  Future<Scout> create({
    required String troopId, required String name, required ScoutCategory category,
    String? gender, String? grade, int? enrollmentYear, DateTime? joinedAt,
    DateTime? birthday, List<AllergyType> allergies = const [], String? specialNotes,
    int leafBadgeOffset = 0,
  }) async {
    final now = DateTime.now();
    final s = Scout(id: _uuid.v4(), troopId: troopId, name: name, gender: gender,
        grade: grade, category: category, enrollmentYear: enrollmentYear,
        joinedAt: joinedAt, birthday: birthday, allergies: allergies,
        specialNotes: specialNotes,
        leafBadgeOffset: leafBadgeOffset, createdAt: now, updatedAt: now);
    final db = await _db.database;
    await db.insert('scouts', s.toMap());
    await _syncIfNeeded(troopId);
    return s;
  }

  Future<void> update(Scout s) async {
    final db = await _db.database;
    await db.update('scouts', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
    await _syncIfNeeded(s.troopId);
  }

  Future<bool> canDelete(String id) async {
    final db = await _db.database;
    final a = await db.query('attendances',
        where: 'member_id = ? AND member_type = "scout"', whereArgs: [id]);
    final sg = await db.query('scout_guardians', where: 'scout_id = ?', whereArgs: [id]);
    return a.isEmpty && sg.isEmpty;
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    final rows = await db.query('scouts', where: 'id = ?', whereArgs: [id]);
    final troopId = rows.isNotEmpty ? rows.first['troop_id'] as String? : null;
    await db.delete('scouts', where: 'id = ?', whereArgs: [id]);
    if (SupabaseConfig.isSignedIn) {
      try {
        await SupabaseConfig.client.from('scouts').delete().eq('id', id);
      } catch (e) {
        debugPrint('ScoutRepository.delete Supabase error: $e');
      }
    }
    if (troopId != null) await _syncIfNeeded(troopId);
  }

  Future<void> addLeafBadges(String scoutId, int count, {bool sync = true}) async {
    final db = await _db.database;
    await db.rawUpdate(
        'UPDATE scouts SET leaf_badges = leaf_badges + ?, updated_at = ? WHERE id = ?',
        [count, DateTime.now().toIso8601String(), scoutId]);
    if (!sync) return;
    final rows = await db.query('scouts', where: 'id = ?', whereArgs: [scoutId]);
    final troopId = rows.isNotEmpty ? rows.first['troop_id'] as String? : null;
    if (troopId != null) await _syncIfNeeded(troopId);
  }

  Future<void> subtractLeafBadges(String scoutId, int count, {bool sync = true}) async {
    final db = await _db.database;
    await db.rawUpdate(
        'UPDATE scouts SET leaf_badges = MAX(0, leaf_badges - ?), updated_at = ? WHERE id = ?',
        [count, DateTime.now().toIso8601String(), scoutId]);
    if (!sync) return;
    final rows = await db.query('scouts', where: 'id = ?', whereArgs: [scoutId]);
    final troopId = rows.isNotEmpty ? rows.first['troop_id'] as String? : null;
    if (troopId != null) await _syncIfNeeded(troopId);
  }

  Future<void> addTwigBadges(String scoutId, int count) async {
    final db = await _db.database;
    await db.rawUpdate(
        'UPDATE scouts SET twig_badges = twig_badges + ?, updated_at = ? WHERE id = ?',
        [count, DateTime.now().toIso8601String(), scoutId]);
    final rows = await db.query('scouts', where: 'id = ?', whereArgs: [scoutId]);
    final troopId = rows.isNotEmpty ? rows.first['troop_id'] as String? : null;
    if (troopId != null) await _syncIfNeeded(troopId);
  }

  Future<void> addOtherBadges(String scoutId, int count) async {
    final db = await _db.database;
    await db.rawUpdate(
        'UPDATE scouts SET other_badges = other_badges + ?, updated_at = ? WHERE id = ?',
        [count, DateTime.now().toIso8601String(), scoutId]);
    final rows = await db.query('scouts', where: 'id = ?', whereArgs: [scoutId]);
    final troopId = rows.isNotEmpty ? rows.first['troop_id'] as String? : null;
    if (troopId != null) await _syncIfNeeded(troopId);
  }

  /// 小枝章（または他の表彰）の授与履歴を twig_badge_history に記録（count本分）
  Future<void> insertTwigBadgeHistory({
    required String scoutId, required String scoutName, required int count,
    required String troopId, bool sync = true,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (var i = 0; i < count; i++) {
      batch.insert('twig_badge_history', {
        'id': _uuid.v4(), 'scout_id': scoutId, 'scout_name': scoutName, 'event_id': null,
        'status': 'awarded', 'awarded_at': now, 'created_at': now, 'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
    if (!sync) return;
    await _syncIfNeeded(troopId);
  }

  /// 団内の表彰（授与済み）履歴を新しい日付順で取得
  Future<List<TwigBadgeHistory>> getAwardHistory(String troopId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT h.* FROM twig_badge_history h
      JOIN scouts s ON s.id = h.scout_id
      WHERE s.troop_id = ? AND h.status = 'awarded'
      ORDER BY h.awarded_at DESC
    ''', [troopId]);
    return rows.map(TwigBadgeHistory.fromMap).toList();
  }
}

// ─── GuardianRepository ──────────────────────────────────────
class GuardianRepository {
  final _db = DatabaseHelper.instance;

  Future<Guardian?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('guardians', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Guardian.fromMap(rows.first);
  }

  Future<List<Scout>> getScoutsByGuardian(String guardianId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT s.* FROM scouts s
      JOIN scout_guardians sg ON sg.scout_id = s.id
      WHERE sg.guardian_id = ?
      ORDER BY s.name
    ''', [guardianId]);
    return rows.map(Scout.fromMap).toList();
  }

  Future<List<Guardian>> getAll({String? troopId}) async {
    final db = await _db.database;
    if (troopId != null) {
      // troop_idで絞り込む（scout_guardians経由でその団のスカウトに結びついた保護者のみ）
      final rows = await db.rawQuery('''
        SELECT DISTINCT g.* FROM guardians g
        JOIN scout_guardians sg ON sg.guardian_id = g.id
        JOIN scouts s ON s.id = sg.scout_id
        WHERE s.troop_id = ?
        UNION
        SELECT * FROM guardians WHERE troop_id = ?
        ORDER BY name
      ''', [troopId, troopId]);
      return rows.map(Guardian.fromMap).toList();
    }
    return (await db.query('guardians', orderBy: 'name')).map(Guardian.fromMap).toList();
  }

  Future<List<Guardian>> getByScout(String scoutId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT g.* FROM guardians g
      JOIN scout_guardians sg ON sg.guardian_id = g.id
      WHERE sg.scout_id = ?
    ''', [scoutId]);
    return rows.map(Guardian.fromMap).toList();
  }

  Future<Guardian> create({required String name, required String troopId, String? gender, String? email, String? phone}) async {
    final now = DateTime.now();
    final g = Guardian(id: _uuid.v4(), troopId: troopId, name: name, gender: gender, email: email, phone: phone,
        createdAt: now, updatedAt: now);
    final db = await _db.database;
    await db.insert('guardians', g.toMap());
    await _syncIfNeeded(troopId);
    return g;
  }

  Future<void> update(Guardian g) async {
    final db = await _db.database;
    await db.update('guardians', g.toMap(), where: 'id = ?', whereArgs: [g.id]);
    // guardians は troop_id を持たないので scout_guardians 経由で troopId を取得
    if (SupabaseConfig.isSignedIn) {
      try {
        await SupabaseConfig.client.from('guardians').upsert(g.toMap());
      } catch (e) {
        debugPrint('GuardianRepository.update Supabase error: $e');
      }
    }
  }

  Future<void> link({required String scoutId, required String guardianId, String? relationship, required String troopId}) async {
    final db = await _db.database;
    await db.insert('scout_guardians',
        {'id': _uuid.v4(), 'scout_id': scoutId, 'guardian_id': guardianId, 'relationship': relationship},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await _syncIfNeeded(troopId);
  }

  Future<void> unlink({required String scoutId, required String guardianId, required String troopId}) async {
    final db = await _db.database;
    await db.delete('scout_guardians',
        where: 'scout_id = ? AND guardian_id = ?', whereArgs: [scoutId, guardianId]);
    await _syncIfNeeded(troopId);
  }

  Future<bool> canDelete(String id) async {
    final db = await _db.database;
    final sg = await db.query('scout_guardians', where: 'guardian_id = ?', whereArgs: [id]);
    if (sg.isNotEmpty) return false;
    final a = await db.query('attendances',
        where: 'member_id = ? AND member_type = "guardian"', whereArgs: [id]);
    return a.isEmpty;
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('guardians', where: 'id = ?', whereArgs: [id]);
    if (SupabaseConfig.isSignedIn) {
      try {
        await SupabaseConfig.client.from('guardians').delete().eq('id', id);
      } catch (e) {
        debugPrint('GuardianRepository.delete Supabase error: $e');
      }
    }
  }
}

// ─── CommitteeRepository ─────────────────────────────────────
class CommitteeRepository {
  final _db = DatabaseHelper.instance;

  Future<List<CommitteeMember>> getByTroop(String troopId) async {
    final db = await _db.database;
    return (await db.query('committee_members', where: 'troop_id = ?', whereArgs: [troopId], orderBy: 'name'))
        .map(CommitteeMember.fromMap).toList();
  }

  Future<CommitteeMember?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('committee_members', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : CommitteeMember.fromMap(rows.first);
  }

  Future<CommitteeMember> create({
    required String troopId, required String name, required CommitteeCategory category,
    String? gender, String? email, String? phone,
  }) async {
    final now = DateTime.now();
    final cm = CommitteeMember(id: _uuid.v4(), troopId: troopId, name: name, gender: gender,
        category: category, email: email, phone: phone, createdAt: now, updatedAt: now);
    final db = await _db.database;
    await db.insert('committee_members', cm.toMap());
    await _syncIfNeeded(troopId);
    return cm;
  }

  Future<void> update(CommitteeMember cm) async {
    final db = await _db.database;
    await db.update('committee_members', cm.toMap(), where: 'id = ?', whereArgs: [cm.id]);
    await _syncIfNeeded(cm.troopId);
  }

  Future<bool> canDelete(String id) async {
    final db = await _db.database;
    final a = await db.query('attendances',
        where: 'member_id = ? AND member_type = "committee"', whereArgs: [id]);
    return a.isEmpty;
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    final rows = await db.query('committee_members', where: 'id = ?', whereArgs: [id]);
    final troopId = rows.isNotEmpty ? rows.first['troop_id'] as String? : null;
    await db.delete('committee_members', where: 'id = ?', whereArgs: [id]);
    if (SupabaseConfig.isSignedIn) {
      try {
        await SupabaseConfig.client.from('committee_members').delete().eq('id', id);
      } catch (e) {
        debugPrint('CommitteeRepository.delete Supabase error: $e');
      }
    }
    if (troopId != null) await _syncIfNeeded(troopId);
  }
}

// ─── EventRepository ─────────────────────────────────────────
class EventRepository {
  final _db = DatabaseHelper.instance;

  Future<List<Event>> getByTroop(String troopId) async {
    final db = await _db.database;
    return (await db.query('events', where: 'troop_id = ?', whereArgs: [troopId], orderBy: 'event_date ASC'))
        .map(Event.fromMap).toList();
  }

  Future<List<Event>> getRecent(String troopId) async {
    final db = await _db.database;
    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;
    // 2ヶ月後の末日を計算
    final twoMonthsLater = DateTime(now.year, now.month + 2 + 1, 0); // +2ヶ月の月末
    final until = twoMonthsLater.toIso8601String().split('T').first;
    return (await db.query('events',
            where: 'troop_id = ? AND event_date >= ? AND event_date <= ?',
            whereArgs: [troopId, today, until],
            orderBy: 'event_date ASC'))
        .map(Event.fromMap).toList();
  }

  Future<Event?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('events', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Event.fromMap(rows.first);
  }

  Future<Event> create({
    required String troopId, required String title, required EventType eventType,
    required DateTime eventDate, String? location, String? startTime, String? endTime, String? notes, String? planUrl,
  }) async {
    final now = DateTime.now();
    final e = Event(id: _uuid.v4(), troopId: troopId, title: title, eventType: eventType,
        status: EventStatus.planned, eventDate: eventDate, location: location,
        startTime: startTime, endTime: endTime, notes: notes, planUrl: planUrl, createdAt: now, updatedAt: now);
    final db = await _db.database;
    await db.insert('events', e.toMap());
    await _syncIfNeeded(troopId);
    return e;
  }

  Future<void> update(Event e) async {
    final db = await _db.database;
    await db.update('events', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
    await _syncIfNeeded(e.troopId);
  }

  Future<bool> canDelete(String id) async {
    final db = await _db.database;
    final ev = await getById(id);
    if (ev == null || ev.status == EventStatus.completed) return false;
    final rows = await db.query('attendances', where: 'event_id = ?', whereArgs: [id]);
    return rows.isEmpty;
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    final rows = await db.query('events', where: 'id = ?', whereArgs: [id]);
    final troopId = rows.isNotEmpty ? rows.first['troop_id'] as String? : null;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
    if (SupabaseConfig.isSignedIn) {
      try {
        await SupabaseConfig.client.from('events').delete().eq('id', id);
      } catch (e) {
        debugPrint('EventRepository.delete Supabase error: $e');
      }
    }
    if (troopId != null) await _syncIfNeeded(troopId);
  }

  Future<List<EventLeafBadge>> getLeafBadges(String eventId) async {
    final db = await _db.database;
    return (await db.query('event_leaf_badges', where: 'event_id = ?', whereArgs: [eventId]))
        .map(EventLeafBadge.fromMap).toList();
  }

  Future<void> upsertLeafBadge(EventLeafBadge b) async {
    final db = await _db.database;
    await db.insert('event_leaf_badges', b.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    final eventRows = await db.query('events', where: 'id = ?', whereArgs: [b.eventId]);
    final troopId = eventRows.isNotEmpty ? eventRows.first['troop_id'] as String? : null;
    if (troopId != null) await _syncIfNeeded(troopId);
  }
}

// ─── AttendanceRepository ────────────────────────────────────
class AttendanceRepository {
  final _db = DatabaseHelper.instance;

  Future<List<Attendance>> getByEvent(String eventId) async {
    final db = await _db.database;
    return (await db.query('attendances', where: 'event_id = ?', whereArgs: [eventId]))
        .map(Attendance.fromMap).toList();
  }

  /// スカウトの参加履歴（イベント情報＋出欠状態）を新しい日付順で取得
  Future<List<ScoutAttendanceRecord>> getByScout(String scoutId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT e.id AS event_id, e.title AS title, e.event_date AS event_date,
             e.status AS event_status, a.status AS attendance_status
      FROM attendances a
      JOIN events e ON e.id = a.event_id
      WHERE a.member_type = 'scout' AND a.member_id = ?
      ORDER BY e.event_date DESC
    ''', [scoutId]);
    return rows.map(ScoutAttendanceRecord.fromMap).toList();
  }

  /// リーダーの参加履歴（イベント情報＋出欠状態）を新しい日付順で取得
  Future<List<ScoutAttendanceRecord>> getByUser(String userId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT e.id AS event_id, e.title AS title, e.event_date AS event_date,
             e.status AS event_status, a.status AS attendance_status
      FROM attendances a
      JOIN events e ON e.id = a.event_id
      WHERE a.member_type = 'user' AND a.member_id = ?
      ORDER BY e.event_date DESC
    ''', [userId]);
    return rows.map(ScoutAttendanceRecord.fromMap).toList();
  }

  /// 保護者の参加履歴（イベント情報＋出欠状態）を新しい日付順で取得
  Future<List<ScoutAttendanceRecord>> getByGuardian(String guardianId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT e.id AS event_id, e.title AS title, e.event_date AS event_date,
             e.status AS event_status, a.status AS attendance_status
      FROM attendances a
      JOIN events e ON e.id = a.event_id
      WHERE a.member_type = 'guardian' AND a.member_id = ?
      ORDER BY e.event_date DESC
    ''', [guardianId]);
    return rows.map(ScoutAttendanceRecord.fromMap).toList();
  }

  /// 団委員の参加履歴（イベント情報＋出欠状態）を新しい日付順で取得
  Future<List<ScoutAttendanceRecord>> getByCommittee(String committeeId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT e.id AS event_id, e.title AS title, e.event_date AS event_date,
             e.status AS event_status, a.status AS attendance_status
      FROM attendances a
      JOIN events e ON e.id = a.event_id
      WHERE a.member_type = 'committee' AND a.member_id = ?
      ORDER BY e.event_date DESC
    ''', [committeeId]);
    return rows.map(ScoutAttendanceRecord.fromMap).toList();
  }

  Future<void> createDefaults({
    required String eventId, required List<AppUser> users, required List<Scout> scouts,
  }) async {
    final db = await _db.database;
    for (final u in users) {
      try {
        await db.insert('attendances', Attendance(id: _uuid.v4(), eventId: eventId,
            memberType: MemberType.user, memberId: u.id, memberName: u.name,
            status: AttendanceStatus.pending, isDefault: true).toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (_) {}
    }
    for (final s in scouts) {
      if (!s.category.isDefaultAttendee) continue;
      try {
        await db.insert('attendances', Attendance(id: _uuid.v4(), eventId: eventId,
            memberType: MemberType.scout, memberId: s.id, memberName: s.name,
            status: AttendanceStatus.pending, isDefault: true).toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (_) {}
    }
    // イベントの troopId を取得して同期
    final eventRows = await db.query('events', where: 'id = ?', whereArgs: [eventId]);
    final troopId = eventRows.isNotEmpty ? eventRows.first['troop_id'] as String? : null;
    if (troopId != null) await _syncIfNeeded(troopId);
  }

  Future<void> add(Attendance a) async {
    final db = await _db.database;
    await db.insert('attendances', a.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    final eventRows = await db.query('events', where: 'id = ?', whereArgs: [a.eventId]);
    final troopId = eventRows.isNotEmpty ? eventRows.first['troop_id'] as String? : null;
    // ローカル挿入のみ待ち、Supabase同期は投げっぱなしにしてUIをブロックしない
    if (troopId != null) unawaited(_syncIfNeeded(troopId));
  }

  Future<void> updateStatus(String id, AttendanceStatus status) async {
    final db = await _db.database;
    await db.update('attendances', {'status': status.value}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> remove(String id) async {
    final db = await _db.database;
    await db.delete('attendances', where: 'id = ?', whereArgs: [id]);
    if (SupabaseConfig.isSignedIn) {
      try {
        await SupabaseConfig.client.from('attendances').delete().eq('id', id);
      } catch (e) {
        debugPrint('AttendanceRepository.remove Supabase error: $e');
      }
    }
  }

  Future<List<PerfectAttendance>> getPerfectAttendance({
    required String troopId,
    required int year,
  }) async {
    final db = await _db.database;
    final from = '$year-04-01';
    final to   = '${year + 1}-03-31';

    final events = await db.query('events',
        where: 'troop_id = ? AND status = ? AND event_date >= ? AND event_date <= ?',
        whereArgs: [troopId, 'completed', from, to],
        orderBy: 'event_date ASC');
    if (events.isEmpty) return [];

    final eventIds = events.map((e) => e['id'] as String).toList();

    final scouts = await db.query('scouts',
        where: 'troop_id = ? AND category IN (?, ?) AND is_active = 1',
        whereArgs: [troopId, 'beaver', 'big_beaver']);
    if (scouts.isEmpty) return [];

    final result = <PerfectAttendance>[];
    for (final sMap in scouts) {
      final scoutId = sMap['id'] as String;
      bool perfect = true;
      for (final eventId in eventIds) {
        final rows = await db.query('attendances',
            where: 'event_id = ? AND member_id = ? AND member_type = ? AND status = ?',
            whereArgs: [eventId, scoutId, 'scout', 'present']);
        if (rows.isEmpty) { perfect = false; break; }
      }
      if (perfect) {
        result.add(PerfectAttendance(
          scoutId: scoutId,
          scoutName: sMap['name'] as String,
          category: sMap['category'] as String,
          eventCount: eventIds.length,
        ));
      }
    }
    return result;
  }

  Future<({int present, int total})> getRates(String troopId) async {
    final db = await _db.database;
    final now = DateTime.now();
    final fiscalStart = '${now.month >= 4 ? now.year : now.year - 1}-04-01';
    final fiscalEnd   = '${now.month >= 4 ? now.year + 1 : now.year}-03-31';
    final rows = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN status='present' THEN 1 ELSE 0 END) AS p,
        SUM(CASE WHEN status IN ('present','absent') THEN 1 ELSE 0 END) AS t
      FROM attendances
      WHERE event_id IN (
        SELECT id FROM events
        WHERE troop_id=?
          AND status='completed'
          AND event_date >= ?
          AND event_date <= ?
      )
        AND member_type = 'scout'
        AND member_id IN (
          SELECT id FROM scouts
          WHERE troop_id=? AND category IN ('big_beaver','beaver')
        )
        AND member_id IS NOT NULL
    ''', [troopId, fiscalStart, fiscalEnd, troopId]);
    if (rows.isEmpty) return (present: 0, total: 0);
    final p = (rows.first['p'] as int?) ?? 0;
    final t = (rows.first['t'] as int?) ?? 0;
    return (present: p, total: t);
  }
}

// ─── ScoutAttendanceRecord ───────────────────────────────────
class ScoutAttendanceRecord {
  final String eventId;
  final String title;
  final DateTime eventDate;
  final EventStatus eventStatus;
  final AttendanceStatus attendanceStatus;
  ScoutAttendanceRecord({
    required this.eventId, required this.title, required this.eventDate,
    required this.eventStatus, required this.attendanceStatus,
  });

  factory ScoutAttendanceRecord.fromMap(Map<String, dynamic> m) => ScoutAttendanceRecord(
      eventId: m['event_id'] as String,
      title: m['title'] as String,
      eventDate: DateTime.parse(m['event_date'] as String),
      eventStatus: EventStatus.fromValue(m['event_status'] as String),
      attendanceStatus: AttendanceStatus.fromValue(m['attendance_status'] as String));
}

// ─── PerfectAttendance ───────────────────────────────────────
class PerfectAttendance {
  final String scoutId;
  final String scoutName;
  final String category;
  final int eventCount;
  PerfectAttendance({required this.scoutId, required this.scoutName, required this.category, required this.eventCount});
}

