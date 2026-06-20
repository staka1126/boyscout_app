          // 団名ヘッダー（currentTroopIdがある場合のみ表示）
          troopAsync.maybeWhen(
            data: (troop) {
              if (troop == null) return const SizedBox();
              final name = troop['name'] ?? '';
              final location = troop['location'];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Text(name.isNotEmpty ? name[0] : '?',
                      style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: location != null ? Text(location) : null,
                onTap: () => context.go('/settings/troop'),
              );
            },
            orElse: () => const SizedBox(),
          ),