import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/models.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../dashboard/dashboard_page.dart';
import 'guardians_list_page.dart';

final _guardianDetailProvider =
    FutureProvider.family<_GuardianDetailData, String>((ref, id) async {
  final guardian = await ref.read(guardianRepositoryProvider).getById(id);
  final scouts = guardian == null
      ? <Scout>[]
      : await ref.read(guardianRepositoryProvider).getScoutsByGuardian(id);
  final attendanceHistory = await ref.read(attendanceRepositoryProvider).getByGuardian(id);
  return _GuardianDetailData(guardian: guardian, scouts: scouts, attendanceHistory: attendanceHistory);
});

class _GuardianDetailData {
  final Guardian? guardian;
  final List<Scout> scouts;
  final List<ScoutAttendanceRecord> attendanceHistory;
  _GuardianDetailData({required this.guardian, required this.scouts, this.attendanceHistory = const []});
}

class GuardianDetailPage extends ConsumerWidget {
  final String id;
  const GuardianDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_guardianDetailProvider(id));
    final troopId = ref.watch(currentTroopIdProvider);

    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('エラー: $e'))),
      data: (data) {
        final guardian = data.guardian;
        if (guardian == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('保護者が見つかりません')));
        }
        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(guardian.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  await context.push('/settings/guardians/${guardian.id}/edit');
                  ref.invalidate(_guardianDetailProvider(id));
                  ref.invalidate(guardiansProvider);
                  ref.invalidate(dashboardProvider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, ref, guardian),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ヘッダーカード
              Card(child: Padding(padding: const EdgeInsets.all(20),
                child: Row(children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: cs.secondaryContainer,
                    child: Text(guardian.name.isNotEmpty ? guardian.name[0] : '?',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                            color: cs.onSecondaryContainer)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(guardian.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                ]))),
              const SizedBox(height: 12),

              // 連絡先
              _infoCard(context, '連絡先', [
                if (guardian.email != null) _InfoRow('メール', guardian.email!),
                if (guardian.phone != null) _InfoRow('電話', guardian.phone!),
                if (guardian.gender != null)
                  _InfoRow('性別', guardian.gender == 'male' ? '男性' : guardian.gender == 'female' ? '女性' : 'その他'),
              ]),
              const SizedBox(height: 12),

              // 紐付きスカウト（スカウト詳細の保護者セクションと同様のUI）
              Card(child: Padding(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('紐付きスカウト',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary)),
                    const Spacer(),
                    if (troopId != null)
                      TextButton.icon(
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('紐付け'),
                        onPressed: () => _showLinkSheet(context, ref, guardian, data.scouts, troopId),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  if (data.scouts.isEmpty)
                    const Text('スカウトが紐付いていません', style: TextStyle(color: Colors.grey))
                  else
                    ...data.scouts.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        CircleAvatar(radius: 16, backgroundColor: cs.primaryContainer,
                          child: Text(s.name.isNotEmpty ? s.name[0] : '?',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: cs.onPrimaryContainer))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text(s.category.label,
                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ])),
                        if (troopId != null)
                          IconButton(
                            icon: Icon(Icons.link_off, size: 18, color: cs.error),
                            tooltip: '紐付けを解除',
                            onPressed: () => _confirmUnlink(context, ref, guardian, s, troopId),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ]),
                    )),
                ]))),
              const SizedBox(height: 12),

              Card(child: Padding(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('参加履歴', style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: cs.primary)),
                  const SizedBox(height: 8),
                  if (data.attendanceHistory.isEmpty)
                    const Text('参加履歴はありません', style: TextStyle(color: Colors.grey))
                  else
                    ...data.attendanceHistory.map((r) => InkWell(
                      onTap: () => context.push('/events/${r.eventId}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          SizedBox(width: 88, child: Text(
                              DateFormat('yyyy/MM/dd').format(r.eventDate),
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
                          Expanded(child: Text(r.title,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          _attendanceIcon(cs, r.attendanceStatus),
                        ]),
                      ),
                    )),
                ]))),
            ],
          ),
        );
      },
    );
  }

  Widget _attendanceIcon(ColorScheme cs, AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icon(Icons.check_circle, size: 18, color: cs.primary);
      case AttendanceStatus.absent:
        return Icon(Icons.cancel, size: 18, color: cs.error);
      case AttendanceStatus.pending:
        return Icon(Icons.remove_circle_outline, size: 18, color: cs.onSurfaceVariant);
    }
  }

  Widget _infoCard(BuildContext context, String title, List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox();
    return Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        ...rows,
      ])));
  }

  Future<void> _showLinkSheet(BuildContext context, WidgetRef ref,
      Guardian guardian, List<Scout> linked, String troopId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _LinkScoutSheet(
          guardian: guardian, linked: linked, troopId: troopId, ref: ref),
    );
    ref.invalidate(_guardianDetailProvider(guardian.id));
    ref.invalidate(guardiansProvider);
  }

  Future<void> _confirmUnlink(BuildContext context, WidgetRef ref,
      Guardian guardian, Scout scout, String troopId) async {
    final ok = await showDialog<bool>(context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('紐付けを解除'),
        content: Text('${guardian.name} と ${scout.name} の紐付けを解除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('解除'),
          ),
        ],
      ));
    if (ok == true) {
      await ref.read(guardianRepositoryProvider).unlink(
          scoutId: scout.id, guardianId: guardian.id, troopId: troopId);
      ref.invalidate(_guardianDetailProvider(guardian.id));
      ref.invalidate(guardiansProvider);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Guardian guardian) async {
    final canDelete = await ref.read(guardianRepositoryProvider).canDelete(guardian.id);
    if (!context.mounted) return;
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('スカウトと紐付いているか出欠履歴があるため削除できません')));
      return;
    }
    final ok = await showDialog<bool>(context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('保護者を削除'),
        content: Text('${guardian.name} を削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ));
    if (ok == true && context.mounted) {
      await ref.read(guardianRepositoryProvider).delete(guardian.id);
      ref.invalidate(guardiansProvider);
      ref.invalidate(dashboardProvider);
      context.go('/settings/guardians');
    }
  }
}

// ─── スカウト紐付けシート ─────────────────────────────────────
class _LinkScoutSheet extends ConsumerStatefulWidget {
  final Guardian guardian;
  final List<Scout> linked;
  final String troopId;
  final WidgetRef ref;
  const _LinkScoutSheet({
    required this.guardian,
    required this.linked,
    required this.troopId,
    required this.ref,
  });

  @override
  ConsumerState<_LinkScoutSheet> createState() => _LinkScoutSheetState();
}

class _LinkScoutSheetState extends ConsumerState<_LinkScoutSheet> {
  List<Scout>? _all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ref.read(scoutRepositoryProvider).getByTroop(widget.troopId);
    if (mounted) setState(() => _all = all);
  }

  @override
  Widget build(BuildContext context) {
    final linkedIds = widget.linked.map((s) => s.id).toSet();
    final unlinked = _all?.where((s) => !linkedIds.contains(s.id)).toList() ?? [];
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4, expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('スカウトを紐付ける',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${widget.guardian.name} に紐付けるスカウトを選んでください',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (_all == null)
            const Center(child: CircularProgressIndicator())
          else if (unlinked.isEmpty)
            const Expanded(child: Center(child: Text('紐付け可能なスカウトがいません')))
          else
            Expanded(child: ListView.builder(
              controller: controller,
              itemCount: unlinked.length,
              itemBuilder: (_, i) {
                final s = unlinked[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Text(s.name.isNotEmpty ? s.name[0] : '?',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer)),
                  ),
                  title: Text(s.name),
                  subtitle: Text(s.category.label,
                      style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.link),
                  onTap: () => _link(s),
                );
              },
            )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _link(Scout scout) async {
    await ref.read(guardianRepositoryProvider).link(
        scoutId: scout.id, guardianId: widget.guardian.id, troopId: widget.troopId);
    if (mounted) Navigator.pop(context);
  }
}

// ─── InfoRow ─────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ]));
  }
}
