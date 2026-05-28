      case _AddTab.committee:
        return FutureBuilder<List<CommitteeMember>>(
          future: _loadCommittee(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const Text('追加できる団委員はいません',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  _otherForm(),
                ]),
              );
            }
            return ListView(controller: controller, children: [
              ...snap.data!.map((c) => ListTile(
                  title: Text(c.name), subtitle: Text(c.category.label),
                  trailing: const Icon(Icons.add),
                  onTap: () => _add(MemberType.committee, c.id, c.name))),
              const Divider(),
              Padding(padding: const EdgeInsets.all(16), child: _otherForm()),
            ]);
          });