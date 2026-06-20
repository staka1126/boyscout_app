  Future<void> _load() async {
    // 既存の団IDがある場合のみ読み込む（新規ユーザーは空で表示）
    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) return;

    try {
      // Supabaseから自分の団を取得
      final troopData = await SupabaseConfig.client
          .from('troops')
          .select('id, name, location, contact')
          .eq('id', troopId)
          .maybeSingle();

      if (troopData != null && mounted) {
        // ローカルDBにも反映
        final troop = await ref.read(troopRepositoryProvider).upsert(
          id: troopData['id'] as String,
          name: troopData['name'] as String,
          location: troopData['location'] as String?,
          contact: troopData['contact'] as String?,
        );
        _existing = troop;
        _nameCtrl.text = troop.name;
        _locationCtrl.text = troop.location ?? '';
        _contactCtrl.text = troop.contact ?? '';
        setState(() {});
      }
    } catch (_) {
      // オフライン時はローカルから取得
      final troop = await ref.read(troopRepositoryProvider).getFirst();
      if (troop != null && mounted) {
        _existing = troop;
        _nameCtrl.text = troop.name;
        _locationCtrl.text = troop.location ?? '';
        _contactCtrl.text = troop.contact ?? '';
        setState(() {});
      }
    }
  }