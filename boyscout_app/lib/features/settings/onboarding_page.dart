import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              Text('まず団情報を登録してください。',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),

              // 注意書き
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

              FilledButton(
                onPressed: () => context.push('/settings/troop'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('団情報を登録する'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: Text('スキップしてアプリを開く',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
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
