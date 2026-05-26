import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';

// ─── Provider ────────────────────────────────────────────────
final _attendanceProvider =
    FutureProvider.family<_AttendanceData, String>((ref, eventId) async {
  final event = await ref.read(eventRepositoryProvider).getById(eventId);
  final list = await ref.read(attendanceRepositoryProvider).getByEvent(eventId);
  return _AttendanceData(event: event!, list: list);
});

class _AttendanceData {
  final Event event;
  final List<Attendance> list;

  _AttendanceData({required this.event, required this.list});

  List<Attendance> get users =>
      list.where((a) => a.memberType == MemberType.user).toList();
  List<Attendance> get scouts =>
      list.where((a) => a.memberType == MemberType.scout).toList();
  List<Attendance> get others => list
      .where((a) =>
          a.memberType != MemberType.user &&
          a.memberType != MemberType.scout)
      .toList();

  int get presentCount =>
      list.where((a) => a.status == AttendanceStatus.present).length;
  int get absentCount =>
      list.where((a) => a.status == AttendanceStatus.absent).length;
}

// ─── AttendancePage ──────────────────────────────────────────
class AttendancePage extends ConsumerWidget {
  final String eventId;
  const AttendancePage({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_attendanceProvider(eventId));

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('エラー: $e'))),
      data: (data) => Scaffold(
        appBar: AppBar(
          title: Text(data.event.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'メンバーを追加',
              onPressed: () => _showAddMemberSheet(context, ref, data.event),
            ),
          ],
        ),
        body: Column(
          children: [
            // サマリバー
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(children: [
                _CountBadge(
                    label: '出席',
                    count: data.presentCount,
                    color: const Color(0xFF43A047)),
                const SizedBox(width: 12),
                _CountBadge(
                    label: '欠席',
                    count: data.absentCount,
                    color: Colors.red),
                const SizedBox(width: 12),
                _CountBadge(
                    label: '未定',
                    count: data.list.length -
                        data.presentCount -
                        data.absentCount,
                    color: Colors.grey),
                const Spacer(),
                Text('計 ${data.list.length}名',
                    style: Theme.of(context).textTheme.labelMedium),
              ]),
            ),
            // リスト
            Expanded(
              child: ListView(
                children: [
                  if (data.users.isNotEmpty) ...[
                    _sectionHeader(context, 'リーダー'),
                    ...data.users.map((a) => _AttendanceTile(
                          attendance: a,
                          onChanged: (s) => _updateStatus(ref, a.id, s),
                        )),
                  ],
                  if (data.scouts.isNotEmpty) ...[
                    _sectionHeader(context, 'スカウト'),
                    ...data.scouts.map((a) => _AttendanceTile(
                          attendance: a,
                          onChanged: (s) => _updateStatus(ref, a.id, s),
                        )),
                  ],
                  if (data.others.isNotEmpty) ...[
                    _sectionHeader(context, 'その他'),
                    ...data.others.map((a) => _AttendanceTile(
                          attendance: a,
                          onChanged: (s) => _updateStatus(ref, a.id, s),
                          onRemove: () => _remove(ref, a.id),
                        )),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.8)),
      );

  Future<void> _updateStatus(
      WidgetRef ref, String id, AttendanceStatus status) async {
    await ref.read(attendanceRepositoryProvider).updateStatus(id, status);
    ref.invalidate(_attendanceProvider(eventId));
  }

  Future<void> _remove(WidgetRef ref, String id) async {
    await ref.read(attendanceRepositoryProvider).remove(id);
    ref.invalidate(_attendanceProvider(eventId));
  }

  Future<void> _showAddMemberSheet(
      BuildContext context, WidgetRef ref, Event event) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddMemberSheet(event: event, ref: ref),
    );
    ref.invalidate(_attendanceProvider(eventId));
  }
}

// ─── AttendanceTile ──────────────────────────────────────────
class _AttendanceTile extends StatelessWidget {
  final Attendance attendance;
  final ValueChanged<AttendanceStatus> onChanged;
  final VoidCallback? onRemove;

  const _AttendanceTile({
    required this.attendance,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: cs.primaryContainer,
          child: Text(
            attendance.memberName.isNotEmpty
                ? attendance.memberName[0]
                : '?',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: cs.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(attendance.memberName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              Text(attendance.memberType.label,
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        // トグルボタン（アイコンのみで幅を節約）
        _ToggleGroup(
          current: attendance.status,
          onChanged: onChanged,
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                size: 18, color: Colors.red),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ]),
    );
  }
}

// ─── ToggleGroup（アイコン＋短いラベル） ──────────────────────
class _ToggleGroup extends StatelessWidget {
  final AttendanceStatus current;
  final ValueChanged<AttendanceStatus> onChanged;

  const _ToggleGroup({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _ToggleBtn(
        icon: Icons.check,
        active: current == AttendanceStatus.present,
        activeColor: const Color(0xFF43A047),
        onTap: () => onChanged(AttendanceStatus.present),
        tooltip: '出席',
      ),
      const SizedBox(width: 4),
      _ToggleBtn(
        icon: Icons.close,
        active: current == AttendanceStatus.absent,
        activeColor: Colors.red,
        onTap: () => onChanged(AttendanceStatus.absent),
        tooltip: '欠席',
      ),
      const SizedBox(width: 4),
      _ToggleBtn(
        icon: Icons.remove,
        active: current == AttendanceStatus.pending,
        activeColor: Colors.grey,
        onTap: () => onChanged(AttendanceStatus.pending),
        tooltip: '未定',
      ),
    ]);
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  final String tooltip;

  const _ToggleBtn({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active
                ? activeColor.withAlpha(40)
                : Colors.transparent,
            border: Border.all(
                color: active ? activeColor : Colors.grey.shade300,
                width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon,
              size: 16,
              color: active ? activeColor : Colors.grey.shade400),
        ),
      ),
    );
  }
}

// ─── CountBadge ──────────────────────────────────────────────
class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountBadge(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text('$label $count',
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ─── AddMemberSheet ──────────────────────────────────────────
class _AddMemberSheet extends ConsumerStatefulWidget {
  final Event event;
  final WidgetRef ref;
  const _AddMemberSheet({required this.event, required this.ref});

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  final _nameCtrl = TextEditingController();
  MemberType _type = MemberType.other;

  Future<List<Scout>> _loadExtraScouts() async {
    final troopId = ref.read(currentTroopIdProvider)!;
    final all =
        await ref.read(scoutRepositoryProvider).getByTroop(troopId);
    final existing = await ref
        .read(attendanceRepositoryProvider)
        .getByEvent(widget.event.id);
    final existingIds = existing.map((a) => a.memberId).toSet();
    return all
        .where((s) =>
            !s.category.isDefaultAttendee &&
            !existingIds.contains(s.id))
        .toList();
  }

  Future<List<CommitteeMember>> _loadCommittee() async {
    final troopId = ref.read(currentTroopIdProvider)!;
    final all = await ref
        .read(committeeRepositoryProvider)
        .getByTroop(troopId);
    final existing = await ref
        .read(attendanceRepositoryProvider)
        .getByEvent(widget.event.id);
    final existingIds = existing.map((a) => a.memberId).toSet();
    return all.where((c) => !existingIds.contains(c.id)).toList();
  }

  Future<void> _addOther() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    await ref.read(attendanceRepositoryProvider).add(Attendance(
          id: const Uuid().v4(),
          eventId: widget.event.id,
          memberType: MemberType.other,
          memberName: _nameCtrl.text.trim(),
          status: AttendanceStatus.present,
        ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addScout(Scout s) async {
    await ref.read(attendanceRepositoryProvider).add(Attendance(
          id: const Uuid().v4(),
          eventId: widget.event.id,
          memberType: MemberType.scout,
          memberId: s.id,
          memberName: s.name,
          status: AttendanceStatus.present,
        ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addCommittee(CommitteeMember c) async {
    await ref.read(attendanceRepositoryProvider).add(Attendance(
          id: const Uuid().v4(),
          eventId: widget.event.id,
          memberType: MemberType.committee,
          memberId: c.id,
          memberName: c.name,
          status: AttendanceStatus.present,
        ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text('メンバーを追加',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SegmentedButton<MemberType>(
            segments: const [
              ButtonSegment(
                  value: MemberType.scout, label: Text('スカウト')),
              ButtonSegment(
                  value: MemberType.committee, label: Text('団委員')),
              ButtonSegment(
                  value: MemberType.other, label: Text('その他')),
            ],
            selected: {_type},
            onSelectionChanged: (s) =>
                setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _type == MemberType.other
                ? Column(children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration:
                          const InputDecoration(labelText: '氏名'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _addOther,
                        child: const Text('追加する')),
                  ])
                : _type == MemberType.scout
                    ? FutureBuilder<List<Scout>>(
                        future: _loadExtraScouts(),
                        builder: (_, snap) {
                          if (!snap.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snap.data!.isEmpty) {
                            return const Center(
                                child: Text('追加できるスカウトはいません'));
                          }
                          return ListView.builder(
                            controller: controller,
                            itemCount: snap.data!.length,
                            itemBuilder: (_, i) {
                              final s = snap.data![i];
                              return ListTile(
                                title: Text(s.name),
                                subtitle: Text(s.category.label),
                                trailing: const Icon(Icons.add),
                                onTap: () => _addScout(s),
                              );
                            },
                          );
                        })
                    : FutureBuilder<List<CommitteeMember>>(
                        future: _loadCommittee(),
                        builder: (_, snap) {
                          if (!snap.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snap.data!.isEmpty) {
                            return const Center(
                                child: Text('追加できる団委員はいません'));
                          }
                          return ListView.builder(
                            controller: controller,
                            itemCount: snap.data!.length,
                            itemBuilder: (_, i) {
                              final c = snap.data![i];
                              return ListTile(
                                title: Text(c.name),
                                subtitle: Text(c.category.label),
                                trailing: const Icon(Icons.add),
                                onTap: () => _addCommittee(c),
                              );
                            },
                          );
                        }),
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}
