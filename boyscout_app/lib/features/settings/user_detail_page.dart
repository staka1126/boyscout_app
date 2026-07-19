import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/models.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/repositories.dart';
import '../../core/supabase_config.dart';
import '../dashboard/dashboard_page.dart';
import 'users_list_page.dart';

final _currentRoleProvider = FutureProvider<String?>((ref) async {
  final user = SupabaseConfig.currentUser;
  if (user == null) return null;
  final member = await SupabaseConfig.client
      .from('troop_members')
      .select('role')
      .eq('user_id', user.id)
      .maybeSingle();
  return member?['role'] as String?;
});

final _userDetailProvider = FutureProvider.family<_UserDetailData, String>((ref, id) async {
  final user = await ref.read(userRepositoryProvider).getById(id);
  final attendanceHistory = await ref.read(attendanceRepositoryProvider).getByUser(id);
  return _UserDetailData(user: user, attendanceHistory: attendanceHistory);
});

class _UserDetailData {
  final AppUser? user;
  final List<ScoutAttendanceRecord> attendanceHistory;
  _UserDetailData({required this.user, this.attendanceHistory = const []});
}

class UserDetailPage extends ConsumerWidget {
  final String id;
  const UserDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_userDetailProvider(id));
    final isLimited = ref.watch(_currentRoleProvider).maybeWhen(
      data: (role) => role == 'limited',
      orElse: () => false,
    );
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('エラー: $e'))),
      data: (data) {
        final user = data.user;
        if (user == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('リーダーが見つかりません')));
        }
        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(user.name),
            actions: [
              if (!isLimited) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await context.push('/settings/users/${user.id}/edit');
                    ref.invalidate(_userDetailProvider(id));
                    ref.invalidate(usersProvider);
                    ref.invalidate(dashboardProvider);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, user),
                ),
              ],
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(child: Padding(padding: const EdgeInsets.all(20),
                child: Row(children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: user.isRetired ? cs.surfaceContainerHighest : cs.primaryContainer,
                    child: Text(user.name.isNotEmpty ? user.name[0] : '?',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                            color: user.isRetired ? cs.onSurfaceVariant : cs.onPrimaryContainer)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(user.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                      if (user.isRetired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text('引退', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                      child: Text(user.role.label,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer)),
                    ),
                  ])),
                ]))),
              const SizedBox(height: 12),
              _infoCard(context, '連絡先', [
                if (user.email != null) _InfoRow('メール', user.email!),
                if (user.phone != null) _InfoRow('電話', user.phone!),
                if (user.gender != null)
                  _InfoRow('性別', user.gender == 'male' ? '男性' : user.gender == 'female' ? '女性' : 'その他'),
              ]),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AppUser user) async {
    final canDelete = await ref.read(userRepositoryProvider).canDelete(user.id);
    if (!context.mounted) return;
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('出欠履歴があるため削除できません')));
      return;
    }
    final ok = await showDialog<bool>(context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('リーダーを削除'),
        content: Text('${user.name} を削除しますか？この操作は取り消せません。'),
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
      await ref.read(userRepositoryProvider).delete(user.id);
      ref.invalidate(usersProvider);
      ref.invalidate(dashboardProvider);
      context.go('/settings/users');
    }
  }
}

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
