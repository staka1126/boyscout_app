import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/event_stats_service.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/supabase_config.dart';
import '../dashboard/dashboard_page.dart';
import '../badges/badges_page.dart';
import 'events_page.dart';

const _uuid = Uuid();

final _eventDetailProvider =
    FutureProvider.autoDispose.family<_EventDetailData?, String>((ref, id) async {
  final event = await ref.read(eventRepositoryProvider).getById(id);
  if (event == null) return null;
  final badges = await ref.read(eventRepositoryProvider).getLeafBadges(id);
  final attendances = await ref.read(attendanceRepositoryProvider).getByEvent(id);
  final troopId = event.troopId;
  final List<Scout> scouts;
  try {
    scouts = await ref.read(scoutRepositoryProvider).getByTroop(troopId);
  } catch (_) {
    return _EventDetailData(event: event, badges: badges, attendances: attendances, scoutList: [], currentRole: null);
  }
  // ロールも同時取得
  String? currentRole;
  try {
    final user = SupabaseConfig.currentUser;
    if (user != null) {
      final member = await SupabaseConfig.client
          .from('troop_members')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();
      currentRole = member?['role'] as String?;
    }
  } catch (_) {}
  return _EventDetailData(event: event, badges: badges, attendances: attendances, scoutList: scouts, currentRole: currentRole);
});

class _EventDetailData {
  final Event event;
  final List<EventLeafBadge> badges;
  final List<Attendance> attendances;
  final List<Scout> scoutList;
  final String? currentRole;
  _EventDetailData({required this.event, required this.badges, required this.attendances, required this.scoutList, required this.currentRole});

  static const _categoryOrder = [
    ScoutCategory.bigBeaver, ScoutCategory.beaver, ScoutCategory.provisional,
    ScoutCategory.experience, ScoutCategory.sibling,
    ScoutCategory.promoted, ScoutCategory.withdrawn, ScoutCategory.notJoined,
  ];

  int get presentCount => attendances.where((a) => a.status == AttendanceStatus.present).length;
  int get absentCount  => attendances.where((a) => a.status == AttendanceStatus.absent).length;
  int get pendingCount => attendances.where((a) => a.status == AttendanceStatus.pending).length;
  List<Attendance> get users  => attendances.where((a) => a.memberType == MemberType.user).toList();
  List<Attendance> get scouts {
    final scoutMap = {for (final s in scoutList) s.id: s};
    return attendances.where((a) => a.memberType == MemberType.scout).toList()
      ..sort((a, b) {
        final sa = a.memberId != null ? scoutMap[a.memberId] : null;
        final sb = b.memberId != null ? scoutMap[b.memberId] : null;
        final ai = sa != null ? _categoryOrder.indexOf(sa.category) : 99;
        final bi = sb != null ? _categoryOrder.indexOf(sb.category) : 99;
        final aIdx = ai == -1 ? 99 : ai;
        final bIdx = bi == -1 ? 99 : bi;
        if (aIdx != bIdx) return aIdx.compareTo(bIdx);
        return a.memberName.compareTo(b.memberName);
      });
  }
  List<Attendance> get guardians => attendances.where((a) => a.memberType == MemberType.guardian).toList();
  List<Attendance> get committees => attendances.where((a) =>
      a.memberType != MemberType.user && a.memberType != MemberType.scout && a.memberType != MemberType.guardian).toList();
  List<Attendance> get others => [...guardians, ...committees];
}

class EventDetailPage extends ConsumerWidget {
  final String id;
  const EventDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_eventDetailProvider(id));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:   (e, _) => Scaffold(body: Center(child: Text('エラー: $e'))),
      data: (data) {
        if (data == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('イベントが見つかりません')));
        final event = data.event;
        final isCompleted = event.status == EventStatus.completed;
        final isLimited = data.currentRole == 'limited';
        return Scaffold(
          appBar: AppBar(
            title: Text(event.title),
            actions: [
              if (!isLimited) ...[
                IconButton(icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await context.push('/events/$id/edit');
                    ref.invalidate(_eventDetailProvider(id));
                    ref.invalidate(eventsProvider);
                    ref.invalidate(dashboardProvider);
                  }),
                IconButton(icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, event)),
              ],
            ],
          ),
          floatingActionButton: isCompleted ? null : FloatingActionButton(
            onPressed: () => _showAddMemberSheet(context, ref, event),
            tooltip: '出席者を追加',
            child: const Icon(Icons.person_add_outlined),
          ),
          body: RefreshIndicator(
            onRefresh: () => ref.refresh(_eventDetailProvider(id).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                _StatusSelector(current: event.status, enabled: !isLimited, onChanged: (s) => _updateEventStatus(context, ref, event, data, s)),
                const SizedBox(height: 12),
                Card(child: Padding(padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _row(context, Icons.calendar_today_outlined, '日付', DateFormat('yyyy/MM/dd (E)', 'ja').format(event.eventDate)),
                    if (event.startTime != null)
                      _row(context, Icons.schedule_outlined, '時間', '${event.startTime}${event.endTime != null ? " ~ ${event.endTime}" : ""}'),
                    if (event.location != null) _row(context, Icons.place_outlined, '場所', event.location!),
                    if (event.notes != null) _row(context, Icons.notes_outlined, '備考', event.notes!),
                  ]))),
                const SizedBox(height: 12),
                Card(child: Padding(padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('木の葉章配布設定', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const Spacer(),
                      if (!isCompleted && !isLimited)
                        TextButton(onPressed: () => _editLeafBadges(context, ref, event, data.badges), child: const Text('編集')),
                    ]),
                    const SizedBox(height: 8),
                    if (data.badges.isEmpty || data.badges.every((b) => b.count == 0))
                      const Text('まだ設定されていません', style: TextStyle(color: Colors.grey))
                    else
                      Wrap(spacing: 8, runSpacing: 8,
                          children: data.badges.where((b) => b.count > 0).map((b) => _LeafBadgeChip(badge: b)).toList()),
                  ]))),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('出欠管理', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(width: 12),
                  _AttendBadge(label: '出席', count: data.presentCount, color: const Color(0xFF43A047)),
                  const SizedBox(width: 6),
                  _AttendBadge(label: '欠席', count: data.absentCount, color: Colors.red),
                  const SizedBox(width: 6),
                  _AttendBadge(label: '未定', count: data.pendingCount, color: Colors.grey),
                ]),
                const SizedBox(height: 8),
                if (data.users.isNotEmpty) ...[
                  _sectionLabel(context, 'リーダー'),
                  Card(child: Column(children: [for (int i = 0; i < data.users.length; i++) ...[
                    if (i > 0) const Divider(height: 0),
                    _AttendanceTile(attendance: data.users[i],
                      onChanged: (s) => _updateAttendStatus(ref, data.users[i].id, s),
                      onRemove: isCompleted ? null : () => _confirmRemove(context, ref, data.users[i])),
                  ]])),
                  const SizedBox(height: 8),
                ],
                if (data.scouts.isNotEmpty) ...[
                  _sectionLabel(context, 'スカウト'),
                  Card(child: Column(children: [for (int i = 0; i < data.scouts.length; i++) ...[
                    if (i > 0) const Divider(height: 0),
                    _AttendanceTile(attendance: data.scouts[i],
                      onChanged: (s) => _updateAttendStatus(ref, data.scouts[i].id, s),
                      onRemove: isCompleted ? null : () => _confirmRemove(context, ref, data.scouts[i])),
                  ]])),
                  const SizedBox(height: 8),
                ],
                if (data.guardians.isNotEmpty) ...[
                  _sectionLabel(context, '保護者'),
                  Card(child: Column(children: [for (int i = 0; i < data.guardians.length; i++) ...[
                    if (i > 0) const Divider(height: 0),
                    _AttendanceTile(attendance: data.guardians[i],
                      onChanged: (s) => _updateAttendStatus(ref, data.guardians[i].id, s),
                      onRemove: isCompleted ? null : () => _removeAttendance(ref, data.guardians[i].id)),
                  ]])),
                  const SizedBox(height: 8),
                ],
                if (data.committees.isNotEmpty) ...[
                  _sectionLabel(context, '団委員ほか'),
                  Card(child: Column(children: [for (int i = 0; i < data.committees.length; i++) ...[
                    if (i > 0) const Divider(height: 0),
                    _AttendanceTile(attendance: data.committees[i],
                      onChanged: (s) => _updateAttendStatus(ref, data.committees[i].id, s),
                      onRemove: isCompleted ? null : () => _removeAttendance(ref, data.committees[i].id)),
                  ]])),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.8)));

  Widget _row(BuildContext context, IconData icon, String label, String value) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ]));

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(_eventDetailProvider(id));
    ref.invalidate(eventsProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(badgesProvider);
  }

  Future<void> _updateEventStatus(BuildContext context, WidgetRef ref,
      Event event, _EventDetailData data, EventStatus newStatus) async {
    if (newStatus == EventStatus.completed) { await _confirmComplete(context, ref, event); return; }
    if (newStatus == EventStatus.cancelled) {
      if (event.status == EventStatus.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('確定済みイベントは非開催に変更できません')));
        return;
      }
      await ref.read(eventRepositoryProvider).update(event.copyWith(status: newStatus));
      _invalidateAll(ref);
      return;
    }
    if (event.status == EventStatus.completed) {
      final ok = await showDialog<bool>(context: context,
        builder: (dlgCtx) => AlertDialog(
          title: const Text('確定を取り消す'),
          content: const Text('このイベントで反映された木の葉章を取り消します。\nよろしいですか？'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
            FilledButton(onPressed: () => Navigator.of(dlgCtx).pop(true), child: const Text('取り消す')),
          ],
        ));
      if (ok != true || !context.mounted) return;
      final totalBadges = data.badges.fold(0, (sum, b) => sum + b.count);
      if (totalBadges > 0) {
        final presentScoutIds = data.attendances
            .where((a) => a.memberType == MemberType.scout && a.status == AttendanceStatus.present && a.memberId != null)
            .map((a) => a.memberId!).toList();
        for (final sid in presentScoutIds) {
          await ref.read(scoutRepositoryProvider).subtractLeafBadges(sid, totalBadges);
        }
      }
    }
    await ref.read(eventRepositoryProvider).update(event.copyWith(status: newStatus, completedAt: null));
    _invalidateAll(ref);
  }

  Future<void> _updateAttendStatus(WidgetRef ref, String attendanceId, AttendanceStatus status) async {
    await ref.read(attendanceRepositoryProvider).updateStatus(attendanceId, status);
    ref.invalidate(_eventDetailProvider(id));
  }

  Future<void> _removeAttendance(WidgetRef ref, String attendanceId) async {
    await ref.read(attendanceRepositoryProvider).remove(attendanceId);
    ref.invalidate(_eventDetailProvider(id));
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, Attendance attendance) async {
    final ok = await showDialog<bool>(context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('出席者を削除'),
        content: Text('「${attendance.memberName}」をこのイベントの出席者から削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dlgCtx).pop(true), child: const Text('削除')),
        ],
      ));
    if (ok == true) await _removeAttendance(ref, attendance.id);
  }

  Future<void> _showAddMemberSheet(BuildContext context, WidgetRef ref, Event event) async {
    await showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true,
        builder: (_) => _AddMemberSheet(event: event, ref: ref));
    ref.invalidate(_eventDetailProvider(id));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Event event) async {
    final canDel = await ref.read(eventRepositoryProvider).canDelete(event.id);
    if (!context.mounted) return;
    if (!canDel) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('確定済みまたは出席情報があるため削除できません')));
      return;
    }
    final ok = await showDialog<bool>(context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('イベントを削除'), content: Text('「${event.title}」を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dlgCtx).pop(true), child: const Text('削除')),
        ],
      ));
    if (ok == true && context.mounted) {
      await ref.read(eventRepositoryProvider).delete(event.id);
      ref.invalidate(eventsProvider);
      ref.invalidate(dashboardProvider);
      context.pop();
    }
  }

  Future<void> _confirmComplete(BuildContext context, WidgetRef ref, Event event) async {
    final ok = await showDialog<bool>(context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('イベントを確定にする'),
        content: const Text('確定にすると木の葉章が各スカウトに反映されます。\nよろしいですか？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.of(dlgCtx).pop(true), child: const Text('確定にする')),
        ],
      ));
    if (ok != true || !context.mounted) return;

    final eventRepo = ref.read(eventRepositoryProvider);
    final scoutRepo = ref.read(scoutRepositoryProvider);

    await eventRepo.update(event.copyWith(status: EventStatus.completed, completedAt: DateTime.now()));
    final badges = await eventRepo.getLeafBadges(event.id);
    final totalBadges = badges.fold(0, (sum, b) => sum + b.count);

    if (totalBadges > 0) {
      final attendances = await ref.read(attendanceRepositoryProvider).getByEvent(event.id);
      final presentScoutIds = attendances
          .where((a) => a.memberType == MemberType.scout && a.status == AttendanceStatus.present && a.memberId != null)
          .map((a) => a.memberId!).toList();
      for (final sid in presentScoutIds) {
        await scoutRepo.addLeafBadges(sid, totalBadges);
      }
    }

    // 参加統計を保存
    await EventStatsService.instance.saveForEvent(event.id);

    if (context.mounted) {
      _invalidateAll(ref);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('イベントを確定にしました')));
    }
  }

  Future<void> _editLeafBadges(BuildContext context, WidgetRef ref, Event event, List<EventLeafBadge> existing) async {
    await showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true,
        builder: (_) => _LeafBadgeEditor(event: event, existing: existing, ref: ref));
    ref.invalidate(_eventDetailProvider(event.id));
  }
}

// ─── StatusSelector ──────────────────────────────────────────
class _StatusSelector extends StatelessWidget {
  final EventStatus current;
  final bool enabled;
  final ValueChanged<EventStatus> onChanged;
  const _StatusSelector({super.key, required this.current, this.enabled = true, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: EventStatus.values.map((s) {
      final isSelected = s == current;
      final color = _color(context, s);
      return Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: (isSelected || !enabled) ? null : () => onChanged(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? color : color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? color : color.withAlpha(80), width: isSelected ? 2 : 1),
            ),
            child: Text(s.label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? Colors.white : color.withAlpha(220))),
          ),
        ),
      ));
    }).toList());
  }

  Color _color(BuildContext context, EventStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case EventStatus.planned:   return cs.primary;
      case EventStatus.completed: return const Color(0xFF43A047);
      case EventStatus.cancelled: return Colors.grey;
    }
  }
}

class _AttendBadge extends StatelessWidget {
  final String label; final int count; final Color color;
  const _AttendBadge({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 3),
    Text('$label $count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
  ]);
}

class _AttendanceTile extends StatelessWidget {
  final Attendance attendance;
  final ValueChanged<AttendanceStatus> onChanged;
  final VoidCallback? onRemove;
  const _AttendanceTile({required this.attendance, required this.onChanged, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        CircleAvatar(radius: 16, backgroundColor: cs.primaryContainer,
          child: Text(attendance.memberName.isNotEmpty ? attendance.memberName[0] : '?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: cs.onPrimaryContainer))),
        const SizedBox(width: 10),
        Expanded(child: Text(attendance.memberName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        _ToggleGroup(current: attendance.status, onChanged: onChanged),
        if (onRemove != null) ...[
          const SizedBox(width: 4),
          GestureDetector(onTap: onRemove, child: Icon(Icons.remove_circle_outline, size: 18, color: cs.error)),
        ],
      ]),
    );
  }
}

class _ToggleGroup extends StatelessWidget {
  final AttendanceStatus current;
  final ValueChanged<AttendanceStatus> onChanged;
  const _ToggleGroup({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    _Btn(icon: Icons.check,  active: current == AttendanceStatus.present, color: const Color(0xFF43A047), tooltip: '出席', onTap: () => onChanged(AttendanceStatus.present)),
    const SizedBox(width: 4),
    _Btn(icon: Icons.close,  active: current == AttendanceStatus.absent,  color: Colors.red,  tooltip: '欠席', onTap: () => onChanged(AttendanceStatus.absent)),
    const SizedBox(width: 4),
    _Btn(icon: Icons.remove, active: current == AttendanceStatus.pending, color: Colors.grey, tooltip: '未定', onTap: () => onChanged(AttendanceStatus.pending)),
  ]);
}

class _Btn extends StatelessWidget {
  final IconData icon; final bool active; final Color color; final String tooltip; final VoidCallback onTap;
  const _Btn({required this.icon, required this.active, required this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(message: tooltip,
    child: GestureDetector(onTap: onTap,
      child: Container(width: 30, height: 30,
        decoration: BoxDecoration(
          color: active ? color.withAlpha(40) : Colors.transparent,
          border: Border.all(color: active ? color : Colors.grey.shade300, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: active ? color : Colors.grey.shade400))));
}

class _LeafBadgeChip extends StatelessWidget {
  final EventLeafBadge badge;
  const _LeafBadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: badge.badgeType.color.withAlpha(40), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: badge.badgeType.color.withAlpha(120)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: badge.badgeType.color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(badge.badgeType.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    ]));
}

class _LeafBadgeEditor extends ConsumerStatefulWidget {
  final Event event;
  final List<EventLeafBadge> existing;
  final WidgetRef ref;
  const _LeafBadgeEditor({required this.event, required this.existing, required this.ref});

  @override
  ConsumerState<_LeafBadgeEditor> createState() => _LeafBadgeEditorState();
}

class _LeafBadgeEditorState extends ConsumerState<_LeafBadgeEditor> {
  late Map<LeafBadgeType, bool> _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = {
      for (final t in LeafBadgeType.values)
        t: (widget.existing.where((b) => b.badgeType == t).firstOrNull?.count ?? 0) > 0,
    };
  }

  Future<void> _save() async {
    final repo = ref.read(eventRepositoryProvider);
    for (final t in LeafBadgeType.values) {
      final existing = widget.existing.where((b) => b.badgeType == t).firstOrNull;
      await repo.upsertLeafBadge(EventLeafBadge(
        id: existing?.id ?? _uuid.v4(), eventId: widget.event.id,
        badgeType: t, count: _enabled[t]! ? 1 : 0));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('木の葉章配布設定', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('配布する木の葉章をONにしてください', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        ...LeafBadgeType.values.map((t) {
          final on = _enabled[t]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _enabled[t] = !on),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: on ? t.color.withAlpha(30) : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: on ? t.color : cs.outline.withAlpha(80), width: on ? 1.5 : 1),
                ),
                child: Row(children: [
                  Container(width: 14, height: 14,
                      decoration: BoxDecoration(color: on ? t.color : cs.outline.withAlpha(80), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.label, style: TextStyle(fontSize: 14,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                      color: on ? t.color : cs.onSurfaceVariant))),
                  Switch(value: on, onChanged: (v) => setState(() => _enabled[t] = v), activeColor: t.color),
                ]),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        FilledButton(onPressed: _save, child: const Text('保存する')),
        const SizedBox(height: 16),
      ]),
    );
  }
}

enum _AddTab { leader, scout, guardian, committee }

class _AddMemberSheet extends ConsumerStatefulWidget {
  final Event event;
  final WidgetRef ref;
  const _AddMemberSheet({required this.event, required this.ref});

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  _AddTab _tab = _AddTab.scout;
  bool _showRetired = false;
  bool _showAllScouts = false;
  bool _showAllGuardians = false;

  // 全データをまとめてロードする Future（existingIds込み）
  late Future<_SheetData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadAll();
  }

  Future<_SheetData> _loadAll() async {
    final troopId = ref.read(currentTroopIdProvider);
    final existing = await ref.read(attendanceRepositoryProvider).getByEvent(widget.event.id);
    final existingIds = existing.map((a) => a.memberId ?? '').toSet();

    if (troopId == null) return _SheetData(existingIds: existingIds);

    final allUsers = await ref.read(userRepositoryProvider).getByTroop(troopId);
    final allScouts = await ref.read(scoutRepositoryProvider).getByTroop(troopId);
    final allGuardians = await ref.read(guardianRepositoryProvider).getAll(troopId: troopId);
    final allCommittee = await ref.read(committeeRepositoryProvider).getByTroop(troopId);

    // 保護者の順序付け（ビーバー系スカウトの保護者を優先）
    const guardianDisplayOrder = [
      ScoutCategory.bigBeaver, ScoutCategory.beaver, ScoutCategory.provisional,
      ScoutCategory.sibling, ScoutCategory.experience,
    ];
    final targetScouts = allScouts.where((s) => guardianDisplayOrder.contains(s.category)).toList()
      ..sort((a, b) => guardianDisplayOrder.indexOf(a.category).compareTo(guardianDisplayOrder.indexOf(b.category)));
    final seen = <String>{};
    final orderedGuardians = <Guardian>[];
    for (final scout in targetScouts) {
      final gs = await ref.read(guardianRepositoryProvider).getByScout(scout.id);
      for (final g in gs) {
        if (!seen.contains(g.id) && !existingIds.contains(g.id)) {
          seen.add(g.id);
          orderedGuardians.add(g);
        }
      }
    }
    // すべて表示用：上記に含まれない残りの保護者
    final remainingGuardians = allGuardians.where((g) => !seen.contains(g.id) && !existingIds.contains(g.id)).toList();

    return _SheetData(
      existingIds: existingIds,
      allUsers: allUsers,
      allScouts: allScouts,
      priorityGuardians: orderedGuardians,
      remainingGuardians: remainingGuardians,
      allCommittee: allCommittee,
    );
  }

  void _reload() => setState(() { _dataFuture = _loadAll(); });

  List<AppUser> _filterUsers(_SheetData d) =>
      d.allUsers.where((u) => !d.existingIds.contains(u.id) && (_showRetired || !u.isRetired)).toList();

  List<Scout> _filterScouts(_SheetData d) {
    const hiddenCategories = [ScoutCategory.promoted, ScoutCategory.withdrawn, ScoutCategory.notJoined];
    const order = [
      ScoutCategory.bigBeaver, ScoutCategory.beaver, ScoutCategory.provisional,
      ScoutCategory.experience, ScoutCategory.sibling,
      ScoutCategory.promoted, ScoutCategory.withdrawn, ScoutCategory.notJoined,
    ];
    return d.allScouts
        .where((s) => !d.existingIds.contains(s.id) && (_showAllScouts || !hiddenCategories.contains(s.category)))
        .toList()
      ..sort((a, b) {
        final ai = order.indexOf(a.category);
        final bi = order.indexOf(b.category);
        final aIdx = ai == -1 ? 99 : ai;
        final bIdx = bi == -1 ? 99 : bi;
        if (aIdx != bIdx) return aIdx.compareTo(bIdx);
        return a.name.compareTo(b.name);
      });
  }

  List<Guardian> _filterGuardians(_SheetData d) {
    if (_showAllGuardians) return [...d.priorityGuardians, ...d.remainingGuardians];
    return d.priorityGuardians;
  }

  List<CommitteeMember> _filterCommittee(_SheetData d) =>
      d.allCommittee.where((c) => !d.existingIds.contains(c.id) && (_showRetired || !c.isRetired)).toList();

  Future<void> _add(MemberType type, String? memberId, String memberName) async {
    await ref.read(attendanceRepositoryProvider).add(Attendance(
        id: _uuid.v4(), eventId: widget.event.id, memberType: type,
        memberId: memberId, memberName: memberName, status: AttendanceStatus.present));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
      builder: (_, controller) => FutureBuilder<_SheetData>(
        future: _dataFuture,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('出席者を追加', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_AddTab>(
                    style: ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                    segments: const [
                      ButtonSegment(value: _AddTab.leader,    label: Text('リーダー')),
                      ButtonSegment(value: _AddTab.scout,     label: Text('スカウト')),
                      ButtonSegment(value: _AddTab.guardian,  label: Text('保護者')),
                      ButtonSegment(value: _AddTab.committee, label: Text('団委員ほか')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Spacer(),
                  Text('すべて表示', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 4),
                  Switch(
                    value: _tab == _AddTab.scout ? _showAllScouts : _tab == _AddTab.guardian ? _showAllGuardians : _showRetired,
                    onChanged: (v) => setState(() {
                      if (_tab == _AddTab.scout) _showAllScouts = v;
                      else if (_tab == _AddTab.guardian) _showAllGuardians = v;
                      else _showRetired = v;
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ]),
              ]),
            ),
            Expanded(child: _buildList(controller, data)),
          ]);
        },
      ),
    );
  }

  Widget _buildList(ScrollController controller, _SheetData data) {
    switch (_tab) {
      case _AddTab.leader:
        final users = _filterUsers(data);
        if (users.isEmpty) return const Center(child: Text('追加できるリーダーはいません'));
        return ListView.builder(controller: controller, itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            return ListTile(title: Text(u.name), subtitle: Text(u.role.label),
                trailing: const Icon(Icons.add), onTap: () => _add(MemberType.user, u.id, u.name));
          });
      case _AddTab.scout:
        final scouts = _filterScouts(data);
        if (scouts.isEmpty) return const Center(child: Text('追加できるスカウトはいません'));
        return ListView.builder(controller: controller, itemCount: scouts.length,
          itemBuilder: (_, i) {
            final s = scouts[i];
            return ListTile(title: Text(s.name), subtitle: Text(s.category.label),
                trailing: const Icon(Icons.add), onTap: () => _add(MemberType.scout, s.id, s.name));
          });
      case _AddTab.guardian:
        final guardians = _filterGuardians(data);
        if (guardians.isEmpty) return const Center(child: Text('追加できる保護者はいません'));
        return ListView.builder(controller: controller, itemCount: guardians.length,
          itemBuilder: (_, i) {
            final g = guardians[i];
            return ListTile(title: Text(g.name), subtitle: g.phone != null ? Text(g.phone!) : null,
                trailing: const Icon(Icons.add), onTap: () => _add(MemberType.guardian, g.id, g.name));
          });
      case _AddTab.committee:
        final committee = _filterCommittee(data);
        if (committee.isEmpty) return const Center(child: Text('追加できる団委員はいません'));
        return ListView.builder(controller: controller, itemCount: committee.length,
          itemBuilder: (_, i) {
            final c = committee[i];
            return ListTile(title: Text(c.name), subtitle: Text(c.category.label),
                trailing: const Icon(Icons.add), onTap: () => _add(MemberType.committee, c.id, c.name));
          });
    }
  }
}

// ─── SheetData ───────────────────────────────────────────────
class _SheetData {
  final Set<String> existingIds;
  final List<AppUser> allUsers;
  final List<Scout> allScouts;
  final List<Guardian> priorityGuardians;
  final List<Guardian> remainingGuardians;
  final List<CommitteeMember> allCommittee;

  _SheetData({
    required this.existingIds,
    this.allUsers = const [],
    this.allScouts = const [],
    this.priorityGuardians = const [],
    this.remainingGuardians = const [],
    this.allCommittee = const [],
  });
}
