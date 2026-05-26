import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';

// ─── Providers ───────────────────────────────────────────────
final _scoutsProvider = FutureProvider<List<Scout>>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return [];
  return ref.read(scoutRepositoryProvider).getByTroop(troopId);
});

// ─── ScoutsPage ──────────────────────────────────────────────
class ScoutsPage extends ConsumerStatefulWidget {
  const ScoutsPage({super.key});

  @override
  ConsumerState<ScoutsPage> createState() => _ScoutsPageState();
}

class _ScoutsPageState extends ConsumerState<ScoutsPage> {
  String _query = '';
  ScoutCategory? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_scoutsProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('スカウト'),
        actions: [
          if (user?.role.canEdit ?? false)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: () => context.go('/scouts/new'),
            ),
        ],
      ),
      body: Column(
        children: [
          // 検索・フィルタ
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '氏名で検索',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<ScoutCategory?>(
                icon: Icon(
                  Icons.filter_list,
                  color: _filterCategory != null
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onSelected: (v) => setState(() => _filterCategory = v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: null, child: Text('すべて')),
                  ...ScoutCategory.values.map((c) =>
                      PopupMenuItem(value: c, child: Text(c.label))),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 8),
          // リスト
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('エラー: $e')),
              data: (scouts) {
                final filtered = scouts.where((s) {
                  final matchQ = _query.isEmpty ||
                      s.name.contains(_query);
                  final matchC = _filterCategory == null ||
                      s.category == _filterCategory;
                  return matchQ && matchC;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('スカウトが見つかりません',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(_scoutsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ScoutCard(scout: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (user?.role.canEdit ?? false)
          ? FloatingActionButton(
              onPressed: () => context.go('/scouts/new'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ─── ScoutCard ───────────────────────────────────────────────
class _ScoutCard extends StatelessWidget {
  final Scout scout;
  const _ScoutCard({required this.scout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/scouts/${scout.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // アバター
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              child: Text(
                scout.name.isNotEmpty ? scout.name[0] : '?',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimaryContainer,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            // 情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(scout.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    _CategoryChip(category: scout.category),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (scout.grade != null) ...[
                      Icon(Icons.school_outlined,
                          size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(scout.grade!,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 10),
                    ],
                    Icon(Icons.eco_outlined,
                        size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text('木の葉章 ${scout.totalLeafBadges}枚',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    if (scout.pendingTwigBadges > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '小枝章 +${scout.pendingTwigBadges}',
                          style: TextStyle(
                              fontSize: 10,
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ]),
        ),
      ),
    );
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
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(category.label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
