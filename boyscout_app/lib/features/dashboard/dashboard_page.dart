import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/supabase_config.dart';
import '../../core/wood_grain_background.dart';
import '../../data/models/models.dart';
import '../../data/providers/app_state_provider.dart';
import '../../data/repositories/repositories.dart';
import '../../data/sync/sync_service.dart';
import '../../features/events/events_page.dart';
import '../../features/scouts/scouts_page.dart';

final _dashboardRoleProvider = FutureProvider.autoDispose<String?>((ref) async {
  final user = SupabaseConfig.currentUser;
  if (user == null) return null;
  final member = await SupabaseConfig.client
      .from('troop_members')
      .select('role')
      .eq('user_id', user.id)
      .maybeSingle();
  return member?['role'] as String?;
});

final dashboardProvider = FutureProvider<_DashboardData>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return _DashboardData.empty();

  // 団名はSupabaseから取得
  String? troopName;
  try {
    final troopData = await SupabaseConfig.client
        .from('troops')
        .select('name')
        .eq('id', troopId)
        .maybeSingle();
    troopName = troopData?['name'] as String?;
  } catch (_) {
    final troop = await ref.read(troopRepositoryProvider).getFirst();
    troopName = troop?.name;
  }

  final events = await ref.read(eventRepositoryProvider).getRecent(troopId);
  final allEvents = await ref.read(eventRepositoryProvider).getByTroop(troopId);
  final scouts = await ref.read(scoutRepositoryProvider).getByTroop(troopId);
  final rates = await ref.read(attendanceRepositoryProvider).getRates(troopId);
  final now = DateTime.now();
  final thisMonthCount = allEvents
      .where((e) => e.eventDate.month == now.month && e.eventDate.year == now.year)
      .length;
  // トータル出席率：全スカウトの出席合計 / (出席+欠席)合計
  final double avgRate = rates.total == 0 ? 0.0 : rates.present / rates.total;
  return _DashboardData(events: events, scouts: scouts, thisMonthCount: thisMonthCount, avgAttendanceRate: avgRate, troopName: troopName);
});

class _DashboardData {
  final List<Event> events;
  final List<Scout> scouts;
  final int thisMonthCount;
  final double avgAttendanceRate;
  final String? troopName;
  _DashboardData({required this.events, required this.scouts, required this.thisMonthCount, required this.avgAttendanceRate, this.troopName});
  factory _DashboardData.empty() => _DashboardData(events: [], scouts: [], thisMonthCount: 0, avgAttendanceRate: 0);
  int get pendingTwigScouts => scouts.where((s) =>
      s.isActive &&
      s.isTwigBadgeEligible &&
      s.pendingTwigBadges > 0 &&
      !const [ScoutCategory.promoted, ScoutCategory.withdrawn, ScoutCategory.notJoined].contains(s.category)
  ).length;
  int get activeScouts => scouts.where((s) => s.isActive && (s.category == ScoutCategory.bigBeaver || s.category == ScoutCategory.beaver)).length;
  List<Scout> get birthdayScouts {
    final now = DateTime.now();
    return scouts
        .where((s) => s.birthday != null && s.birthday!.month == now.month && s.isActive)
        .toList()
      ..sort((a, b) => a.birthday!.day.compareTo(b.birthday!.day));
  }
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    final cs = Theme.of(context).colorScheme;
    final isLimited = ref.watch(_dashboardRoleProvider).maybeWhen(
      data: (role) => role == 'limited',
      orElse: () => true, // loading/error中はFAB非表示
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: async.when(
          loading: () => const Text('ビーバー隊'),
          error: (_, __) => const Text('ビーバー隊'),
          data: (data) => Text(data.troopName != null ? '${data.troopName} ビーバー隊' : 'ビーバー隊'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: () async {
            final troopId = ref.read(currentTroopIdProvider);
            if (troopId == null) return;
            try {
              await SyncService.instance.syncFromSupabase(troopId, force: true);
            } catch (_) {}
            ref.invalidate(dashboardProvider);
            ref.invalidate(eventsProvider);
            ref.invalidate(scoutsProvider);
          }),
        ],
      ),
      body: Stack(children: [
        const WoodGrainBackground(),
        async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardProvider.future),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: _MetricCard(label: '今月のイベント', value: '${data.thisMonthCount}件', icon: Icons.event, color: cs.primaryContainer, iconColor: cs.onPrimaryContainer)),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard(label: 'スカウト数', value: '${data.activeScouts}名', icon: Icons.people, color: cs.secondaryContainer, iconColor: cs.onSecondaryContainer)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _MetricCard(label: '今年度の出席率', value: '${(data.avgAttendanceRate * 100).round()}%', icon: Icons.check_circle_outline, color: cs.tertiaryContainer, iconColor: cs.onTertiaryContainer)),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard(label: '小枝章 授与待ち', value: '${data.pendingTwigScouts}名', icon: Icons.military_tech_outlined, color: cs.errorContainer, iconColor: cs.onErrorContainer)),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Text('直近のイベント', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(onPressed: () => context.go('/events'), child: const Text('すべて見る')),
            ]),
            const SizedBox(height: 8),
            if (data.events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('直近のイベントはありません',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                    textAlign: TextAlign.center),
              )
            else
              Card(child: Column(children: [
                for (int i = 0; i < data.events.take(5).length; i++) ...[
                  if (i > 0) const Divider(height: 0),
                  _EventListTile(event: data.events[i]),
                ],
              ])),
            const SizedBox(height: 24),
            if (data.pendingTwigScouts > 0) ...[  
            Text('小枝章 授与待ち', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Card(child: ListTile(
            leading: CircleAvatar(backgroundColor: cs.tertiaryContainer,
            child: Icon(Icons.military_tech, color: cs.onTertiaryContainer)),
            title: Text('${data.pendingTwigScouts}名のスカウトが授与待ちです'),
            subtitle: const Text('表彰タブから確認できます'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/badges'),
            )),
              const SizedBox(height: 24),
            ],
            if (data.birthdayScouts.isNotEmpty) ...[  
              Text('今月の誕生日', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Card(child: Column(children: [
                for (int i = 0; i < data.birthdayScouts.length; i++) ...[  
                  if (i > 0) const Divider(height: 0),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFD700).withAlpha(80),
                      child: const Text('🎂', style: TextStyle(fontSize: 18)),
                    ),
                    title: Text(data.birthdayScouts[i].name,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    subtitle: Text(
                        '${data.birthdayScouts[i].birthday!.month}月${data.birthdayScouts[i].birthday!.day}日  ${data.birthdayScouts[i].category.label}'),
                    trailing: Text(
                      _ageText(data.birthdayScouts[i].birthday!),
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                    onTap: () => context.go('/scouts/${data.birthdayScouts[i].id}'),
                  ),
                ],
              ])),
            ],
          ]),
        ),
      ),
      ]),
      floatingActionButton: isLimited ? null : FloatingActionButton(
            heroTag: 'add_event_fab',
            onPressed: () async {
          final troopId = ref.read(currentTroopIdProvider);
          if (troopId == null) return;
          final users = await ref.read(userRepositoryProvider).getByTroop(troopId);
          final scouts = await ref.read(scoutRepositoryProvider).getByTroop(troopId);
          if (!context.mounted) return;
          if (users.isEmpty || scouts.isEmpty) {
            final missing = [
              if (users.isEmpty) 'リーダー',
              if (scouts.isEmpty) 'スカウト',
            ].join('と');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$missingを先に1名以上登録してください')),
            );
            return;
          }
          context.push('/events/new');
          },
        child: const Icon(Icons.add),
      ),

    );
  }
}

String _ageText(DateTime birthday) {
  final now = DateTime.now();
  int age = now.year - birthday.year;
  if (now.month < birthday.month ||
      (now.month == birthday.month && now.day < birthday.day)) {
    age--;
  }
  return '$age歳';
}

class _MetricCard extends StatelessWidget {
  final String label; final String value; final IconData icon; final Color color; final Color iconColor;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 8),
        Expanded(child: RichText(overflow: TextOverflow.ellipsis, maxLines: 2,
          text: TextSpan(children: [
            TextSpan(text: '$value\n', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: iconColor, height: 1.2)),
            TextSpan(text: label, style: TextStyle(fontSize: 10, color: iconColor.withAlpha(200), height: 1.3)),
          ]))),
      ]),
    );
  }
}

class _EventListTile extends StatelessWidget {
  final Event event;
  const _EventListTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _DateBadge(date: event.eventDate),
      title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(
        [if (event.location != null) event.location!, if (event.startTime != null) event.startTime!].join(' · '),
        style: const TextStyle(fontSize: 12)),
      trailing: _StatusChip(status: event.status),
      onTap: () => context.go('/events/${event.id}'),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime date;
  const _DateBadge({required this.date});

  static Color _monthColor(int month) {
    switch (month) {
      case 4:  return const Color(0xFF81C784); // 春・淡緑
      case 5:  return const Color(0xFF4CAF50); // 春・中緑
      case 6:  return const Color(0xFF2E7D32); // 春・深緑
      case 7:  return const Color(0xFF4FC3F7); // 夏・淡青
      case 8:  return const Color(0xFF0288D1); // 夏・中青
      case 9:  return const Color(0xFF01579B); // 夏・深青
      case 10: return const Color(0xFFFFB74D); // 秋・淡橙
      case 11: return const Color(0xFFF57C00); // 秋・中橙
      case 12: return const Color(0xFFBF360C); // 秋・深赤橙
      case 1:  return const Color(0xFF9FA8DA); // 冬・淡藍
      case 2:  return const Color(0xFF5C6BC0); // 冬・中藍
      default: return const Color(0xFF283593); // 冬・深藍（3月）
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _monthColor(date.month);
    return Container(
      width: 40,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Center(child: RichText(textAlign: TextAlign.center,
        text: TextSpan(children: [
          TextSpan(text: '${DateFormat('M月').format(date)}\n',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white, height: 1.4)),
          TextSpan(text: DateFormat('d').format(date),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: Colors.white, height: 1.2)),
        ]))),
    );
  }
}

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
      case EventStatus.planned:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
      case EventStatus.cancelled:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)));
  }
}
