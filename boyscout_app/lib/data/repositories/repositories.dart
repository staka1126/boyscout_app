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
final twigBadgeRepositoryProvider = Provider((_) => TwigBadgeRepository());

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

  Future<void> addLeafBadges(String scoutId, int count) async {
    final db = await _db.database;
    await db.rawUpdate(
        'UPDATE scouts SET leaf_badges = leaf_badges + ?, updated_at = ? WHERE id = ?',
        [count, DateTime.now().toIso8601String(), scoutId]);
    final rows = await db.query('scouts', where: 'id = ?', whereArgs: [scoutId]);
    final troopId = rows.isNotEmpty ? rows.first['troop_id'] as String? : null;
    if (troopId != null) await _syncIfNeeded(troopId);
  }

  Future<void> subtractLeafBadges(String scoutId, int count) async {
    final db = await _db.database;
    await db.rawUpdate(
        'UPDATE scouts SET leaf_badges = MAX(0, leaf_badges - ?), updated_at = ? WHERE id = ?',
        [count, DateTime.now().toIso8601String(), scoutId]);
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
}

// ─── GuardianRepository ──────────────────────────────────────
class GuardianRepository {
  final _db = DatabaseHelper.instance;

  Future<List<Guardian>> getAll() async {
    final db = await _db.database;
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
    final since = DateTime.now().subtract(const Duration(days: 62));
    return (await db.query('events',
            where: 'troop_id = ? AND event_date >= ?',
            whereArgs: [troopId, since.toIso8601String().split('T').first],
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
    required DateTime eventDate, String? location, String? startTime, String? endTime, String? notes,
  }) async {
    final now = DateTime.now();
    final e = Event(id: _uuid.v4(), troopId: troopId, title: title, eventType: eventType,
        status: EventStatus.planned, eventDate: eventDate, location: location,
        startTime: startTime, endTime: endTime, notes: notes, createdAt: now, updatedAt: now);
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
    if (troopId != null) await _syncIfNeeded(troopId);
  }

  Future<void> updateStatus(String id, AttendanceStatus status) async {
    final db = await _db.database;
    await db.update('attendances', {'status': status.value}, where: 'id = ?', whereArgs: [id]);
    // attendance から event → troop を辿って同期
    final rows = await db.query('attendances', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final eventId = rows.first['event_id'] as String;
      final eventRows = await db.query('events', where: 'id = ?', whereArgs: [eventId]);
      final troopId = eventRows.isNotEmpty ? eventRows.first['troop_id'] as String? : null;
      if (troopId != null) await _syncIfNeeded(troopId);
    }
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

  Future<Map<String, double>> getRates(String troopId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT member_id,
        SUM(CASE WHEN status='present' THEN 1 ELSE 0 END) AS p,
        SUM(CASE WHEN status IN ('present','absent') THEN 1 ELSE 0 END) AS t
      FROM attendances
      WHERE event_id IN (SELECT id FROM events WHERE troop_id=?)
        AND member_type IN ('user','scout')
        AND member_id IS NOT NULL
      GROUP BY member_id
    ''', [troopId]);
    return {
      for (final r in rows)
        r['member_id'] as String:
            (r['t'] as int) == 0 ? 0.0 : (r['p'] as int) / (r['t'] as int),
    };
  }
}

// ─── PerfectAttendance ───────────────────────────────────────
class PerfectAttendance {
  final String scoutId;
  final String scoutName;
  final String category;
  final int eventCount;
  PerfectAttendance({required this.scoutId, required this.scoutName, required this.category, required this.eventCount});
}

// ─── TwigBadgeRepository ─────────────────────────────────────
class TwigBadgeRepository {
  final _db = DatabaseHelper.instance;

  Future<List<TwigBadgeHistory>> getByScout(String scoutId) async {
    final db = await _db.database;
    return (await db.query('twig_badge_history', where: 'scout_id = ?',
            whereArgs: [scoutId], orderBy: 'created_at DESC'))
        .map(TwigBadgeHistory.fromMap).toList();
  }

  Future<List<TwigBadgeHistory>> getAll(String troopId) async {
    final db = await _db.database;
    return (await db.rawQuery('''
      SELECT t.* FROM twig_badge_history t
      JOIN scouts s ON s.id = t.scout_id
      WHERE s.troop_id = ?
      ORDER BY t.created_at DESC
    ''', [troopId])).map(TwigBadgeHistory.fromMap).toList();
  }

  Future<TwigBadgeHistory> create({
    required String scoutId, required String scoutName, String? eventId, required String troopId,
  }) async {
    final now = DateTime.now();
    final h = TwigBadgeHistory(id: _uuid.v4(), scoutId: scoutId, scoutName: scoutName,
        eventId: eventId, status: 'pending', createdAt: now, updatedAt: now);
    final db = await _db.database;
    await db.insert('twig_badge_history', h.toMap());
    await _syncIfNeeded(troopId);
    return h;
  }

  Future<void> markAwarded(String id, String troopId) async {
    final db = await _db.database;
    final now = DateTime.now();
    await db.update('twig_badge_history',
        {'status': 'awarded', 'awarded_at': now.toIso8601String().split('T').first, 'updated_at': now.toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
    await _syncIfNeeded(troopId);
  }

  Future<void> deleteByEvent(String eventId, String troopId) async {
    final db = await _db.database;
    await db.delete('twig_badge_history', where: 'event_id = ?', whereArgs: [eventId]);
    if (SupabaseConfig.isSignedIn) {
      try {
        await SupabaseConfig.client.from('twig_badge_history').delete().eq('event_id', eventId);
      } catch (e) {
        debugPrint('TwigBadgeRepository.deleteByEvent Supabase error: $e');
      }
    }
  }
}
