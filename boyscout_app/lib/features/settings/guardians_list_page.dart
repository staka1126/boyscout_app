import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/wood_grain_background.dart';
import '../dashboard/dashboard_page.dart';

// スカウトリストと共通の分類順
const _kCategoryOrder = [
  ScoutCategory.bigBeaver,
  ScoutCategory.beaver,
  ScoutCategory.provisional,
  ScoutCategory.experience,
  ScoutCategory.sibling,
  ScoutCategory.promoted,
  ScoutCategory.withdrawn,
  ScoutCategory.notJoined,
];
const _kHiddenCategories = [
  ScoutCategory.promoted,
  ScoutCategory.withdrawn,
  ScoutCategory.notJoined,
];

class _GuardianWithScout {
  final Guardian guardian;
  final Scout? linkedScout; // 先勝ちで紐付いた最初のスカウト
  _GuardianWithScout({required this.guardian, this.linkedScout});
}

final guardiansProvider = FutureProvider<List<_GuardianWithScout>>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return [];

  final guardians = await ref.read(guardianRepositoryProvider).getAll(troopId: troopId);
  final scouts = await ref.read(scoutRepositoryProvider).getByTroop(troopId);

  // スカウトを分類順に並べてから処理することで、より上位分類が先勝ちになる
  final sortedScouts = List<Scout>.from(scouts)..sort((a, b) {
    final ai = _kCategoryOrder.indexOf(a.category);
    final bi = _kCategoryOrder.indexOf(b.category);
    final aIdx = ai == -1 ? 99 : ai;
    final bIdx = bi == -1 ? 99 : bi;
    if (aIdx != bIdx) return aIdx.compareTo(bIdx);
    return a.name.compareTo(b.name);
  });

  // guardian_id → 最初に見つかったスカウト（分類順で先勝ち）
  final guardianToScout = <String, Scout>{};
  for (final s in sortedScouts) {
    final linkedGuardians = await ref.read(guardianRepositoryProvider).getByScout(s.id);
    for (final g in linkedGuardians) {
      guardianToScout.putIfAbsent(g.id, () => s);
    }
  }

  final items = guardians.map((g) => _GuardianWithScout(
    guardian: g,
    linkedScout: guardianToScout[g.id],
  )).toList();

  // スカウトの分類順でソート
  // 紐付きなし → 末尾
  items.sort((a, b) {
    final sa = a.linkedScout;
    final sb = b.linkedScout;

    // 両方紐付きなし → 名前順
    if (sa == null && sb == null) return a.guardian.name.compareTo(b.guardian.name);
    // 片方のみ紐付きなし → 末尾
    if (sa == null) return 1;
    if (sb == null) return -1;

    // 非表示カテゴリは末尾
    final aHidden = _kHiddenCategories.contains(sa.category);
    final bHidden = _kHiddenCategories.contains(sb.category);
    if (aHidden != bHidden) return aHidden ? 1 : -1;

    // 分類順
    final ai = _kCategoryOrder.indexOf(sa.category);
    final bi = _kCategoryOrder.indexOf(sb.category);
    final aIdx = ai == -1 ? 99 : ai;
    final bIdx = bi == -1 ? 99 : bi;
    if (aIdx != bIdx) return aIdx.compareTo(bIdx);

    // 同分類内はスカウト名順
    return sa.name.compareTo(sb.name);
  });

  return items;
});

class GuardiansListPage extends ConsumerStatefulWidget {
  const GuardiansListPage({super.key});

  @override
  ConsumerState<GuardiansListPage> createState() => _GuardiansListPageState();
}

class _GuardiansListPageState extends ConsumerState<GuardiansListPage> {
  bool _showHidden = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(guardiansProvider);
    final troopId = ref.watch(currentTroopIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('保護者管理')),
      body: Stack(children: [
        const WoodGrainBackground(),
        troopId == null ? _NoTroopView() : async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('保護者がいません', style: TextStyle(color: Colors.grey)));
          }

          // 非表示カテゴリのスカウトに紐付く保護者を分離
          final visible = items.where((item) {
            final s = item.linkedScout;
            if (s == null) return true; // 紐付きなしは表示
            return _showHidden || !_kHiddenCategories.contains(s.category);
          }).toList();

          final hasHidden = items.any((item) {
            final s = item.linkedScout;
            return s != null && _kHiddenCategories.contains(s.category);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length + (hasHidden ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (hasHidden && i == visible.length) {
                return TextButton.icon(
                  onPressed: () => setState(() => _showHidden = !_showHidden),
                  icon: Icon(_showHidden ? Icons.expand_less : Icons.expand_more, size: 18),
                  label: Text(_showHidden
                      ? '上進・退団・入隊せずのスカウトの保護者を隠す'
                      : '上進・退団・入隊せずのスカウトの保護者を表示'),
                );
              }
              final g = visible[i].guardian;
              final subtitle = [
                if (g.email != null) g.email!,
                if (g.phone != null) g.phone!,
              ].join('　');
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Text(g.name.isNotEmpty ? g.name[0] : '?',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSecondaryContainer)),
                  ),
                  title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(subtitle.isEmpty ? '連絡先未登録' : subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/guardians/${g.id}'),
                ),
              );
            },
          );
        },
      ),
      ]),
      floatingActionButton: troopId != null
          ? FloatingActionButton(
              onPressed: () async {
                await context.push('/settings/guardians/new');
                ref.invalidate(guardiansProvider);
              },
              tooltip: '保護者を追加',
              child: const Icon(Icons.person_add_outlined),
            )
          : null,
    );
  }

}

class _NoTroopView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.warning_amber_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
      const SizedBox(height: 12),
      const Text('先に団情報を登録してください'),
      const SizedBox(height: 16),
      FilledButton(
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 24)),
        onPressed: () => context.go('/settings/troop'),
        child: const Text('団情報を登録する'),
      ),
    ]));
  }
}
