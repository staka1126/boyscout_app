import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/models.dart';
import '../../data/providers/app_state_provider.dart';
import '../../data/repositories/repositories.dart';
import '../../core/wood_grain_background.dart';
import '../../core/supabase_config.dart';
import '../../data/sync/sync_service.dart';
import '../auth/auth_service.dart';
import '../auth/auth_provider.dart';
import 'excel_import_page.dart';
import 'batch_register_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'report_page.dart';

final _currentProfileProvider = FutureProvider<Map<String, String?>>((ref) async {
  final isSignedIn = ref.watch(isSignedInProvider);
  if (!isSignedIn) return {};

  final user = SupabaseConfig.currentUser;
  if (user == null) return {};
  try {
    final data = await SupabaseConfig.client
        .from('profiles')
        .select('name, email')
        .eq('id', user.id)
        .maybeSingle();
    final member = await SupabaseConfig.client
        .from('troop_members')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
    return {
      'name': data?['name'] as String?,
      'email': data?['email'] as String?,
      'role': member?['role'] as String?,
    };
  } catch (e) {
    debugPrint('_currentProfileProvider error: $e');
    return {};
  }
});

// 団情報プロバイダー（currentTroopIdProviderに依存）
final _troopInfoProvider = FutureProvider.autoDispose<Map<String, String?>?>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return null;
  try {
    final troop = await SupabaseConfig.client
        .from('troops')
        .select('id, name, location')
        .eq('id', troopId)
        .maybeSingle();
    if (troop == null) return null;
    return {
      'id': troop['id'] as String?,
      'name': troop['name'] as String?,
      'location': troop['location'] as String?,
    };
  } catch (e) {
    print("_troopInfoProvider error: " + e.toString());
    // オフライン時はローカルから取得
    final troop = await ref.read(troopRepositoryProvider).getFirst();
    if (troop == null) return null;
    return {'id': troop.id, 'name': troop.name, 'location': troop.location};
  }
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final profile = ref.watch(_currentProfileProvider);
    final troopAsync = ref.watch(_troopInfoProvider);
    final troopId = ref.watch(currentTroopIdProvider);
    print('troopId=' + troopId.toString());
    final isAdmin = profile.maybeWhen(
      data: (p) => p['role'] == 'admin',
      orElse: () => false,
    );
    final isLimited = profile.maybeWhen(
      data: (p) => p['role'] == 'limited',
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: Stack(children: [
        const WoodGrainBackground(),
        ListView(children: [
          // 団名ヘッダー（currentTroopIdがある場合のみ表示）
          troopAsync.maybeWhen(
            data: (troop) {
              if (troop == null) return const SizedBox();
              final name = troop['name'] ?? '';
              final location = troop['location'];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Text(name.isNotEmpty ? name[0] : '?',
                      style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: location != null ? Text(location) : null,
                onTap: isLimited ? null : () => context.go('/settings/troop'),
              );
            },
            orElse: () => const SizedBox(),
          ),
          const Divider(),

          profile.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (p) {
              final name = p['name'] ?? '';
              final email = p['email'] ?? '';
              final role = p['role'] == 'admin' ? '管理者' : p['role'] == 'limited' ? '制限メンバー' : 'メンバー';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.secondaryContainer,
                  child: Text(name.isNotEmpty ? name[0] : '?',
                      style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w700)),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p['role'] == 'admin'
                            ? cs.primaryContainer
                            : p['role'] == 'limited'
                                ? cs.tertiaryContainer
                                : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(role,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: p['role'] == 'admin'
                                  ? cs.onPrimaryContainer
                                  : p['role'] == 'limited'
                                      ? cs.onTertiaryContainer
                                      : cs.onSurfaceVariant)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: '表示名を編集',
                      onPressed: () => _editDisplayName(context, ref, name),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),

          if (!isLimited)
            _tile(context, Icons.home_outlined, '団情報', '/settings/troop'),
          const Divider(),

          _tile(context, Icons.manage_accounts_outlined, 'リーダー', '/settings/users'),
          if (!isLimited) ...[
            _tile(context, Icons.family_restroom_outlined, '保護者', '/settings/guardians'),
            _tile(context, Icons.groups_outlined, '団委員ほか', '/settings/committee'),
          ],
          const Divider(),

          if (!isLimited) ...[
            _tile(context, Icons.contact_phone_outlined, '電話帳', '/settings/phonebook'),
            _tile(context, Icons.no_food_outlined, 'アレルギー情報', '/settings/allergy'),
            const Divider(),
          ],
          
          // レポート出力
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('レポート出力'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportPage()),
            ),  
          ),
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('使い方'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => launchUrl(
              Uri.parse('https://jetter.sakura.ne.jp/beaverlog/manual/index.html'),
              mode: LaunchMode.externalApplication,
            ),
          ),

          const Divider(),          if (isAdmin) ...[
            _tile(context, Icons.supervised_user_circle_outlined, '利用者管理', '/settings/members'),
            _tile(context, Icons.vpn_key_outlined, '招待コード', '/settings/invite-codes'),
            _LongPressBatchTile(context: context),
            const Divider(),
          ],

          ListTile(
            leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
            title: const Text('アカウントを削除する', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
          const Divider(),

          _LongPressVersionTile(
            showHiddenMenu: !isLimited,
            onActivate: () => _confirmClearData(context, ref),
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

  Future<void> _editDisplayName(BuildContext context, WidgetRef ref, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('表示名を編集'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '氏名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dlgCtx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || !context.mounted) return;

    try {
      await AuthService.instance.updateDisplayName(newName);
      ref.invalidate(_currentProfileProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('表示名を更新しました')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.of(dlgCtx).pop(true), child: const Text('ログアウト')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _logout(context, ref);
  }

  static Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('troop_id');
    ref.read(currentTroopIdProvider.notifier).state = null;
    await AuthService.instance.signOut();
    if (context.mounted) context.go('/login');
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    try {
      final member = await SupabaseConfig.client
          .from('troop_members')
          .select('role')
          .eq('user_id', SupabaseConfig.currentUser!.id)
          .maybeSingle();
      if (member != null && (member['role'] as String).trim() == 'admin') {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (dlgCtx) => _AdminDeleteBlockDialog(ref: ref),
          );
        }
        return;
      }
    } catch (e) {
    print("_troopInfoProvider error: " + e.toString());}

    final ok1 = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('アカウントを削除する'),
        content: const Text('アカウントを削除すると、このアプリへのアクセスができなくなります。\n\nローカルデータは端末に残ります。\n\nこの操作は取り消せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
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
        content: const Text('本当にアカウントを削除してよいですか？\n復元する方法はありません。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
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
      await SupabaseConfig.client.rpc('delete_own_account');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('troop_id');
      ref.read(currentTroopIdProvider.notifier).state = null;
      try { await SupabaseConfig.client.auth.signOut(); } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('アカウントを削除しました')));
        context.go('/login');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除に失敗しました: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('データをすべて削除'),
        content: const Text('団・スカウト・イベント・出欠・表彰など\nすべてのローカルデータが削除されます。\n\nこの操作は取り消せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
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
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
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
        await txn.execute('DELETE FROM leaders');
        await txn.execute('DELETE FROM troops');
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ローカルデータを削除しました。ログアウトします。')));
        await _logout(context, ref);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
      }
    }
  }
}

class _LongPressBatchTile extends StatefulWidget {
  final BuildContext context;
  const _LongPressBatchTile({required this.context});

  @override
  State<_LongPressBatchTile> createState() => _LongPressBatchTileState();
}

class _LongPressBatchTileState extends State<_LongPressBatchTile> {
  Timer? _timer;
  bool _pressing = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _timer?.cancel();
    setState(() => _pressing = true);
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _pressing = false);
        Navigator.of(widget.context).push(
          MaterialPageRoute(builder: (_) => const ExcelImportPage()),
        );
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _pressing = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      child: ListTile(
        leading: Icon(
          Icons.group_add_outlined,
          color: _pressing ? Theme.of(context).colorScheme.primary : null,
        ),
        title: const Text('バッチ登録'),
        subtitle: Text(
          _pressing ? '長押してインポートモードへ...' : 'Excelで複数メンバーを一括登録',
          style: TextStyle(
            fontSize: 11,
            color: _pressing ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/batch-register'),
      ),
    );
  }
}

class _LongPressVersionTile extends StatefulWidget {
  final VoidCallback onActivate;
  final bool showHiddenMenu;
  const _LongPressVersionTile({required this.onActivate, this.showHiddenMenu = true});

  @override
  State<_LongPressVersionTile> createState() => _LongPressVersionTileState();
}

class _LongPressVersionTileState extends State<_LongPressVersionTile> {
  Timer? _timer;
  bool _pressing = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.showHiddenMenu) return;
    _timer?.cancel();
    setState(() => _pressing = true);
    _timer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _pressing = false);
        widget.onActivate();
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _pressing = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      child: ListTile(
        leading: Icon(
          Icons.info_outline,
          color: _pressing ? Theme.of(context).colorScheme.error : null,
        ),
        title: const Text('バージョン情報'),
        trailing: Text(
          _version,
          style: TextStyle(
            color: _pressing ? Theme.of(context).colorScheme.error : Colors.grey,
          ),
        ),
      ),
    );
  }
}

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
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? Text('エラー: $_error', style: const TextStyle(color: Colors.red))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('このコードを招待したいメンバーに伝えてください。\n有効期限は7日間です。'),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
      ],
    );
  }
}

class _AdminDeleteBlockDialog extends StatefulWidget {
  final WidgetRef ref;
  const _AdminDeleteBlockDialog({required this.ref});

  @override
  State<_AdminDeleteBlockDialog> createState() => _AdminDeleteBlockDialogState();
}

class _AdminDeleteBlockDialogState extends State<_AdminDeleteBlockDialog> {
  Timer? _timer1;
  Timer? _timer2;
  bool _pressing1 = false;
  bool _pressing2 = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _timer1?.cancel();
    _timer2?.cancel();
    super.dispose();
  }

  void _onTapDown1(TapDownDetails _) {
    _timer1?.cancel();
    if (mounted) setState(() => _pressing1 = true);
    _timer1 = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _pressing1 = false; _showConfirm = true; });
      });
    });
  }

  void _onTapUp1(TapUpDetails _) {
    _timer1?.cancel();
    if (mounted) setState(() => _pressing1 = false);
  }

  void _onTapDown2(TapDownDetails _) {
    _timer2?.cancel();
    if (mounted) setState(() => _pressing2 = true);
    _timer2 = Timer(const Duration(seconds: 10), () {
      if (mounted) _executeDeleteAll();
    });
  }

  void _onTapUp2(TapUpDetails _) {
    _timer2?.cancel();
    if (mounted) setState(() => _pressing2 = false);
  }

  Future<void> _executeDeleteAll() async {
    if (!mounted) return;
    Navigator.of(context).pop();

    try {
      await SupabaseConfig.client.rpc('dissolve_troop');

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
        await txn.execute('DELETE FROM leaders');
        await txn.execute('DELETE FROM troops');
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('troop_id');
      widget.ref.read(currentTroopIdProvider.notifier).state = null;
      await AuthService.instance.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('団から退会しました。ログアウトします。')));
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('失敗しました: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('管理者はアカウントを削除できません'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('管理者アカウントは直接削除できません。\n\n削除するには、先に「利用者管理」で他のメンバーに管理者権限を付与してください。\n\nもしくは、団の利用者全員を強制的に退会させたうえで、再度ログインしてアカウントを削除してください。'),
          if (_showConfirm) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠️ 団の全員を強制退会させる',
                      style: TextStyle(fontWeight: FontWeight.w700, color: cs.onErrorContainer)),
                  const SizedBox(height: 4),
                  Text('この団に所属する全メンバーのアクセスが失われます。\n団のデータはSupabaseから削除されます。\n\n「実行」を10秒長押しすると実行されます。',
                      style: TextStyle(fontSize: 12, color: cs.onErrorContainer)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTapDown: _onTapDown2,
                    onTapUp: _onTapUp2,
                    onTapCancel: () { _timer2?.cancel(); if (mounted) setState(() => _pressing2 = false); },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _pressing2 ? cs.error.withAlpha(200) : cs.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _pressing2 ? '押し続けてください...' : '実行（10秒長押し）',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        if (!_showConfirm)
          GestureDetector(
            onTapDown: _onTapDown1,
            onTapUp: _onTapUp1,
            onTapCancel: () { _timer1?.cancel(); if (mounted) setState(() => _pressing1 = false); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _pressing1 ? cs.error.withAlpha(200) : cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _pressing1 ? '押し続けてください...' : '団全員を強制退会（10秒長押し）',
                style: TextStyle(
                  color: _pressing1 ? Colors.white : cs.onErrorContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
