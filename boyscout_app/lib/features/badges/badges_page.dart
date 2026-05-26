import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';

final _badgesProvider = FutureProvider<_BadgesData>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return _BadgesData(scouts: [], history: []);
  final scouts = await ref.read(scoutRepositoryProvider).getByTroop(troopId);
  final history = await ref.read(twigBadgeRepositoryProvider).getAll(troopId);
  return _BadgesData(scouts: scouts, history: history);
});

class _BadgesData {
  final List<Scout> scouts;
  final List<TwigBadgeHistory> history;
  _BadgesData({required this.scouts, required this.history});
  List<Scout> get withPending =>
      scouts.where((s) => s.pendingTwigBadges > 0).toList();
}

class BadgesPage extends ConsumerStatefulWidget {
  const BadgesPage({super.key});
  @override
  ConsumerState<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends ConsumerState<BadgesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_badgesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('表彰管理'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '小枝章 授与待ち'),
            Tab(text: '木の葉章 一覧'),
          ],
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (data) => TabBarView(
          controller: _tab,
          children: [
            _TwigBadgeTab(data: data, ref: ref),
            _LeafBadgeTab(scouts: data.scouts),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }
}

class _TwigBadgeTab extends StatelessWidget {
  final _BadgesData data;
  final WidgetRef ref;
  const _TwigBadgeTab({required this.data, required this.ref});

  @override
  Widget build(BuildContext context) {
    final pending = data.withPending;
    if (pending.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.military_tech_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('授与待ちのスカウトはいません'),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = pending[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.tertiaryContainer,
                child: Icon(Icons.military_tech,
                    color:
                        Theme.of(context).colorScheme.onTertiaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                        '木の葉章 ${s.totalLeafBadges}枚 → '
                        '小枝章 ${s.pendingTwigBadges}本 授与待ち',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: () => _awardTwig(context, s),
                child: const Text('授与'),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _awardTwig(BuildContext context, Scout scout) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('小枝章を授与'),
        content: Text(
            '${scout.name} に小枝章を ${scout.pendingTwigBadges}本 授与しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('授与する')),
        ],
      ),
    );
    if (ok != true) return;

    final scoutRepo = ref.read(scoutRepositoryProvider);
    final twigRepo = ref.read(twigBadgeRepositoryProvider);
    final history = await twigRepo.getByScout(scout.id);
    for (final h in history.where((h) => !h.isAwarded)) {
      await twigRepo.markAwarded(h.id);
    }
    await scoutRepo.incrementTwigBadge(scout.id);
    ref.invalidate(_badgesProvider);
  }
}

class _LeafBadgeTab extends StatelessWidget {
  final List<Scout> scouts;
  const _LeafBadgeTab({required this.scouts});

  @override
  Widget build(BuildContext context) {
    final active = scouts
        .where((s) => s.isActive && s.category.isDefaultAttendee)
        .toList()
      ..sort((a, b) => b.totalLeafBadges.compareTo(a.totalLeafBadges));

    if (active.isEmpty) {
      return const Center(child: Text('スカウトがいません'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: active.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _LeafBadgeRow(scout: active[i]),
    );
  }
}

class _LeafBadgeRow extends StatelessWidget {
  final Scout scout;
  const _LeafBadgeRow({required this.scout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = (scout.totalLeafBadges % 10) / 10.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer,
              child: Text(
                scout.name.isNotEmpty ? scout.name[0] : '?',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(scout.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(scout.category.label,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('合計 ${scout.totalLeafBadges}枚',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              Text('小枝章 ${scout.twigBadges}本',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant)),
            ]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: const Color(0xFF43A047),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${scout.totalLeafBadges % 10}/10',
                style:
                    TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            ...List.generate(
              (scout.totalLeafBadges % 10).clamp(0, 10),
              (i) => Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 3),
                decoration: const BoxDecoration(
                    color: Color(0xFF43A047), shape: BoxShape.circle),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
