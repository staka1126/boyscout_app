    try {
      // RPC経由でアカウント削除（SECURITY DEFINERでauth.usersから自分を削除）
      await SupabaseConfig.client.rpc('delete_own_account');

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