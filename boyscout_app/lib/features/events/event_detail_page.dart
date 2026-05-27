// ─── LeafBadgeEditor ─────────────────────────────────────────
class _LeafBadgeEditor extends ConsumerStatefulWidget {
  final Event event;
  final List<EventLeafBadge> existing;
  final WidgetRef ref;
  const _LeafBadgeEditor({required this.event, required this.existing, required this.ref});

  @override
  ConsumerState<_LeafBadgeEditor> createState() => _LeafBadgeEditorState();
}

class _LeafBadgeEditorState extends ConsumerState<_LeafBadgeEditor> {
  late Map<LeafBadgeType, bool> _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = {
      for (final t in LeafBadgeType.values)
        t: (widget.existing.where((b) => b.badgeType == t).firstOrNull?.count ?? 0) > 0,
    };
  }

  Future<void> _save() async {
    final repo = ref.read(eventRepositoryProvider);
    for (final t in LeafBadgeType.values) {
      final existing = widget.existing.where((b) => b.badgeType == t).firstOrNull;
      await repo.upsertLeafBadge(EventLeafBadge(
        id: existing?.id ?? _uuid.v4(),
        eventId: widget.event.id,
        badgeType: t,
        count: _enabled[t]! ? 1 : 0,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('木の葉章配布設定',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('配布する木の葉章をONにしてください',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          ...LeafBadgeType.values.map((t) {
            final on = _enabled[t]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => setState(() => _enabled[t] = !on),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: on ? t.color.withAlpha(30) : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: on ? t.color : cs.outline.withAlpha(80),
                      width: on ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: on ? t.color : cs.outline.withAlpha(80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(t.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                            color: on ? t.color : cs.onSurfaceVariant,
                          )),
                    ),
                    Switch(
                      value: on,
                      onChanged: (v) => setState(() => _enabled[t] = v),
                      activeColor: t.color,
                    ),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('保存する')),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}