import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/wood_grain_background.dart';
import '../../core/supabase_config.dart';
import '../dashboard/dashboard_page.dart';

final eventsProvider = FutureProvider<List<Event>>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return [];
  return ref.read(eventRepositoryProvider).getByTroop(troopId);
});

// 年度を返す（4月始まり）
int _fiscalYear(DateTime date) =>
    date.month >= 4 ? date.year : date.year - 1;

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});
  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  EventStatus? _filterStatus;
  late int _selectedYear;
  String? _currentRole;

  @override
  void initState() {
    super.initState();
    _selectedYear = _fiscalYear(DateTime.now());
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = SupabaseConfig.currentUser;
    if (user == null) return;
    final member = await SupabaseConfig.client
        .from('troop_members')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
    if (mounted) setState(() => _currentRole = member?['role'] as String?);
  }

  void _refresh() {
    ref.invalidate(eventsProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> _goAdd() async {
    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) return;

    // リーダー・スカウトの存在チェック
    final users = await ref.read(userRepositoryProvider).getByTroop(troopId);
    final scouts = await ref.read(scoutRepositoryProvider).getByTroop(troopId);

    if (!mounted) return;

    if (users.isEmpty || scouts.isEmpty) {
      final missing = [
        if (users.isEmpty) 'リーダー',
        if (scouts.isEmpty) 'スカウト',
      ].join('と');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$missingを先に1名以上登録してください'),
          action: SnackBarAction(
            label: '登録する',
            onPressed: () {
              if (users.isEmpty) {
                context.push('/settings/users');
              } else {
                context.push('/scouts');
              }
            },
          ),
        ),
      );
      return;
    }

    await context.push('/events/new');
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventsProvider);
    final troopId = ref.watch(currentTroopIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
        title: const Text('イベント管理'),
        actions: [
          PopupMenuButton<EventStatus?>(
            icon: Icon(Icons.filter_list,
                color: _filterStatus != null
                    ? Theme.of(context).colorScheme.primary
                    : null),
            onSelected: (v) => setState(() => _filterStatus = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('すべて')),
              ...EventStatus.values
                  .map((s) => PopupMenuItem(value: s, child: Text(s.label))),
            ],
          ),
        ],
      ),
      body: Stack(children: [
        const WoodGrainBackground(),
        async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (events) {
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

          // 利用可能な年度を決定
          final years = events
              .map((e) => _fiscalYear(e.eventDate))
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a));
          if (!years.contains(_selectedYear) && years.isNotEmpty) {
            _selectedYear = years.first;
          }

          // 年度・ステータスフィルタ
          final yearFiltered = events
              .where((e) => _fiscalYear(e.eventDate) == _selectedYear)
              .toList();
          final filtered = _filterStatus == null
              ? yearFiltered
              : yearFiltered.where((e) => e.status == _filterStatus).toList();

          return Column(children: [
            // 年度選択バー
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 16),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: years.contains(_selectedYear) ? _selectedYear : (years.isNotEmpty ? years.first : _selectedYear),
                      isDense: true,
                      underline: const SizedBox(),
                      items: years.map((y) => DropdownMenuItem(
                        value: y,
                        child: Text('$y年度',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedYear = v!),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('実施${yearFiltered.where((e) => e.status == EventStatus.completed).length}件　予定${yearFiltered.where((e) => e.status == EventStatus.planned).length}件　非開催${yearFiltered.where((e) => e.status != EventStatus.completed && e.status != EventStatus.planned).length}件',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const Divider(height: 0),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('この年度のイベントはありません',
                      style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _EventCard(event: filtered[i], onReturn: _refresh),
                      ),
                    ),
            ),
          ]);
        },
      ),
      ]),
      floatingActionButton: troopId != null && _currentRole != 'limited'
          ? FloatingActionButton(
              onPressed: _goAdd,
              tooltip: 'イベントを追加',
              child: const Icon(Icons.add))
          : null,
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onReturn;
  const _EventCard({required this.event, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await context.push('/events/${event.id}');
          onReturn();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: _monthColor(event.eventDate.month),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(DateFormat('M月').format(event.eventDate),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Colors.white)),
                Text(DateFormat('d').format(event.eventDate),
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w400,
                        color: Colors.white)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(event.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15))),
                      _statusChip(context, event.status),
                    ]),
                    const SizedBox(height: 4),
                    Wrap(spacing: 8, children: [
                      if (event.location != null)
                        _meta(context, Icons.place_outlined, event.location!),
                      if (event.startTime != null)
                        _meta(context, Icons.schedule_outlined,
                            '${event.startTime}${event.endTime != null ? " ~ ${event.endTime}" : ""}'),
                    ]),
                  ]),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ]),
        ),
      ),
    );
  }

  // 月ごとに色分け（季節の系統で濃淡変化）
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

  Widget _meta(BuildContext context, IconData icon, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 3),
            Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]);

  Widget _statusChip(BuildContext context, EventStatus status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)));
  }
}
