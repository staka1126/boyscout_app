import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

final _guardiansProvider = FutureProvider<List<Guardian>>((ref) async {
  return ref.read(guardianRepositoryProvider).getAll();
});

class GuardiansListPage extends ConsumerWidget {
  const GuardiansListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_guardiansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('保護者管理')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (guardians) {
          if (guardians.isEmpty) {
            return const Center(child: Text('保護者がいません', style: TextStyle(color: Colors.grey)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: guardians.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final g = guardians[i];
              final subtitle = [
                if (g.email != null) g.email!,
                if (g.phone != null) g.phone!,
              ].join('　');
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Text(g.name.isNotEmpty ? g.name[0] : '?',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSecondaryContainer)),
                  ),
                  title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(subtitle.isEmpty ? '連絡先未登録' : subtitle),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        await context.push('/settings/guardians/${g.id}/edit');
                        ref.invalidate(_guardiansProvider);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error),
                      onPressed: () => _confirmDelete(context, ref, g),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/settings/guardians/new');
          ref.invalidate(_guardiansProvider);
        },
        tooltip: '保護者を追加',
        child: const Icon(Icons.person_add_outlined),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Guardian guardian) async {
    final canDelete = await ref.read(guardianRepositoryProvider).canDelete(guardian.id);
    if (!context.mounted) return;

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('スカウトと紐付いているため削除できません')));
      return;
    }

    final ok = await showDialog<bool>(context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('保護者を削除'),
        content: Text('${guardian.name} を削除しますか？'),
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
      await ref.read(guardianRepositoryProvider).delete(guardian.id);
      ref.invalidate(_guardiansProvider);
    }
  }
}
