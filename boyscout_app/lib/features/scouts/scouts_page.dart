import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/wood_grain_background.dart';
import '../badges/badges_page.dart';
import '../dashboard/dashboard_page.dart';

final scoutsProvider = FutureProvider<List<Scout>>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return [];
  return ref.read(scoutRepositoryProvider).getByTroop(troopId);
});

class ScoutsPage extends ConsumerStatefulWidget {
  const ScoutsPage({super.key});

  @override
  ConsumerState<ScoutsPage> createState() => _ScoutsPageState();
}

class _ScoutsPageState extends ConsumerState<ScoutsPage> {
  // 表示順（デフォルト表示対象のみ）
  static const _categoryOrder = [
    ScoutCategory.bigBeaver,
    ScoutCategory.beaver,
    ScoutCategory.provisional,
    ScoutCategory.experience,
    ScoutCategory.sibling,
  ];

  // デフォルト非表示の分類
  static const _hiddenCategories = [
    ScoutCategory.promoted,
    ScoutCategory.withdrawn,
    ScoutCategory.notJoined,
  ];

  String _query = '';
  ScoutCategory? _filterCategory;
  bool _showHidden = false;

  void _refresh() {
    ref.invalidate(scoutsProvider);
    ref.invalidate(badgesProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> _goAdd() async {
    await context.push('/scouts/new');
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(scoutsProvider);
    final troopId = ref.watch(currentTroopIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
        title: const Text('スカウト管理'),
        actions: [
          PopupMenuButton<ScoutCategory?>(
            icon: Icon(Icons.filter_list,
                color: _filterCategory != null
                    ? Theme.of(context).colorScheme.primary
                    : null),
            onSelected: (v) => setState(() => _filterCategory = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('すべて')),
              ...ScoutCategory.values
                  .map((c) => PopupMenuItem(value: c, child: Text(c.label))),
            ],
          ),
        ],
      ),
      body: Stack(children: [
        const WoodGrainBackground(),
        Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '氏名で検索',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('エラー: $e')),
              data: (scouts) {
                if (troopId == null) {
                  return Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.warning_amber_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        const Text('先に団情報を登録してください'),
                        const SizedBox(height: 16),
                        FilledButton(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 24)),
                            onPressed: () => context.go('/settings/troop'),
                            child: const Text('団情報を登録する')),
                      ]));
                }

                if (scouts.isEmpty) {
                  return Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.people_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        const Text('スカウトがいません',
                            style: TextStyle(color: Colors.grey)),
                      ]));
                }

                final filtered = scouts.where((s) {
                  final matchQ = _query.isEmpty || s.name.contains(_query);
                  final matchC = _filterCategory == null || s.category == _filterCategory;
                  // フィルタ指定なしの場合は非表示分類を隔離（トグルのみ表示）
                  final matchHidden = _filterCategory != null
                      || _showHidden
                      || !_hiddenCategories.contains(s.category);
                  return matchQ && matchC && matchHidden;
                }).toList()
                  ..sort((a, b) {
                    // フィルタ指定時は名前順、それ以外は分類順＋名前順
                    if (_filterCategory != null) return a.name.compareTo(b.name);
                    final ai = _categoryOrder.indexOf(a.category);
                    final bi = _categoryOrder.indexOf(b.category);
                    final aIdx = ai == -1 ? 99 : ai;
                    final bIdx = bi == -1 ? 99 : bi;
                    if (aIdx != bIdx) return aIdx.compareTo(bIdx);
                    return a.name.compareTo(b.name);
                  });

                // 非表示分類の有無
                final hasHidden = _filterCategory == null &&
                    scouts.any((s) => _hiddenCategories.contains(s.category));

                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('スカウトが見つかりません',
                          style: TextStyle(color: Colors.grey)));
                }

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length + (hasHidden ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      // 最後にトグルボタン
                      if (hasHidden && i == filtered.length) {
                        return TextButton.icon(
                          onPressed: () => setState(() => _showHidden = !_showHidden),
                          icon: Icon(_showHidden ? Icons.expand_less : Icons.expand_more, size: 18),
                          label: Text(_showHidden
                              ? '上進・退団・入隊せずを隠す'
                              : '上進・退団・入隊せずを表示'),
                        );
                      }
                      return _ScoutCard(scout: filtered[i], onReturn: _refresh);
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ]),
      floatingActionButton: troopId != null
          ? FloatingActionButton(
              onPressed: _goAdd,
              tooltip: 'スカウトを追加',
              child: const Icon(Icons.person_add_outlined))
          : null,
    );
  }
}

class _ScoutCard extends StatelessWidget {
  final Scout scout;
  final VoidCallback onReturn;
  const _ScoutCard({required this.scout, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pending = scout.isTwigBadgeEligible
        ? scout.pendingTwigBadges
        : scout.pendingOtherBadges;
    final pendingLabel = scout.isTwigBadgeEligible ? '小枝章 +$pending' : '表彰 +$pending';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await context.push('/scouts/${scout.id}');
          onReturn();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
                radius: 22,
                backgroundColor: _categoryAvatarBg(cs, scout.category),
                child: Text(scout.name.isNotEmpty ? scout.name[0] : '?',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _categoryAvatarFg(cs, scout.category),
                        fontSize: 16))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(scout.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15))),
                      _CategoryChip(category: scout.category),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.eco_outlined,
                          size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text('木の葉章 ${scout.totalLeafBadges}枚',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                      if (pending > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: cs.errorContainer,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(pendingLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onErrorContainer,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                  ]),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ]),
        ),
      ),
    );
  }
}

Color _categoryAvatarBg(ColorScheme cs, ScoutCategory category) {
  switch (category) {
    case ScoutCategory.bigBeaver:
      return cs.primaryContainer;
    case ScoutCategory.beaver:
      return cs.secondaryContainer;
    case ScoutCategory.provisional:
      return cs.tertiaryContainer;
    default:
      return cs.surfaceContainerHighest;
  }
}

Color _categoryAvatarFg(ColorScheme cs, ScoutCategory category) {
  switch (category) {
    case ScoutCategory.bigBeaver:
      return cs.onPrimaryContainer;
    case ScoutCategory.beaver:
      return cs.onSecondaryContainer;
    case ScoutCategory.provisional:
      return cs.onTertiaryContainer;
    default:
      return cs.onSurfaceVariant;
  }
}

class _CategoryChip extends StatelessWidget {
  final ScoutCategory category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    switch (category) {
      case ScoutCategory.bigBeaver:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
      case ScoutCategory.beaver:
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
      case ScoutCategory.provisional:
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
      default:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(category.label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)));
  }
}
