  Future<void> _load() async {
    // 既存の団IDがある場合のみ読み込む（新規ユーザーは空で表示）
    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) return;

    final troop = await ref.read(troopRepositoryProvider).getFirst();
    if (troop != null && mounted) {
      _existing = troop;
      _nameCtrl.text = troop.name;
      _locationCtrl.text = troop.location ?? '';
      _contactCtrl.text = troop.contact ?? '';
      setState(() {});
    }
  }