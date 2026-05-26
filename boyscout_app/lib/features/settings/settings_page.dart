import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final troopId = ref.watch(currentTroopIdProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // ユーザー情報
          userAsync.when(
            loading: () => const ListTile(title: Text('読み込み中...')),
            error: (_, __) => const SizedBox(),
            data: (user) => user == null
                ? const SizedBox()
                : ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0] : '?',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(user.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(user.role.label),
                  ),
          ),
          const Divider(),
          _SectionHeader('団・リーダー管理'),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('団情報'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/troop'),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('リーダー管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/users/new'),
          ),
          ListTile(
            leading: const Icon(Icons.family_restroom_outlined),
            title: const Text('保護者管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/guardians/new'),
          ),
          const Divider(),
          _SectionHeader('アプリ設定'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('バージョン情報'),
            trailing:
                const Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('データをすべて削除',
                style: TextStyle(color: Colors.red)),
            onTap: () => _confirmClearData(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('データを削除'),
        content: const Text('すべてのデータが削除されます。この操作は取り消せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (context.mounted) {
        ref.read(currentTroopIdProvider.notifier).state = null;
        context.go('/settings');
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.8)),
      );
}
