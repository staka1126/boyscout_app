import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';

class ScoutDetailPage extends ConsumerWidget {
  final String id;
  const ScoutDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoutAsync = FutureProvider<Scout?>((r) =>
        r.read(scoutRepositoryProvider).getById(id));

    return ref.watch(scoutAsync).when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('エラー: $e'))),
      data: (scout) {
        if (scout == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('スカウトが見つかりません')),
          );
        }
        final cs = Theme.of(context).colorScheme;
        final user = ref.watch(currentUserProvider).valueOrNull;

        return Scaffold(
          appBar: AppBar(
            title: Text(scout.name),
            actions: [
              if (user?.role.canEdit ?? false)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.go('/scouts/$id/edit'),
                ),
              if (user?.role.canEdit ?? false)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, scout),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ヘッダー
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        scout.name.isNotEmpty ? scout.name[0] : '?',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(scout.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        _chip(context, scout.category.label, cs.secondaryContainer,
                            cs.onSecondaryContainer),
                      ],
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              // 基本情報
              _infoCard(context, '基本情報', [
                if (scout.grade != null) _InfoRow('学年', scout.grade!),
                if (scout.gender != null)
                  _InfoRow('性別',
                      scout.gender == 'male' ? '男性' : scout.gender == 'female' ? '女性' : 'その他'),
                if (scout.joinedAt != null)
                  _InfoRow('入隊日', DateFormat('yyyy/MM/dd').format(scout.joinedAt!)),
                if (scout.enrollmentYear != null)
                  _InfoRow('小学校入学年度', '${scout.enrollmentYear}年'),
              ]),
              const SizedBox(height: 12),
              // 木の葉章
              _infoCard(context, '木の葉章・小枝章', [
                _InfoRow('木の葉章（活動取得）', '${scout.leafBadges}枚'),
                _InfoRow('入隊時補正', '${scout.leafBadgeOffset}枚'),
                _InfoRow('合計', '${scout.totalLeafBadges}枚',
                    highlight: true),
                _InfoRow('小枝章（授与済み）', '${scout.twigBadges}本'),
                if (scout.pendingTwigBadges > 0)
                  _InfoRow('小枝章（授与待ち）', '${scout.pendingTwigBadges}本',
                      highlight: true),
              ]),
              const SizedBox(height: 12),
              // 木の葉章 ビジュアル
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('木の葉章',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: cs.primary)),
                      const SizedBox(height: 12),
                      _LeafBadgeProgress(scout: scout),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(BuildContext context, String label, Color bg, Color fg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      );

  Widget _infoCard(BuildContext context, String title, List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Scout scout) async {
    final canDelete =
        await ref.read(scoutRepositoryProvider).canDelete(scout.id);
    if (!context.mounted) return;

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出欠履歴または保護者紐付けがあるため削除できません')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('スカウトを削除'),
        content: Text('${scout.name} を削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await ref.read(scoutRepositoryProvider).delete(scout.id);
      context.go('/scouts');
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      highlight ? FontWeight.w700 : FontWeight.w400,
                  color: highlight ? cs.primary : cs.onSurface)),
        ),
      ]),
    );
  }
}

class _LeafBadgeProgress extends StatelessWidget {
  final Scout scout;
  const _LeafBadgeProgress({required this.scout});

  @override
  Widget build(BuildContext context) {
    final total = scout.totalLeafBadges;
    final inCurrent = total % 10;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('次の小枝章まで $inCurrent / 10 枚',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: inCurrent / 10,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(
            10,
            (i) => Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < inCurrent
                    ? const Color(0xFF43A047)
                    : cs.surfaceContainerHighest,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
