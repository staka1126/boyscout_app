import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/database_helper.dart';
import '../../data/providers/app_state_provider.dart';
import '../../data/repositories/repositories.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final troopAsync = ref.watch(
      FutureProvider((ref) => ref.read(troopRepositoryProvider).getFirst()).future);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          FutureBuilder(
            future: ref.read(troopRepositoryProvider).getFirst(),
            builder: (_, snap) {
              final troop = snap.data;
              if (troop == null) return const SizedBox();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(troop.name.isNotEmpty ? troop.name[0] : '?',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700)),
                ),
                title: Text(troop.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: troop.location != null ? Text(troop.location!) : null,
                onTap: () => context.go('/settings/troop'),
              );
            },
          ),
          const Divider(),
          _tile(context, Icons.home_outlined, '団情報', '/settings/troop'),
          _tile(context, Icons.manage_accounts_outlined, 'リーダー管理', '/settings/users'),
          _tile(context, Icons.people_outline, 'スカウト管理', '/scouts'),
          _tile(context, Icons.family_restroom_outlined, '保護者管理', '/settings/guardians'),
          _tile(context, Icons.groups_outlined, '団委員ほか管理', '/settings/committee'),
          _tile(context, Icons.event_outlined, 'イベント管理', '/events'),
          _tile(context, Icons.military_tech_outlined, '表彰管理', '/badges'),
          _tile(context, Icons.contact_phone_outlined, '電話帳', '/settings/phonebook'),
          _tile(context, Icons.no_food_outlined, 'アレルギー情報', '/settings/allergy'),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('バージョン情報'),
            trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text('データをすべて削除',
                style: TextStyle(color: Colors.red)),
            onTap: () => _confirmClearData(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String path) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(path),
      );

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('データをすべて削除'),
        content: const Text(
            '団・スカウト・イベント・出欠・表彰など\nすべてのデータが完全に削除されます。\n\nこの操作は取り消せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(false),
              child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok1 != true || !context.mounted) return;

    final ok2 = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('本当に削除しますか？'),
        content: const Text('本当にすべてのデータを削除してよいですか？\n復元する方法はありません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(false),
              child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('完全に削除する'),
          ),
        ],
      ),
    );
    if (ok2 != true || !context.mounted) return;

    try {
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
        await txn.execute('DELETE FROM users');
        await txn.execute('DELETE FROM troops');
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (context.mounted) {
        ref.read(currentTroopIdProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('すべてのデータを削除しました')));
        context.go('/onboarding');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
      }
    }
  }
}
