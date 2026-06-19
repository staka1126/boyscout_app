  Widget _buildLoginForm() {
    return Column(
      children: [
        TextField(
          controller: _loginEmailCtrl,
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _loginPasswordCtrl,
          decoration: InputDecoration(
            labelText: 'パスワード',
            prefixIcon: const Icon(Icons.lock_outlined),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscureLogin ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
            ),
          ),
          obscureText: _obscureLogin,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isLoading ? null : _login,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('ログイン'),
          ),
        ),
        // 開発用：DBリセット同期ボタン
        if (kDebugMode) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('[DEV] ローカルDBをリセットして同期', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
              ),
              onPressed: _isLoading ? null : _devResetAndSync,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _devResetAndSync() async {
    setState(() => _isLoading = true);
    try {
      // ローカルDBを全削除
      final db = await ref.read(troopRepositoryProvider).dbHelper.database;
      await db.transaction((txn) async {
        await txn.execute('DELETE FROM twig_badge_history');
        await txn.execute('DELETE FROM attendances');
        await txn.execute('DELETE FROM event_leaf_badges');
        await txn.execute('DELETE FROM events');
        await txn.execute('DELETE FROM scout_guardians');
        await txn.execute('DELETE FROM committee_members');
        await txn.execute('DELETE FROM guardians');
        await txn.execute('DELETE FROM scouts');
        await txn.execute('DELETE FROM users');
        await txn.execute('DELETE FROM troops');
      });

      // Supabaseにログインして同期
      final email = _loginEmailCtrl.text.trim();
      final password = _loginPasswordCtrl.text;
      if (email.isEmpty || password.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールアドレスとパスワードを入力してからリセットしてください')),
        );
        return;
      }

      await AuthService.instance.signIn(email: email, password: password);
      if (!mounted) return;

      final troopId = await _resolveTroopId();
      if (!mounted) return;

      if (troopId != null) {
        await SyncService.instance.syncFromSupabase(troopId);
        if (!mounted) return;
        ref.read(currentTroopIdProvider.notifier).state = troopId;
        context.go('/dashboard');
      } else {
        context.go('/onboarding');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }