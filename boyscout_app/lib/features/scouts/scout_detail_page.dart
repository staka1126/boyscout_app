import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/models.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/repositories.dart';
import '../../core/supabase_config.dart';
import '../badges/badges_page.dart';
import '../dashboard/dashboard_page.dart';
import 'scouts_page.dart';

final _scoutDetailRoleProvider = FutureProvider<String?>((ref) async {
  final user = SupabaseConfig.currentUser;
  if (user == null) return null;
  final member = await SupabaseConfig.client
      .from('troop_members')
      .select('role')
      .eq('user_id', user.id)
      .maybeSingle();
  return member?['role'] as String?;
});

final _scoutDetailProvider =
    FutureProvider.family<_ScoutDetailData, String>((ref, id) async {
  final scout = await ref.read(scoutRepositoryProvider).getById(id);
  final guardians = await ref.read(guardianRepositoryProvider).getByScout(id);
  final attendanceHistory = await ref.read(attendanceRepositoryProvider).getByScout(id);
  return _ScoutDetailData(scout: scout, guardians: guardians, attendanceHistory: attendanceHistory);
});

class _ScoutDetailData {
  final Scout? scout;
  final List<Guardian> guardians;
  final List<ScoutAttendanceRecord> attendanceHistory;
  _ScoutDetailData({required this.scout, required this.guardians, this.attendanceHistory = const []});
}

class ScoutDetailPage extends ConsumerWidget {
  final String id;
  const ScoutDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_scoutDetailProvider(id));
    final isLimited = ref.watch(_scoutDetailRoleProvider).maybeWhen(
      data: (role) => role == 'limited',
      orElse: () => false,
    );

    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('エラー: $e'))),
      data: (data) {
        final scout = data.scout;
        if (scout == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('スカウトが見つかりません')));
        }

        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(scout.name),
            actions: [
              if (!isLimited) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await context.push('/scouts/$id/edit');
                    ref.invalidate(_scoutDetailProvider(id));
                    ref.invalidate(scoutsProvider);
                    ref.invalidate(badgesProvider);
                    ref.invalidate(dashboardProvider);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, scout),
                ),
              ],
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(child: Padding(padding: const EdgeInsets.all(20),
                child: Row(children: [
                  CircleAvatar(radius: 32, backgroundColor: cs.primaryContainer,
                    child: Text(scout.name.isNotEmpty ? scout.name[0] : '?',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(scout.name, style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    _chip(context, scout.category.label, cs.secondaryContainer, cs.onSecondaryContainer),
                  ])),
                ]))),
              const SizedBox(height: 12),

              if ([scout.grade, scout.gender, scout.joinedAt, scout.enrollmentYear, scout.birthday].any((v) => v != null))
                _infoCard(context, '基本情報', [
                  if (scout.grade != null) _InfoRow('初期登録時学年', scout.grade!),
                  if (scout.gender != null)
                    _InfoRow('性別', scout.gender == 'male' ? '男性' : scout.gender == 'female' ? '女性' : 'その他'),
                  if (scout.birthday != null)
                    _InfoRow('誕生日', DateFormat('yyyy/MM/dd').format(scout.birthday!)),
                  if (scout.joinedAt != null)
                    _InfoRow('入隊日', DateFormat('yyyy/MM/dd').format(scout.joinedAt!)),
                  if (scout.enrollmentYear != null)
                    _InfoRow('小学校入学年度', '${scout.enrollmentYear}年'),
                ]),
              const SizedBox(height: 12),

              _infoCard(context, '木の葉章・小枝章', [
                _InfoRow('木の葉章（活動取得）', '${scout.leafBadges}枚'),
                if (scout.isTwigBadgeEligible) ...[  
                  _InfoRow('入隊時補正（減算）', '${scout.leafBadgeOffset}枚'),
                  _InfoRow('合計', '${scout.totalLeafBadges}枚', highlight: true),
                  _InfoRow('小枝章（授与済み）', '${scout.twigBadges}本'),
                  if (scout.pendingTwigBadges > 0)
                    _InfoRow('小枝章（授与待ち）', '${scout.pendingTwigBadges}本', highlight: true),
                ] else ...[
                  _InfoRow('表彰（授与済み）', '${scout.otherBadges}回'),
                  if (scout.pendingOtherBadges > 0)
                    _InfoRow('表彰（授与待ち）', '${scout.pendingOtherBadges}回', highlight: true),
                ],
              ]),
              const SizedBox(height: 12),

              Card(child: Padding(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('木の葉章 進捗', style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: cs.primary)),
                  const SizedBox(height: 12),
                  _LeafBadgeProgress(scout: scout),
                ]))),
              const SizedBox(height: 12),

              if (scout.allergies.isNotEmpty || scout.specialNotes != null)
                _infoCard(context, 'アレルギー・特記', [
                  if (scout.allergies.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('アレルギー', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 4,
                          children: scout.allergies.map((a) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(a.label, style: TextStyle(fontSize: 11, color: cs.onErrorContainer)),
                          )).toList()),
                      ]),
                    ),
                  if (scout.specialNotes != null)
                    _InfoRow('特記事項', scout.specialNotes!),
                ]),
              const SizedBox(height: 12),

              Card(child: Padding(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('保護者', style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: cs.primary)),
                    const Spacer(),
                    if (!isLimited)
                      TextButton.icon(
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('紐付け'),
                        onPressed: () => _showLinkSheet(context, ref, scout, data.guardians),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  if (data.guardians.isEmpty)
                    const Text('保護者が登録されていません', style: TextStyle(color: Colors.grey))
                  else
                    ...data.guardians.map((g) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        CircleAvatar(radius: 16, backgroundColor: cs.secondaryContainer,
                          child: Text(g.name.isNotEmpty ? g.name[0] : '?',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: cs.onSecondaryContainer))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(g.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          if (g.phone != null || g.email != null)
                            Text([if (g.email != null) g.email!, if (g.phone != null) g.phone!].join('　'),
                                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ])),
                        IconButton(
                          icon: Icon(Icons.link_off, size: 18, color: cs.error),
                          tooltip: '紐付けを解除',
                          onPressed: isLimited ? null : () => _confirmUnlink(context, ref, scout, g),
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

  Widget _chip(BuildContext context, String label, Color bg, Color fg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)));

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
      Scout scout, List<Guardian> linked) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _LinkGuardianSheet(scout: scout, linked: linked, ref: ref),
    );
    ref.invalidate(_scoutDetailProvider(id));
  }

  Future<void> _confirmUnlink(BuildContext context, WidgetRef ref,
      Scout scout, Guardian guardian) async {
    final ok = await showDialog<bool>(context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('紐付けを解除'),
        content: Text('${scout.name} と ${guardian.name} の紐付けを解除しますか？'),
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
          scoutId: scout.id, guardianId: guardian.id, troopId: scout.troopId);
      ref.invalidate(_scoutDetailProvider(id));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Scout scout) async {
    final canDelete = await ref.read(scoutRepositoryProvider).canDelete(scout.id);
    if (!context.mounted) return;
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('出欠履歴または保護者紐付けがあるため削除できません')));
      return;
    }
    final ok = await showDialog<bool>(context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('スカウトを削除'),
        content: Text('${scout.name} を削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ));
    if (ok == true && context.mounted) {
      await ref.read(scoutRepositoryProvider).delete(scout.id);
      ref.invalidate(scoutsProvider);
      ref.invalidate(badgesProvider);
      ref.invalidate(dashboardProvider);
      context.go('/scouts');
    }
  }
}

class _LinkGuardianSheet extends ConsumerStatefulWidget {
  final Scout scout;
  final List<Guardian> linked;
  final WidgetRef ref;
  const _LinkGuardianSheet({required this.scout, required this.linked, required this.ref});

  @override
  ConsumerState<_LinkGuardianSheet> createState() => _LinkGuardianSheetState();
}

class _LinkGuardianSheetState extends ConsumerState<_LinkGuardianSheet> {
  List<Guardian>? _all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ref.read(guardianRepositoryProvider).getAll(troopId: widget.scout.troopId);
    if (mounted) setState(() => _all = all);
  }

  @override
  Widget build(BuildContext context) {
    final linkedIds = widget.linked.map((g) => g.id).toSet();
    final unlinked = _all?.where((g) => !linkedIds.contains(g.id)).toList() ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4, expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('保護者を紐付ける',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${widget.scout.name} に紐付ける保護者を選んでください',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (_all == null)
            const Center(child: CircularProgressIndicator())
          else if (unlinked.isEmpty)
            const Expanded(child: Center(child: Text('紐付け可能な保護者がいません\n設定 › 保護者管理から先に保護者を登録してください')))
          else
            Expanded(child: ListView.builder(
              controller: controller,
              itemCount: unlinked.length,
              itemBuilder: (_, i) {
                final g = unlinked[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Text(g.name.isNotEmpty ? g.name[0] : '?',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSecondaryContainer)),
                  ),
                  title: Text(g.name),
                  subtitle: g.phone != null || g.email != null
                      ? Text([if (g.email != null) g.email!, if (g.phone != null) g.phone!].join('　'),
                          style: const TextStyle(fontSize: 11))
                      : null,
                  trailing: const Icon(Icons.link),
                  onTap: () => _link(g),
                );
              },
            )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _link(Guardian guardian) async {
    await ref.read(guardianRepositoryProvider).link(
        scoutId: widget.scout.id, guardianId: guardian.id, troopId: widget.scout.troopId);
    if (mounted) Navigator.pop(context);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _InfoRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 140, child: Text(label,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))),
        Expanded(child: Text(value, style: TextStyle(
            fontSize: 14,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
            color: highlight ? cs.primary : cs.onSurface))),
      ]));
  }
}

class _LeafBadgeProgress extends StatelessWidget {
  final Scout scout;
  const _LeafBadgeProgress({required this.scout});

  @override
  Widget build(BuildContext context) {
    final inCurrent = scout.totalLeafBadges % 10;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('次の小枝章まで $inCurrent / 10 枚',
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: inCurrent / 10, minHeight: 8, borderRadius: BorderRadius.circular(4)),
      const SizedBox(height: 8),
      Wrap(spacing: 4, runSpacing: 4,
        children: List.generate(10, (i) => Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < inCurrent
                ? const Color(0xFF43A047)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          )))),
    ]);
  }
}
