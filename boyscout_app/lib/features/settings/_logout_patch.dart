  static Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('troop_id');
    ref.read(currentTroopIdProvider.notifier).state = null;
    ref.invalidate(_currentProfileProvider);
    await AuthService.instance.signOut();
    if (context.mounted) context.go('/login');
  }