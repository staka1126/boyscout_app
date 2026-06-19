import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_config.dart';

class _InviteCode {
  final String id;
  final String code;
  final DateTime expiresAt;
  final String? usedBy;
  final String? usedByName;

  const _InviteCode({
    required this.id,
    required this.code,
    required this.expiresAt,
    this.usedBy,
    this.usedByName,
  });

  bool get isUsed => usedBy != null;
  bool get isExpired => !isUsed && DateTime.now().isAfter(expiresAt);
}

final _inviteCodesProvider = FutureProvider.autoDispose<List<_InviteCode>>((ref) async {
  final user = SupabaseConfig.currentUser;
  if (user == null) return [];

  final rows = await SupabaseConfig.client.rpc('get_invite_codes');

  return (rows as List).map((r) => _InviteCode(
    id: r['id'] as String,
    code: r['code'] as String,
    expiresAt: DateTime.parse(r['expires_at'] as String),
    usedBy: r['used_by'] as String?,
    usedByName: r['used_by_name'] as String?,
  )).toList();
});

class InviteCodesPage extends ConsumerWidget {
  const InviteCodesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_inviteCodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('招待コード'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_inviteCodesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _generateCode(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新しく発行'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (codes) {
          if (codes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.vpn_key_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('招待コードがまだありません'),
                  SizedBox(height: 4),
                  Text('右下のボタンから発行してください',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: codes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _InviteCodeCard(code: codes[i]),
          );
        },
      ),
    );
  }

  Future<void> _generateCode(BuildContext context, WidgetRef ref) async {
    final user = SupabaseConfig.currentUser;
    if (user == null) return;

    final myMember = await SupabaseConfig.client
        .from('troop_members')
        .select('troop_id')
        .eq('user_id', user.id)
        .maybeSingle();
    if (myMember == null || !context.mounted) return;
    final troopId = myMember['troop_id'] as String;

    // ランダムコード生成（0/O・1/I除外）
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    final code = List.generate(6, (i) => chars[(now ~/ (i + 1)) % chars.length]).join();

    final expiresAt = DateTime.now().toUtc().add(const Duration(days: 7));

    try {
      await SupabaseConfig.client.from('invite_codes').insert({
        'code': code,
        'troop_id': troopId,
        'created_by': user.id,
        'expires_at': expiresAt.toIso8601String(),
      });

      ref.invalidate(_inviteCodesProvider);

      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (dlgCtx) => AlertDialog(
            title: const Text('招待コードを発行しました'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('このコードを招待したいメンバーに伝えてください。\n有効期限は7日間です。'),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(code,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('コードをコピーしました')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('コピー'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('閉じる')),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('発行に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _InviteCodeCard extends StatelessWidget {
  final _InviteCode code;
  const _InviteCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('yyyy/MM/dd HH:mm');

    final (statusLabel, statusColor, statusBg) = code.isUsed
        ? ('使用済み', cs.onSecondaryContainer, cs.secondaryContainer)
        : code.isExpired
            ? ('期限切れ', cs.onSurfaceVariant, cs.surfaceContainerHighest)
            : ('未使用', cs.onPrimaryContainer, cs.primaryContainer);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(code.code,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        fontFamily: 'monospace')),
                const SizedBox(width: 8),
                if (!code.isUsed && !code.isExpired)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('コードをコピーしました')),
                      );
                    },
                    child: Icon(Icons.copy, size: 16, color: cs.onSurfaceVariant),
                  ),
              ]),
              const SizedBox(height: 4),
              if (code.isUsed)
                Text('使用者: ${code.usedByName ?? '不明'}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
              else
                Text('有効期限: ${fmt.format(code.expiresAt.toLocal())}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
        ]),
      ),
    );
  }
}
