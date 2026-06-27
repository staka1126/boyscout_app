import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../dashboard/dashboard_page.dart';
import 'users_list_page.dart';

final _userDetailProvider = FutureProvider.family<AppUser?, String>((ref, id) async {
  return ref.read(userRepositoryProvider).getById(id);
});

class UserDetailPage extends ConsumerWidget {
  final String id;
  const UserDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_userDetailProvider(id));

    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('エラー: $e'))),
      data: (user) {
        if (user == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('リーダーが見つかりません')));
        }
        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(user.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  await context.push('/settings/users/${user.id}/edit');
                  ref.invalidate(_userDetailProvider(id));
                  ref.invalidate(usersProvider);
                  ref.invalidate(dashboardProvider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, ref, user),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(child: Padding(padding: const EdgeInsets.all(20),
                child: Row(children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: user.isRetired ? cs.surfaceContainerHighest : cs.primaryContainer,
                    child: Text(user.name.isNotEmpty ? user.name[0] : '?',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                            color: user.isRetired ? cs.onSurfaceVariant : cs.onPrimaryContainer)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(user.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                      if (user.isRetired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text('引退', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                      child: Text(user.role.label,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer)),
                    ),
                  ])),
                ]))),
              const SizedBox(height: 12),
              _infoCard(context, '連絡先', [
                if (user.email != null) _InfoRow('メール', user.email!),
                if (user.phone != null) _InfoRow('電話', user.phone!),
                if (user.gender != null)
                  _InfoRow('性別', user.gender == 'male' ? '男性' : user.gender == 'female' ? '女性' : 'その他'),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _infoCard(BuildContext context, String title, List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox();
    return Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        ...rows,
      ])));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AppUser user) async {
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
        content: Text('${user.name} を削除しますか？この操作は取り消せません。'),
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
      ref.invalidate(usersProvider);
      ref.invalidate(dashboardProvider);
      context.go('/settings/users');
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ]));
  }
}
