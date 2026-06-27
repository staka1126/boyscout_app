import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/wood_grain_background.dart';
import '../dashboard/dashboard_page.dart';

final usersProvider = FutureProvider<List<AppUser>>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return [];
  return ref.read(userRepositoryProvider).getByTroop(troopId);
});

class UsersListPage extends ConsumerWidget {
  const UsersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(usersProvider);
    final troopId = ref.watch(currentTroopIdProvider);

    return Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('リーダー管理')),
    body: Stack(children: [
    const WoodGrainBackground(),
    troopId == null
      ? _NoTroopView()
      : async.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(child: Text('エラー: $e')),
    data: (users) {
    if (users.isEmpty) {
      return const Center(child: Text('リーダーがいません', style: TextStyle(color: Colors.grey)));
    }
    // 現役→引退の順
    final sorted = [...users]..sort((a, b) {
        if (a.isRetired == b.isRetired) return a.name.compareTo(b.name);
      return a.isRetired ? 1 : -1;
    });
    return ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: sorted.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (_, i) {
    final u = sorted[i];
    final cs = Theme.of(context).colorScheme;
    return Opacity(
    opacity: u.isRetired ? 0.5 : 1.0,
    child: Card(
    child: ListTile(
    leading: CircleAvatar(
    backgroundColor: u.isRetired
    ? cs.surfaceContainerHighest
    : cs.primaryContainer,
      child: Text(u.name.isNotEmpty ? u.name[0] : '?',
          style: TextStyle(fontWeight: FontWeight.w700,
            color: u.isRetired ? cs.onSurfaceVariant : cs.onPrimaryContainer)),
    ),
    title: Row(children: [
    Expanded(child: Text(u.name,
    style: const TextStyle(fontWeight: FontWeight.w600))),
    if (u.isRetired)
    Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
    color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12)),
          child: Text('引退',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ),
    ]),
      subtitle: Text('${u.role.label}　${u.email}'),
        trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/users/${u.id}'),
            ),
            ),
          );
          },
          );
        },
      ),
      ]),
      floatingActionButton: troopId != null
          ? FloatingActionButton(
              onPressed: () async {
                await context.push('/settings/users/new');
                ref.invalidate(usersProvider);
              },
              tooltip: 'リーダーを追加',
              child: const Icon(Icons.person_add_outlined),
            )
          : null,
    );
  }
}

class _NoTroopView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.warning_amber_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
      const SizedBox(height: 12),
      const Text('先に団情報を登録してください'),
      const SizedBox(height: 16),
      FilledButton(
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 24)),
        onPressed: () => context.go('/settings/troop'),
        child: const Text('団情報を登録する'),
      ),
    ]));
  }
}
