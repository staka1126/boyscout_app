      if (_original == null) {
        // troopIdを取得（linkScoutIdがあればスカウト経由、なければcurrentTroopId）
        String troopId = ref.read(currentTroopIdProvider) ?? '';
        if (widget.linkScoutId != null) {
          final scout = await ref.read(scoutRepositoryProvider).getById(widget.linkScoutId!);
          troopId = scout?.troopId ?? troopId;
        }
        g = await repo.create(
          name: _fullName, troopId: troopId, gender: _gender,
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        );