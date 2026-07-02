  // ─────────────────────────────────────────────
  // 招待コード使用
  // ─────────────────────────────────────────────
  Future<String> joinWithInviteCode(String code) async {
    final user = currentUser;
    if (user == null) throw Exception('ログインが必要です');

    final invite = await _client
        .from('invite_codes')
        .select('id, troop_id, expires_at, used_by, role')
        .eq('code', code.toUpperCase())
        .maybeSingle();

    if (invite == null) throw Exception('招待コードが見つかりません');
    if (invite['used_by'] != null) throw Exception('この招待コードはすでに使用されています');

    final expiresAt = DateTime.parse(invite['expires_at'] as String);
    if (DateTime.now().isAfter(expiresAt)) throw Exception('招待コードの有効期限が切れています');

    final troopId = invite['troop_id'] as String;
    final inviteId = invite['id'] as String;
    final role = invite['role'] as String? ?? 'member';

    // すでに同じ団に所属していないか確認
    final existing = await _client
        .from('troop_members')
        .select('id')
        .eq('user_id', user.id)
        .eq('troop_id', troopId)
        .maybeSingle();
    if (existing != null) throw Exception('すでにこの団に参加しています');

    // profilesが存在しない場合に備えてupsertで保証
    await _client.from('profiles').upsert({
      'id': user.id,
      'name': user.email?.split('@').first ?? 'user',
      'email': user.email,
    }, onConflict: 'id');

    await _client.from('troop_members').insert({
      'user_id': user.id,
      'troop_id': troopId,
      'role': role,
    });

    await _client.from('invite_codes').update({
      'used_by': user.id,
      'used_at': DateTime.now().toIso8601String(),
    }).eq('id', inviteId);

    return troopId;
  }