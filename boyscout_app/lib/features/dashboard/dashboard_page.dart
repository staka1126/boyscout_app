import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';

final _dashboardProvider = FutureProvider<_DashboardData>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return _DashboardData.empty();
  final events = await ref.read(eventRepositoryProvider).getRecent(troopId);
  final scouts = await ref.read(scoutRepositoryProvider).getByTroop(troopId);
  final rates = await ref.read(attendanceRepositoryProvider).getRates(troopId);
  final now = DateTime.now();
  final thisMonthCount = events
      .where((e) => e.eventDate.month == now.month && e.eventDate.year == now.year)
      .length;
  double avgRate = 0;
  if (rates.isNotEmpty) {
    avgRate = rates.values.reduce((a, b) => a + b) / rates.length;
  }
  return _DashboardData(
    events: events,
    scouts: scouts,
    thisMonthCount: thisMonthCount,
    avgAttendanceRate: avgRate,
  );
});

class _DashboardData {
  final List<Event> events;
  final List<Scout> scouts;
  final int thisMonthCount;
  final double avgAttendanceRate;

  _DashboardData({
    required this.events,
    required this.scouts,
    required this.thisMonthCount,
    required this.avgAttendanceRate,
  });

  factory _DashboardData.empty() =>
      _DashboardData(events: [], scouts: [], thisMonthCount: 0, avgAttendanceRate: 0);

  int get pendingTwigScouts => scouts.where((s) => s.pendingTwigBadges > 0).length;
  int get activeScouts =>
      scouts.where((s) => s.isActive && s.category.isDefaultAttendee).length;
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_dashboardProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ビーバー隊'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(_dashboardProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(_dashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(
                  child: _MetricCard(
                    label: '今月のイベント',
                    value: '${data.thisMonthCount}件',
                    icon: Icons.event,
                    color: cs.primaryContainer,
                    iconColor: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'スカウト数',
                    value: '${data.activeScouts}名',
                    icon: Icons.people,
                    color: cs.secondaryContainer,
                    iconColor: cs.onSecondaryContainer,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _MetricCard(
                    label: '平均出席率',
                    value: '${(data.avgAttendanceRate * 100).round()}%',
                    icon: Icons.check_circle_outline,
                    color: cs.tertiaryContainer,
                    iconColor: cs.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: '小枝章 授与待ち',
                    value: '${data.pendingTwigScouts}名',
                    icon: Icons.military_tech_outlined,
                    color: cs.errorContainer,
                    iconColor: cs.onErrorContainer,
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                Text('直近のイベント',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/events'),
                  child: const Text('すべて見る'),
                ),
              ]),
              const SizedBox(height: 8),
              if (data.events.isEmpty)
                _EmptyCard(
                  icon: Icons.event_outlined,
                  message: 'イベントがありません',
                  action: 'イベントを追加',
                  onAction: () => context.go('/events/new'),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (int i = 0; i < data.events.take(5).length; i++) ...[
                        if (i > 0) const Divider(height: 0),
                        _EventListTile(event: data.events[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              if (data.pendingTwigScouts > 0) ...[
                Text('小枝章 授与待ち',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.tertiaryContainer,
                      child: Icon(Icons.military_tech, color: cs.onTertiaryContainer),
                    ),
                    title: Text('${data.pendingTwigScouts}名のスカウトが授与待ちです'),
                    subtitle: const Text('表彰タブから確認できます'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/badges'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/events/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─── MetricCard ──────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color iconColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$value\n',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                      height: 1.2,
                    ),
                  ),
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      fontSize: 10,
                      color: iconColor.withAlpha(200),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── EventListTile ───────────────────────────────────────────
class _EventListTile extends StatelessWidget {
  final Event event;
  const _EventListTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      // leading に Column を使わず RichText で日付を表示
      leading: _DateBadge(date: event.eventDate),
      title: Text(event.title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(
        [
          event.eventType.label,
          if (event.location != null) event.location!,
          if (event.startTime != null) event.startTime!,
        ].join(' · '),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: _StatusChip(status: event.status),
      onTap: () => context.go('/events/${event.id}'),
    );
  }
}

// ─── DateBadge（Column を使わず RichText で縦並び）─────────────
class _DateBadge extends StatelessWidget {
  final DateTime date;
  const _DateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: '${DateFormat('d').format(date)}\n',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimaryContainer,
                  height: 1.2,
                ),
              ),
              TextSpan(
                text: DateFormat('M月').format(date),
                style: TextStyle(
                  fontSize: 9,
                  color: cs.onPrimaryContainer,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── StatusChip ──────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final EventStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    switch (status) {
      case EventStatus.completed:
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
      case EventStatus.ongoing:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
      case EventStatus.cancelled:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
      default:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ─── EmptyCard ───────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String action;
  final VoidCallback onAction;

  const _EmptyCard({
    required this.icon,
    required this.message,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
