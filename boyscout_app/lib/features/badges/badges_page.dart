import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/wood_grain_background.dart';
import '../dashboard/dashboard_page.dart';

final badgesProvider = FutureProvider<_BadgesData>((ref) async {
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

  List<_PendingTwig> get pendingList {
    final result = <_PendingTwig>[];
    for (final s in scouts) {
      if (!s.isActive) continue;
      if (s.isTwigBadgeEligible && s.pendingTwigBadges > 0) {
        result.add(_PendingTwig(scout: s, count: s.pendingTwigBadges));
      }
    }
    return result;
  }

  List<Scout> get enrollmentTargets {
    final targets = scouts
        .where((s) =>
            s.isActive && s.category.isTwigBadgeEligible && s.joinedAt == null)
        .toList();
    targets.sort((a, b) => a.name.compareTo(b.name));
    return targets;
  }
}

class _PendingTwig {
  final Scout scout;
  final int count;
  _PendingTwig({required this.scout, required this.count});
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
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(badgesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
        title: const Text('表彰管理'),
        bottom: TabBar(controller: _tab, tabs: const [
          Tab(text: '入隊式'),
          Tab(text: '小枝章'),
          Tab(text: '木の葉章'),
          Tab(text: '皆勤賞'),
        ]),
      ),
      body: Stack(children: [
        const WoodGrainBackground(),
        async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('エラー: $e')),
          data: (data) => TabBarView(controller: _tab, children: [
            _EnrollmentTab(scouts: data.enrollmentTargets),
            _TwigBadgeTab(data: data, onRefresh: () => ref.invalidate(badgesProvider)),
            _LeafBadgeTab(scouts: data.scouts),
            _PerfectAttendanceTab(),
          ]),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }
}

// ─── 皆勤賞タブ ─────────────────────────────────────────────
class _PerfectAttendanceTab extends ConsumerStatefulWidget {
  const _PerfectAttendanceTab();
  @override
  ConsumerState<_PerfectAttendanceTab> createState() => _PerfectAttendanceTabState();
}

class _PerfectAttendanceTabState extends ConsumerState<_PerfectAttendanceTab> {
  late int _year;
  late List<int> _years;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // 現在の年度（4月始まり）
    _year = now.month >= 4 ? now.year : now.year - 1;
    // 過去5年度分を選択肢に
    _years = List.generate(5, (i) => _year - i);
  }

  @override
  Widget build(BuildContext context) {
    final troopId = ref.watch(currentTroopIdProvider);
    return Column(children: [
      // 年度選択
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          const Text('年度', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _year,
            items: _years.map((y) => DropdownMenuItem(
              value: y,
              child: Text('$y年度（$y/4/1 〜 ${y+1}/3/31）'),
            )).toList(),
            onChanged: (v) { if (v != null) setState(() => _year = v); },
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: troopId == null
            ? const Center(child: Text('団情報が未登録です'))
            : FutureBuilder<List<PerfectAttendance>>(
                future: ref.read(attendanceRepositoryProvider)
                    .getPerfectAttendance(troopId: troopId, year: _year),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) return Center(child: Text('エラー: ${snap.error}'));
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('皆勤賞に該当するスカウトはいません'),
                      ],
                    ));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final p = list[i];
                      final cs = Theme.of(context).colorScheme;
                      return Card(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFFFD700).withAlpha(80),
                            child: const Icon(Icons.emoji_events, color: Color(0xFFFFD700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.scoutName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text('全${p.eventCount}イベント出席',
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withAlpha(50),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFFD700)),
                            ),
                            child: const Text('皆勤賞',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                    color: Color(0xFF8B6914))),
                          ),
                        ]),
                      ));
                    },
                  );
                },
              ),
      ),
    ]);
  }
}

// ─── 入隊式タブ ────────────────────────────────────────────────
class _EnrollmentTab extends StatelessWidget {
  final List<Scout> scouts;
  const _EnrollmentTab({required this.scouts});

  @override
  Widget build(BuildContext context) {
    if (scouts.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
        SizedBox(height: 8),
        Text('入隊式がまだのスカウトはいません'),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: scouts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _EnrollmentRow(scout: scouts[i]),
    );
  }
}

class _EnrollmentRow extends StatelessWidget {
  final Scout scout;
  const _EnrollmentRow({required this.scout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        CircleAvatar(radius: 20, backgroundColor: cs.primaryContainer,
          child: Text(scout.name.isNotEmpty ? scout.name[0] : '?',
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(scout.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 2),
          Text(scout.category.label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(20)),
          child: Text('入隊式未入力',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onErrorContainer)),
        ),
      ]),
    ));
  }
}

// ─── 小枝章タブ ──────────────────────────────────────────────
class _TwigBadgeTab extends ConsumerWidget {
  final _BadgesData data;
  final VoidCallback onRefresh;
  const _TwigBadgeTab({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = data.pendingList;
    if (pending.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.military_tech_outlined, size: 48, color: Colors.grey),
        SizedBox(height: 8),
        Text('授与待ちのスカウトはいません'),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = pending[i];
        return Card(child: Padding(padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              child: Icon(Icons.military_tech, color: Theme.of(context).colorScheme.onTertiaryContainer)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.scout.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 2),
              Text('${p.scout.category.label} ／ 木の葉章 ${p.scout.totalLeafBadges}枚 → 小枝章 ${p.count}本 授与待ち',
                  style: const TextStyle(fontSize: 12)),
            ])),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14)),
              onPressed: () => _awardTwig(context, ref, p.scout),
              child: const Text('授与'),
            ),
          ]),
        ));
      },
    );
  }

  Future<void> _awardTwig(BuildContext context, WidgetRef ref, Scout scout) async {
    final ok = await showDialog<bool>(context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('小枝章を授与'),
        content: Text('${scout.name} に小枝章を ${scout.pendingTwigBadges}本 授与しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.of(dlgCtx).pop(true), child: const Text('授与する')),
        ],
      ));
    if (ok != true) return;
    final scoutRepo = ref.read(scoutRepositoryProvider);
    final twigRepo = ref.read(twigBadgeRepositoryProvider);
    final history = await twigRepo.getByScout(scout.id);
    for (final h in history.where((h) => !h.isAwarded)) {
      await twigRepo.markAwarded(h.id);
    }
    await scoutRepo.incrementTwigBadge(scout.id);
    ref.invalidate(dashboardProvider);
    onRefresh();
  }
}

// ─── 木の葉章タブ ────────────────────────────────────────────
class _LeafBadgeTab extends StatelessWidget {
  final List<Scout> scouts;
  const _LeafBadgeTab({required this.scouts});

  @override
  Widget build(BuildContext context) {
    final active = scouts
        .where((s) => s.isActive && s.category.isDefaultAttendee)
        .toList()
      ..sort((a, b) => b.totalLeafBadges.compareTo(a.totalLeafBadges));
    if (active.isEmpty) return const Center(child: Text('スカウトがいません'));
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
    return Card(child: Padding(padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: cs.primaryContainer,
            child: Text(scout.name.isNotEmpty ? scout.name[0] : '?',
                style: TextStyle(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(scout.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(scout.category.label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('合計 ${scout.totalLeafBadges}枚',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('小枝章 ${scout.twigBadges}本',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                color: const Color(0xFF43A047)))),
          const SizedBox(width: 8),
          Text('${scout.totalLeafBadges % 10}/10',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ]),
      ]),
    ));
  }
}
