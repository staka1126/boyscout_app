import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/database_helper.dart';
import '../../data/providers/app_state_provider.dart';
import '../../data/repositories/repositories.dart';
import '../../core/wood_grain_background.dart';
import '../auth/auth_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('設定')),
      body: Stack(children: [
        const WoodGrainBackground(),
        ListView(children: [
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

          // ─── アカウント ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('アカウント',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary)),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('招待コードを発行する'),
            subtitle: const Text('他のメンバーをこの団に招待します'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showGenerateInviteCode(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('ログアウト', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(context),
          ),
          const Divider(),

          // ─── その他 ───────────────────────────────────
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
        ]),
      ]),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String path) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(path),
      );

  // ─── 招待コード発行 ──────────────────────────────────
  Future<void> _showGenerateInviteCode(BuildContext context, WidgetRef ref) async {
    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('団が登録されていません')),
      );
      return;
    }

    // ローディングダイアログを表示しながらコード生成
    String? code;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GenerateCodeDialog(troopId: troopId),
    );
  }

  // ─── ログアウト確認 ──────────────────────────────────
  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await AuthService.instance.signOut();
    if (context.mounted) context.go('/login');
  }

  // ─── データ削除 ──────────────────────────────────────
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

// ─── 招待コード生成ダイアログ ────────────────────────────────
class _GenerateCodeDialog extends StatefulWidget {
  final String troopId;
  const _GenerateCodeDialog({required this.troopId});

  @override
  State<_GenerateCodeDialog> createState() => _GenerateCodeDialogState();
}

class _GenerateCodeDialogState extends State<_GenerateCodeDialog> {
  String? _code;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final code = await AuthService.instance.generateInviteCode(widget.troopId);
      if (mounted) setState(() { _code = code; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('招待コード'),
      content: _isLoading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
              ? Text('エラー: $_error', style: const TextStyle(color: Colors.red))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('このコードを招待したいメンバーに伝えてください。\n有効期限は7日間です。'),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _code!,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _code!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('コードをコピーしました')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('コピー'),
                    ),
                  ],
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
