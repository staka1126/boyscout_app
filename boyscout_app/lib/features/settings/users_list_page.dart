import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';

final _usersProvider = FutureProvider<List<AppUser>>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return [];
  return ref.read(userRepositoryProvider).getByTroop(troopId);
});

class UsersListPage extends ConsumerWidget {
  const UsersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_usersProvider);
    final troopId = ref.watch(currentTroopIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('リーダー管理')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('リーダーがいません', style: TextStyle(color: Colors.grey)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final u = users[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(u.name.isNotEmpty ? u.name[0] : '?',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onPrimaryContainer)),
                  ),
                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${u.role.label}　${u.email}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        await context.push('/settings/users/${u.id}/edit');
                        ref.invalidate(_usersProvider);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error),
                      onPressed: () => _confirmDelete(context, ref, u),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: troopId != null
          ? FloatingActionButton(
              onPressed: () async {
                await context.push('/settings/users/new');
                ref.invalidate(_usersProvider);
              },
              tooltip: 'リーダーを追加',
              child: const Icon(Icons.person_add_outlined),
            )
          : null,
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AppUser user) async {
    final canDelete = await ref.read(userRepositoryProvider).canDelete(user.id);
    if (!context.mounted) return;

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('出欠履歴があるため削除できません')));
      return;
    }

    final ok = await showDialog<bool>(context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('リーダーを削除'),
        content: Text('${user.name} を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ));

    if (ok == true && context.mounted) {
      await ref.read(userRepositoryProvider).delete(user.id);
      ref.invalidate(_usersProvider);
    }
  }
}
