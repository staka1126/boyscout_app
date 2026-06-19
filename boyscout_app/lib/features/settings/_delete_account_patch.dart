  // ─── アカウント削除 ──────────────────────────────────────
  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    // 唯一の管理者かつ他にメンバーがいる場合はブロック
    try {
      final rows = await SupabaseConfig.client.rpc('get_troop_members');
      final members = rows as List;
      final adminCount = members.where((m) => m['member_role'] == 'admin').length;
      final memberCount = members.length;

      if (adminCount == 1 && memberCount > 1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('あなたが唯一の管理者です。先に他のメンバーを管理者に昇格させてから削除してください。'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    } catch (_) {
      // RPC失敗（メンバーなし等）は続行
    }

    final ok1 = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('アカウントを削除する'),
        content: const Text(
            'アカウントを削除すると、このアプリへのアクセスができなくなります。\n\nローカルデータは端末に残ります。\n\nこの操作は取り消せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok1 != true || !context.mounted) return;

    final ok2 = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('本当に削除しますか？'),
        content: const Text('本当にアカウントを削除してよいですか？\n復元する方法はありません。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('完全に削除する'),
          ),
        ],
      ),
    );
    if (ok2 != true || !context.mounted) return;

    try {
      await SupabaseConfig.client.functions.invoke('delete-account');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('troop_id');
      ref.read(currentTroopIdProvider.notifier).state = null;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('アカウントを削除しました')));
        context.go('/login');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除に失敗しました: $e'), backgroundColor: Colors.red));
      }
    }
  }