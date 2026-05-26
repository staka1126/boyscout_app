import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';

const _uuid = Uuid();

// ─── Provider ────────────────────────────────────────────────
final _eventDetailProvider =
    FutureProvider.family<_EventDetailData?, String>((ref, id) async {
  final event = await ref.read(eventRepositoryProvider).getById(id);
  if (event == null) return null;
  final badges = await ref.read(eventRepositoryProvider).getLeafBadges(id);
  final attendances =
      await ref.read(attendanceRepositoryProvider).getByEvent(id);
  return _EventDetailData(
      event: event, badges: badges, attendances: attendances);
});

class _EventDetailData {
  final Event event;
  final List<EventLeafBadge> badges;
  final List<Attendance> attendances;

  _EventDetailData({
    required this.event,
    required this.badges,
    required this.attendances,
  });

  int get presentCount =>
      attendances.where((a) => a.status == AttendanceStatus.present).length;
  int get absentCount =>
      attendances.where((a) => a.status == AttendanceStatus.absent).length;
}

// ─── EventDetailPage ─────────────────────────────────────────
class EventDetailPage extends ConsumerWidget {
  final String id;
  const EventDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_eventDetailProvider(id));
    final user = ref.watch(currentUserProvider).valueOrNull;

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('エラー: $e'))),
      data: (data) {
        if (data == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('イベントが見つかりません')));
        }
        final event = data.event;

        return Scaffold(
          appBar: AppBar(
            title: Text(event.title),
            actions: [
              if (user?.role.canEdit ?? false)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.go('/events/$id/edit'),
                ),
              if (user?.role.canEdit ?? false)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'delete') _confirmDelete(context, ref, event);
                    if (v == 'complete') _confirmComplete(context, ref, event);
                  },
                  itemBuilder: (_) => [
                    if (event.status != EventStatus.completed &&
                        event.status != EventStatus.cancelled)
                      const PopupMenuItem(
                          value: 'complete', child: Text('完了にする')),
                    if (event.status != EventStatus.completed)
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('削除',
                              style: TextStyle(color: Colors.red))),
                  ],
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => ref.refresh(_eventDetailProvider(id).future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ステータス
                _StatusBanner(status: event.status),
                const SizedBox(height: 12),

                // 基本情報
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row(context, Icons.category_outlined, '種別',
                            event.eventType.label),
                        _row(context, Icons.calendar_today_outlined, '日付',
                            DateFormat('yyyy/MM/dd (E)', 'ja')
                                .format(event.eventDate)),
                        if (event.startTime != null)
                          _row(context, Icons.schedule_outlined, '時間',
                              '${event.startTime}'
                              '${event.endTime != null ? " ~ ${event.endTime}" : ""}'),
                        if (event.location != null)
                          _row(context, Icons.place_outlined, '場所',
                              event.location!),
                        if (event.notes != null)
                          _row(context, Icons.notes_outlined, '備考',
                              event.notes!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 出欠状況 — ListTile の trailing に大きなボタンを置かず
                // Padding + Row で素直に並べる
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('出欠状況',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          '出席 ${data.presentCount}名 '
                          '/ 欠席 ${data.absentCount}名 '
                          '/ 未定 ${data.attendances.length - data.presentCount - data.absentCount}名',
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.checklist, size: 18),
                            label: const Text('出欠管理を開く'),
                            onPressed: () =>
                                context.go('/events/$id/attendance'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 木の葉章配布数
                if (data.badges.isNotEmpty || (user?.role.canEdit ?? false))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Text('木の葉章配布数',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const Spacer(),
                            if (user?.role.canEdit ?? false)
                              TextButton(
                                onPressed: () => _editLeafBadges(
                                    context, ref, event, data.badges),
                                child: const Text('編集'),
                              ),
                          ]),
                          const SizedBox(height: 8),
                          if (data.badges.isEmpty)
                            const Text('まだ設定されていません',
                                style: TextStyle(color: Colors.grey))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: data.badges
                                  .map((b) => _LeafBadgeChip(badge: b))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(
      BuildContext context, IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
              width: 60,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant))),
          Expanded(
              child:
                  Text(value, style: const TextStyle(fontSize: 14))),
        ]),
      );

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Event event) async {
    final canDel =
        await ref.read(eventRepositoryProvider).canDelete(event.id);
    if (!context.mounted) return;
    if (!canDel) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('完了済みまたは出席情報があるため削除できません')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('イベントを削除'),
        content: Text('「${event.title}」を削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(eventRepositoryProvider).delete(event.id);
      context.go('/events');
    }
  }

  Future<void> _confirmComplete(
      BuildContext context, WidgetRef ref, Event event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('イベントを完了にする'),
        content: const Text(
            '完了にすると木の葉章が各スカウトに反映されます。\nよろしいですか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('完了にする')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final eventRepo = ref.read(eventRepositoryProvider);
    final scoutRepo = ref.read(scoutRepositoryProvider);
    final twigRepo = ref.read(twigBadgeRepositoryProvider);

    await eventRepo.update(event.copyWith(
      status: EventStatus.completed,
      completedAt: DateTime.now(),
    ));

    final badges = await eventRepo.getLeafBadges(event.id);
    final totalBadges = badges.fold(0, (sum, b) => sum + b.count);
    if (totalBadges > 0) {
      final attendances = await ref
          .read(attendanceRepositoryProvider)
          .getByEvent(event.id);
      final presentScoutIds = attendances
          .where((a) =>
              a.memberType == MemberType.scout &&
              a.status == AttendanceStatus.present)
          .map((a) => a.memberId!)
          .toList();

      for (final sid in presentScoutIds) {
        await scoutRepo.addLeafBadges(sid, totalBadges);
        final scout = await scoutRepo.getById(sid);
        if (scout != null && scout.pendingTwigBadges > 0) {
          for (int i = 0; i < scout.pendingTwigBadges; i++) {
            await twigRepo.create(
                scoutId: sid,
                scoutName: scout.name,
                eventId: event.id);
          }
        }
      }
    }

    if (context.mounted) {
      ref.invalidate(_eventDetailProvider(event.id));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('イベントを完了にしました')));
    }
  }

  Future<void> _editLeafBadges(BuildContext context, WidgetRef ref,
      Event event, List<EventLeafBadge> existing) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _LeafBadgeEditor(event: event, existing: existing, ref: ref),
    );
    ref.invalidate(_eventDetailProvider(event.id));
  }
}

// ─── StatusBanner ────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final EventStatus status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    IconData icon;
    switch (status) {
      case EventStatus.completed:
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        icon = Icons.check_circle_outline;
      case EventStatus.ongoing:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        icon = Icons.play_circle_outline;
      case EventStatus.cancelled:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        icon = Icons.cancel_outlined;
      default:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        icon = Icons.schedule_outlined;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, color: fg, size: 18),
        const SizedBox(width: 8),
        Text(status.label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── LeafBadgeChip ───────────────────────────────────────────
class _LeafBadgeChip extends StatelessWidget {
  final EventLeafBadge badge;
  const _LeafBadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badge.badgeType.color.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badge.badgeType.color.withAlpha(120)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: badge.badgeType.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('${badge.badgeType.label} ${badge.count}枚',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─── LeafBadgeEditor (BottomSheet) ───────────────────────────
class _LeafBadgeEditor extends ConsumerStatefulWidget {
  final Event event;
  final List<EventLeafBadge> existing;
  final WidgetRef ref;

  const _LeafBadgeEditor({
    required this.event,
    required this.existing,
    required this.ref,
  });

  @override
  ConsumerState<_LeafBadgeEditor> createState() => _LeafBadgeEditorState();
}

class _LeafBadgeEditorState extends ConsumerState<_LeafBadgeEditor> {
  late Map<LeafBadgeType, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final t in LeafBadgeType.values)
        t: TextEditingController(
          text: widget.existing
                  .where((b) => b.badgeType == t)
                  .firstOrNull
                  ?.count
                  .toString() ??
              '0',
        ),
    };
  }

  Future<void> _save() async {
    final repo = ref.read(eventRepositoryProvider);
    for (final t in LeafBadgeType.values) {
      final count = int.tryParse(_ctrls[t]!.text) ?? 0;
      final existing =
          widget.existing.where((b) => b.badgeType == t).firstOrNull;
      await repo.upsertLeafBadge(EventLeafBadge(
        id: existing?.id ?? _uuid.v4(),
        eventId: widget.event.id,
        badgeType: t,
        count: count,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('木の葉章配布数の設定',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...LeafBadgeType.values.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: t.color, shape: BoxShape.circle),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(t.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500)),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _ctrls[t],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                          suffixText: '枚', isDense: true),
                    ),
                  ),
                ]),
              )),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('保存する')),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }
}
