import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';

final _committeeProvider = FutureProvider<List<CommitteeMember>>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return [];
  return ref.read(committeeRepositoryProvider).getByTroop(troopId);
});

class CommitteeListPage extends ConsumerWidget {
  const CommitteeListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_committeeProvider);
    final troopId = ref.watch(currentTroopIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('団委員ほか管理')),
      body: troopId == null
          ? _NoTroopView()
          : async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (members) {
          if (members.isEmpty) {
            return const Center(
                child: Text('団委員が登録されていません',
                    style: TextStyle(color: Colors.grey)));
          }
          // 現役→引退の順
          final sorted = [...members]..sort((a, b) {
              if (a.isRetired == b.isRetired) return a.name.compareTo(b.name);
              return a.isRetired ? 1 : -1;
            });
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = sorted[i];
              final cs = Theme.of(context).colorScheme;
              final subtitle = [
                m.category.label,
                if (m.email != null) m.email!,
                if (m.phone != null) m.phone!,
              ].join('　');
              return Opacity(
                opacity: m.isRetired ? 0.5 : 1.0,
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: m.isRetired
                          ? cs.surfaceContainerHighest
                          : cs.tertiaryContainer,
                      child: Text(m.name.isNotEmpty ? m.name[0] : '?',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: m.isRetired
                                  ? cs.onSurfaceVariant
                                  : cs.onTertiaryContainer)),
                    ),
                    title: Row(children: [
                      Expanded(child: Text(m.name,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      if (m.isRetired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text('引退',
                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ),
                    ]),
                    subtitle: Text(subtitle),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          await context.push('/settings/committee/${m.id}/edit');
                          ref.invalidate(_committeeProvider);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        onPressed: () => _confirmDelete(context, ref, m),
                      ),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: troopId != null
          ? FloatingActionButton(
              onPressed: () async {
                await context.push('/settings/committee/new');
                ref.invalidate(_committeeProvider);
              },
              tooltip: '団委員を追加',
              child: const Icon(Icons.person_add_outlined),
            )
          : null,
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, CommitteeMember member) async {
    final canDelete = await ref.read(committeeRepositoryProvider).canDelete(member.id);
    if (!context.mounted) return;
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('出欠履歴があるため削除できません')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('団委員を削除'),
        content: Text('${member.name} を削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(false),
              child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(committeeRepositoryProvider).delete(member.id);
      ref.invalidate(_committeeProvider);
    }
  }
}

class _NoTroopView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.warning_amber_outlined, size: 48,
          color: Theme.of(context).colorScheme.outline),
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
