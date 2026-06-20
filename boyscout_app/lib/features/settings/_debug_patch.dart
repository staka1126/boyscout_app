    final cs = Theme.of(context).colorScheme;
    final profile = ref.watch(_currentProfileProvider);
    final troopAsync = ref.watch(_troopInfoProvider);
    final troopId = ref.watch(currentTroopIdProvider);
    // ignore: avoid_print
    print('SettingsPage build: troopId=' + (troopId ?? 'null'));
    final isAdmin = profile.maybeWhen(