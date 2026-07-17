import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/wood_grain_background.dart';
import '../../core/supabase_config.dart';
import '../../data/providers/app_state_provider.dart';
import '../auth/auth_service.dart';

class TroopMember {
  final String memberId;
  final String userId;
  final String name;
  final String email;
  final String role;
  final bool isMe;
  final String myRole;

  const TroopMember({
    required this.memberId,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.isMe,
    required this.myRole,
  });

  bool get isAdmin => role == 'admin';
  bool get canManage => myRole == 'admin' && !isMe && !isAdmin;
}

// autoDispose で画面を離れるたびにキャッシュをクリア
final troopMembersProvider = FutureProvider.autoDispose<List<TroopMember>>((ref) async {
  final user = SupabaseConfig.currentUser;
  if (user == null) return [];

  try {
    final myMember = await SupabaseConfig.client
        .from('troop_members')
        .select('troop_id, role')
        .eq('user_id', user.id)
        .maybeSingle();

    if (myMember == null) return [];
    final myRole = myMember['role'] as String;

    final rows = await SupabaseConfig.client.rpc('get_troop_members');

    final result = <TroopMember>[];
    for (final m in rows as List) {
      result.add(TroopMember(
        memberId: m['member_id'] as String,
        userId: m['user_id'] as String,
        name: m['name'] as String? ?? '（名前なし）',
        email: m['email'] as String? ?? '',
        role: (m['member_role'] as String).trim(),
        isMe: m['user_id'] == user.id,
        myRole: myRole,
      ));
    }

    result.sort((a, b) {
      const order = {'admin': 0, 'member': 1, 'limited': 2};
      return (order[a.role] ?? 9).compareTo(order[b.role] ?? 9);
    });

    return result;
  } catch (e) {
    debugPrint('troopMembersProvider error: $e');
    return [];
  }
});

class TroopMembersPage extends ConsumerWidget {
  const TroopMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(troopMembersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('利用者管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(troopMembersProvider),
          ),
        ],
      ),
      body: Stack(children: [
        const WoodGrainBackground(),
        async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('エラー: $e')),
          data: (members) {
            if (members.isEmpty) {
              return const Center(child: Text('メンバーがいません'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _MemberCard(
                member: members[i],
                ref: ref,
                onChanged: () => ref.invalidate(troopMembersProvider),
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final TroopMember member;
  final WidgetRef ref;
  final VoidCallback onChanged;

  const _MemberCard({
    required this.member,
    required this.ref,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        onTap: member.canManage ? () => _showActionSheet(context) : null,
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(
            member.name.isNotEmpty ? member.name[0] : '?',
            style: TextStyle(
                color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
          ),
        ),
        title: Row(children: [
          Flexible(
            child: Text(member.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          if (member.isMe) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('自分',
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ),
          ],
        ]),
        subtitle: Text(member.email,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            overflow: TextOverflow.ellipsis),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _RoleBadge(role: member.role),
          if (member.canManage) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 18),
          ],
        ]),
      ),
    );
  }

  Future<void> _showActionSheet(BuildContext context) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(member.name),
        content: Text(member.email,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop('promote'),
            child: const Text('管理者にする'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop('remove'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退会させる'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(null),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case 'promote':
        await _confirmPromote(context);
      case 'remove':
        await _confirmRemove(context);
    }
  }

  Future<void> _confirmPromote(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('管理者にする'),
        content: Text(
            '${member.name} を管理者にしますか？\n\nあなたはメンバーになり、いったんログアウトされます。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(false),
              child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('管理者にする'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await SupabaseConfig.client.rpc('update_member_role', params: {
        'p_member_id': member.memberId,
        'p_new_role': 'admin',
      });

      final myMember = await SupabaseConfig.client
          .from('troop_members')
          .select('id')
          .eq('user_id', SupabaseConfig.currentUser!.id)
          .maybeSingle();
      if (myMember != null) {
        await SupabaseConfig.client.rpc('update_member_role', params: {
          'p_member_id': myMember['id'] as String,
          'p_new_role': 'member',
        });
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} を管理者にしました。ログアウトします。')),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('troop_id');
      ref.read(currentTroopIdProvider.notifier).state = null;
      await AuthService.instance.signOut();

      if (context.mounted) context.go('/login');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('団から退会させる'),
        content: Text(
            '${member.name} をこの団から退会させますか？\n\nアカウント自体は削除されません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(false),
              child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('退会させる'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await SupabaseConfig.client.rpc('remove_troop_member', params: {
        'p_member_id': member.memberId,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.name} を退会させました')),
        );
        onChanged();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = switch (role) {
      'admin' => '管理者',
      'limited' => '制限',
      _ => 'メンバー',
    };
    final color = switch (role) {
      'admin' => cs.primaryContainer,
      'limited' => cs.surfaceContainerHighest,
      _ => cs.secondaryContainer,
    };
    final textColor = switch (role) {
      'admin' => cs.onPrimaryContainer,
      'limited' => cs.onSurfaceVariant,
      _ => cs.onSecondaryContainer,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}
