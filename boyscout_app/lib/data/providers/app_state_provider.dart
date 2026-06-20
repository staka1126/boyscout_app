import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../local/database_helper.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../sync/sync_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/supabase_config.dart';

// ─── 現在の団ID ───────────────────────────────────────────────
final currentTroopIdProvider = StateProvider<String?>((ref) => null);

// ─── ログイン処理中フラグ（trueの間はルーターのリダイレクトを抑制）
final isLoggingInProvider = StateProvider<bool>((ref) => false);

// ─── 起動時に団を読み込み、Supabaseから同期する ──────────────
final initTroopProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('troop_id');
  final repo = ref.read(troopRepositoryProvider);

  String? troopId;

  if (saved != null) {
    final troops = await repo.getAll();
    if (troops.any((t) => t.id == saved)) {
      troopId = saved;
    }
  }

  if (troopId == null) {
    final first = await repo.getFirst();
    if (first != null) {
      troopId = first.id;
      await prefs.setString('troop_id', troopId);
    }
  }

  // Supabaseにログイン済みの場合、troop_membersの存在確認
  if (troopId != null && SupabaseConfig.isSignedIn) {
    try {
      final user = SupabaseConfig.currentUser;
      if (user != null) {
        final member = await SupabaseConfig.client
            .from('troop_members')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (member == null) {
          // troop_membersにレコードがない → ローカルDBをリセットしてオンボーディングへ
          debugPrint('initTroopProvider: troop_members not found, resetting local DB');
          final db = await DatabaseHelper.instance.database;
          await db.transaction((txn) async {
            await txn.execute('DELETE FROM twig_badge_history');
            await txn.execute('DELETE FROM attendances');
            await txn.execute('DELETE FROM event_leaf_badges');
            await txn.execute('DELETE FROM events');
            await txn.execute('DELETE FROM scout_guardians');
            await txn.execute('DELETE FROM committee_members');
            await txn.execute('DELETE FROM guardians');
            await txn.execute('DELETE FROM scouts');
            await txn.execute('DELETE FROM leaders');
            await txn.execute('DELETE FROM troops');
          });
          await prefs.remove('troop_id');
          return null;
        }
      }

      await SyncService.instance.syncFromSupabase(troopId);
    } catch (e) {
      debugPrint('initTroopProvider: error $e');
    }
  }

  if (troopId != null) {
    ref.read(currentTroopIdProvider.notifier).state = troopId;
  }

  return troopId;
});

// ─── 現在のログインユーザー ────────────────────────────────────
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return null;
  final users = await ref.read(userRepositoryProvider).getByTroop(troopId);
  return users.where((u) => u.role == UserRole.leader).firstOrNull ??
      users.firstOrNull;
});
