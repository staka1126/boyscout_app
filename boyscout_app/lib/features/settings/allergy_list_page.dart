import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/wood_grain_background.dart';
import '../../core/constants/app_constants.dart';

class AllergyListPage extends ConsumerWidget {
  const AllergyListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final troopId = ref.watch(currentTroopIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('アレルギー情報')),
      body: Stack(children: [
        const WoodGrainBackground(),
        troopId == null
            ? const Center(child: Text('先に団情報を登録してください'))
            : FutureBuilder<List<Scout>>(
                future: ref.read(scoutRepositoryProvider).getByTroop(troopId),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final scouts = snap.data!
                      .where((s) => s.isActive && s.allergies.isNotEmpty)
                      .toList();

                  if (scouts.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                          SizedBox(height: 8),
                          Text('アレルギーのあるスカウトはいません'),
                        ],
                      ),
                    );
                  }

                  final Map<AllergyType, List<Scout>> grouped = {};
                  for (final type in AllergyType.values) {
                    final matched = scouts.where((s) => s.allergies.contains(type)).toList()
                      ..sort((a, b) => a.name.compareTo(b.name));
                    if (matched.isNotEmpty) grouped[type] = matched;
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _summaryCard(context, scouts),
                      const SizedBox(height: 16),
                      ...grouped.entries.map((entry) =>
                          _AllergenSection(type: entry.key, scouts: entry.value)),
                    ],
                  );
                },
              ),
      ]),
    );
  }

  Widget _summaryCard(BuildContext context, List<Scout> scouts) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.errorContainer.withAlpha(80),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.warning_amber_outlined, color: cs.error, size: 18),
            const SizedBox(width: 6),
            Text('アレルギーあり ${scouts.length}名',
                style: TextStyle(fontWeight: FontWeight.w700, color: cs.error)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 4,
            children: scouts.map((s) => Chip(
              label: Text(s.name, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              backgroundColor: cs.errorContainer,
              side: BorderSide.none,
            )).toList(),
          ),
        ]),
      ),
    );
  }
}

class _AllergenSection extends StatelessWidget {
  final AllergyType type;
  final List<Scout> scouts;
  const _AllergenSection({required this.type, required this.scouts});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                    color: cs.error, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(type.label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${scouts.length}名',
                    style: TextStyle(fontSize: 11, color: cs.onErrorContainer,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 10),
            ...scouts.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primaryContainer,
                  child: Text(s.name.isNotEmpty ? s.name[0] : '?',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (s.specialNotes != null)
                      Text(s.specialNotes!,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
                Text(s.category.label,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ]),
            )),
          ]),
        ),
      ),
    );
  }
}
