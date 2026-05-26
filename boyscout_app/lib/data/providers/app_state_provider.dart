import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../../core/constants/app_constants.dart';

// ─── 現在の団ID ───────────────────────────────────────────────
final currentTroopIdProvider = StateProvider<String?>((ref) => null);

// ─── 起動時に団を読み込む ────────────────────────────────────
final initTroopProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('troop_id');
  final repo = ref.read(troopRepositoryProvider);

  if (saved != null) {
    final troops = await repo.getAll();
    if (troops.any((t) => t.id == saved)) {
      ref.read(currentTroopIdProvider.notifier).state = saved;
      return saved;
    }
  }

  final first = await repo.getFirst();
  if (first != null) {
    await prefs.setString('troop_id', first.id);
    ref.read(currentTroopIdProvider.notifier).state = first.id;
    return first.id;
  }
  return null;
});

// ─── 現在のログインユーザー ────────────────────────────────────
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return null;
  final users = await ref.read(userRepositoryProvider).getByTroop(troopId);
  // 隊長を優先、いなければ最初のユーザー
  return users.where((u) => u.role == UserRole.leader).firstOrNull ??
      users.firstOrNull;
});
