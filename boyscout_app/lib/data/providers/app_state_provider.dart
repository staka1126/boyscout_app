import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  if (troopId != null && SupabaseConfig.isSignedIn) {
    try {
      await SyncService.instance.syncFromSupabase(troopId);
    } catch (e) {
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
