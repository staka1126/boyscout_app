import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../core/supabase_config.dart';

/// Supabase ↔ ローカルSQLite の双方向同期サービス
///
/// 方針：
/// - Supabase がマスター、ローカルはキャッシュ
/// - 起動時・ログイン時に Supabase → ローカルへ全件同期
/// - データ変更時はローカルに書いた後 Supabase にも書く
/// - コンフリクトは Last-Write-Wins（updated_at が新しい方を採用）
class SyncService {
  SyncService._();
  static final instance = SyncService._();

  final _client = SupabaseConfig.client;
  final _dbHelper = DatabaseHelper.instance;

  bool _isSyncing = false;
  final Set<String> _syncedTroopIds = {};

  /// セッション中の同期済みフラグをリセット（ログアウト時に呼ぶ）
  void resetSyncedFlag() => _syncedTroopIds.clear();

  // ─────────────────────────────────────────────────────────
  // Supabase → ローカル（ダウンロード同期）
  // ─────────────────────────────────────────────────────────
  Future<void> syncFromSupabase(String troopId, {bool force = false}) async {
    if (!force && _syncedTroopIds.contains(troopId)) {
      debugPrint('syncFromSupabase: already synced for $troopId, skipped');
      return;
    }
    if (_isSyncing) {
      debugPrint('syncFromSupabase: already running, skipped');
      return;
    }
    _isSyncing = true;
    try {
      final db = await _dbHelper.database;

      await _syncTroop(db, troopId);
      await _syncUsers(db, troopId);
      await _syncScouts(db, troopId);
      await _syncGuardians(db, troopId);
      await _syncScoutGuardians(db, troopId);
      await _syncCommitteeMembers(db, troopId);
      await _syncEvents(db, troopId);
      await _syncEventLeafBadges(db, troopId);
      await _syncAttendances(db, troopId);
      await _syncEventStats(db, troopId);
      _syncedTroopIds.add(troopId);
    } catch (e) {
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // ローカル → Supabase（アップロード同期）
  // ─────────────────────────────────────────────────────────
  Future<void> syncToSupabase(String troopId) async {
    try {
      final db = await _dbHelper.database;

      await _uploadTable(db, 'leaders', troopId: troopId);
      await _uploadTable(db, 'scouts', troopId: troopId);
      await _uploadGuardians(db, troopId);
      await _uploadTable(db, 'committee_members', troopId: troopId);
      await _uploadTable(db, 'events', troopId: troopId);
      await _uploadEventLeafBadges(db, troopId);
      await _uploadAttendances(db, troopId);
      await _uploadEventStats(db, troopId);
    } catch (e) {
      // アップロード失敗はローカル操作に影響しない
    }
  }

  // ─────────────────────────────────────────────────────────
  // 個別テーブルのダウンロード
  // ─────────────────────────────────────────────────────────

  Future<void> _syncTroop(Database db, String troopId) async {
    final rows = await _client.from('troops').select().eq('id', troopId);
    for (final row in rows as List) {
      await db.insert('troops', _troopFromSupabase(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _syncUsers(Database db, String troopId) async {
    final rows = await _client.from('leaders').select().eq('troop_id', troopId);
    for (final row in rows as List) {
      await db.insert('leaders', _normalize(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _syncScouts(Database db, String troopId) async {
    final rows = await _client.from('scouts').select().eq('troop_id', troopId);
    for (final row in rows as List) {
      await db.insert('scouts', _normalize(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _syncGuardians(Database db, String troopId) async {
    final scoutRows = await _client.from('scouts').select('id').eq('troop_id', troopId);
    final scoutIds = (scoutRows as List).map((r) => r['id'] as String).toList();
    if (scoutIds.isEmpty) return;

    final sgRows = await _client.from('scout_guardians')
        .select()
        .inFilter('scout_id', scoutIds);
    final guardianIds = (sgRows as List).map((r) => r['guardian_id'] as String).toSet().toList();
    if (guardianIds.isEmpty) return;

    final gRows = await _client.from('guardians')
        .select()
        .inFilter('id', guardianIds);
    for (final row in gRows as List) {
      await db.insert('guardians', _normalize(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _syncScoutGuardians(Database db, String troopId) async {
    final scoutRows = await _client.from('scouts').select('id').eq('troop_id', troopId);
    final scoutIds = (scoutRows as List).map((r) => r['id'] as String).toList();
    if (scoutIds.isEmpty) return;

    final rows = await _client.from('scout_guardians')
        .select()
        .inFilter('scout_id', scoutIds);
    for (final row in rows as List) {
      await db.insert('scout_guardians', _normalize(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _syncCommitteeMembers(Database db, String troopId) async {
    final rows = await _client.from('committee_members').select().eq('troop_id', troopId);
    for (final row in rows as List) {
      await db.insert('committee_members', _normalize(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _syncEvents(Database db, String troopId) async {
    final rows = await _client.from('events').select().eq('troop_id', troopId);
    for (final row in rows as List) {
      await db.insert('events', _normalize(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _syncEventLeafBadges(Database db, String troopId) async {
    final eventRows = await _client.from('events').select('id').eq('troop_id', troopId);
    final eventIds = (eventRows as List).map((r) => r['id'] as String).toList();
    if (eventIds.isEmpty) return;

    final rows = await _client.from('event_leaf_badges')
        .select()
        .inFilter('event_id', eventIds);
    for (final row in rows as List) {
      await db.insert('event_leaf_badges', _normalize(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _syncAttendances(Database db, String troopId) async {
    final eventRows = await _client.from('events').select('id').eq('troop_id', troopId);
    final eventIds = (eventRows as List).map((r) => r['id'] as String).toList();
    if (eventIds.isEmpty) return;

    final rows = await _client.from('attendances')
        .select()
        .inFilter('event_id', eventIds);
    for (final row in rows as List) {
      await db.insert('attendances', _normalize(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// event_stats を Supabase → ローカルに同期
  Future<void> _syncEventStats(Database db, String troopId) async {
    final eventRows = await _client.from('events').select('id').eq('troop_id', troopId);
    final eventIds = (eventRows as List).map((r) => r['id'] as String).toList();
    if (eventIds.isEmpty) return;

    final rows = await _client.from('event_stats')
        .select()
        .inFilter('event_id', eventIds);
    for (final row in rows as List) {
      await db.insert('event_stats', _normalizeEventStats(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _syncTwigBadgeHistory(Database db, String troopId) async {
    final scoutRows = await _client.from('scouts').select('id').eq('troop_id', troopId);
    final scoutIds = (scoutRows as List).map((r) => r['id'] as String).toList();
    if (scoutIds.isEmpty) return;

    final rows = await _client.from('twig_badge_history')
        .select()
        .inFilter('scout_id', scoutIds);
    for (final row in rows as List) {
      await db.insert('twig_badge_history', _normalize(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ─────────────────────────────────────────────────────────
  // 個別テーブルのアップロード
  // ─────────────────────────────────────────────────────────

  Future<void> _uploadTable(Database db, String table, {required String troopId}) async {
    final rows = await db.query(table, where: 'troop_id = ?', whereArgs: [troopId]);
    if (rows.isEmpty) return;
    await _client.from(table).upsert(
        rows.map((r) => Map<String, dynamic>.from(r)).toList());
  }

  Future<void> _uploadGuardians(Database db, String troopId) async {
    final scoutRows = await db.query('scouts', where: 'troop_id = ?', whereArgs: [troopId]);
    final scoutIds = scoutRows.map((r) => r['id'] as String).toList();
    if (scoutIds.isEmpty) return;

    final placeholder = scoutIds.map((_) => '?').join(',');
    final sgRows = await db.query('scout_guardians',
        where: 'scout_id IN ($placeholder)', whereArgs: scoutIds);
    final guardianIds = sgRows.map((r) => r['guardian_id'] as String).toSet().toList();
    if (guardianIds.isEmpty) return;

    final gPlaceholder = guardianIds.map((_) => '?').join(',');
    final gRows = await db.query('guardians',
        where: 'id IN ($gPlaceholder)', whereArgs: guardianIds);

    if (gRows.isNotEmpty) {
      await _client.from('guardians').upsert(
          gRows.map((r) => Map<String, dynamic>.from(r)).toList());
    }
    if (sgRows.isNotEmpty) {
      await _client.from('scout_guardians').upsert(
          sgRows.map((r) => Map<String, dynamic>.from(r)).toList());
    }
  }

  Future<void> _uploadEventLeafBadges(Database db, String troopId) async {
    final eventRows = await db.query('events', where: 'troop_id = ?', whereArgs: [troopId]);
    final eventIds = eventRows.map((r) => r['id'] as String).toList();
    if (eventIds.isEmpty) return;

    final placeholder = eventIds.map((_) => '?').join(',');
    final rows = await db.query('event_leaf_badges',
        where: 'event_id IN ($placeholder)', whereArgs: eventIds);
    if (rows.isEmpty) return;
    await _client.from('event_leaf_badges').upsert(
        rows.map((r) => Map<String, dynamic>.from(r)).toList());
  }

  Future<void> _uploadAttendances(Database db, String troopId) async {
    final eventRows = await db.query('events', where: 'troop_id = ?', whereArgs: [troopId]);
    final eventIds = eventRows.map((r) => r['id'] as String).toList();
    if (eventIds.isEmpty) return;

    final placeholder = eventIds.map((_) => '?').join(',');
    final rows = await db.query('attendances',
        where: 'event_id IN ($placeholder)', whereArgs: eventIds);
    if (rows.isEmpty) return;
    await _client.from('attendances').upsert(
        rows.map((r) => Map<String, dynamic>.from(r)).toList());
  }

  /// event_stats をローカル → Supabase にアップロード
  Future<void> _uploadEventStats(Database db, String troopId) async {
    // event_stats は troop_id を持たないのでイベントID経由で絞り込む
    final eventRows = await db.query('events',
        columns: ['id'], where: 'troop_id = ?', whereArgs: [troopId]);
    final eventIds = eventRows.map((r) => r['id'] as String).toList();
    if (eventIds.isEmpty) return;

    final placeholder = eventIds.map((_) => '?').join(',');
    final rows = await db.query('event_stats',
        where: 'event_id IN ($placeholder)', whereArgs: eventIds);
    if (rows.isEmpty) return;

    // ローカルの updated_at は ISO8601 文字列なので Supabase 向けにそのまま渡す
    await _client.from('event_stats').upsert(
        rows.map((r) => Map<String, dynamic>.from(r)).toList());
  }

  // ─────────────────────────────────────────────────────────
  // ヘルパー
  // ─────────────────────────────────────────────────────────

  Map<String, dynamic> _troopFromSupabase(Map<String, dynamic> row) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': row['id']?.toString() ?? '',
      'name': row['name'] ?? '',
      'location': row['location'],
      'contact': row['contact'],
      'troop_code': null,
      'created_at': row['created_at'] ?? now,
      'updated_at': row['updated_at'] ?? now,
    };
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> row) {
    return row.map((key, value) {
      if (value is bool) return MapEntry(key, value ? 1 : 0);
      return MapEntry(key, value);
    });
  }

  /// event_stats は bool カラムなし・updated_at は TIMESTAMPTZ なのでそのまま渡す
  Map<String, dynamic> _normalizeEventStats(Map<String, dynamic> row) {
    return Map<String, dynamic>.from(row);
  }
}
