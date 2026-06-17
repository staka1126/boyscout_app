import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/providers/app_state_provider.dart';
import '../auth/auth_service.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                    color: cs.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.home_work_outlined,
                    size: 52, color: cs.onPrimaryContainer),
              )),
              const SizedBox(height: 32),
              Text('ビーバーログへようこそ',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('団情報を登録するか、招待コードで既存の団に参加してください。',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('はじめる前に', style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    _Note('団情報を登録してください'),
                    _Note('リーダーを1名以上登録してください'),
                    _Note('スカウトを1名以上登録してください'),
                    _Note('リーダー・スカウトが揃うとイベントを作成できます'),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              FilledButton.icon(
                onPressed: () => context.push('/settings/troop'),
                icon: const Icon(Icons.add),
                label: const Text('新しく団を登録する'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: () => _showInviteCodeDialog(),
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('招待コードで参加する'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 12),

              TextButton.icon(
                onPressed: _logout,
                icon: Icon(Icons.logout, size: 16, color: cs.onSurfaceVariant),
                label: Text('ログアウト',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('troop_id');
    ref.read(currentTroopIdProvider.notifier).state = null;
    await AuthService.instance.signOut();
    if (mounted) context.go('/login');
  }

  Future<void> _showInviteCodeDialog() async {
    final codeCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('招待コードで参加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('管理者から受け取った6桁のコードを入力してください。'),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: '招待コード',
                  hintText: 'A3K9PQ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.length != 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('6桁のコードを入力してください')),
                  );
                  return;
                }
                setDialogState(() {});
                try {
                  final troopId = await AuthService.instance.joinWithInviteCode(code);

                  // SharedPreferences と Riverpod 状態を更新
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('troop_id', troopId);

                  if (ctx.mounted) Navigator.pop(ctx);

                  if (mounted) {
                    ref.read(currentTroopIdProvider.notifier).state = troopId;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('団への参加が完了しました'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    context.go('/dashboard');
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.red[700],
                      ),
                    );
                  }
                }
              },
              child: const Text('参加する'),
            ),
          ],
        ),
      ),
    );
    codeCtrl.dispose();
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('・ ', style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Expanded(child: Text(text, style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ]),
    );
  }
}
