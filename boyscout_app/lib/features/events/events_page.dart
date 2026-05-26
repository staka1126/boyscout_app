import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';

// ─── Provider ────────────────────────────────────────────────
final _eventsProvider = FutureProvider<List<Event>>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return [];
  return ref.read(eventRepositoryProvider).getByTroop(troopId);
});

// ─── EventsPage ──────────────────────────────────────────────
class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  EventStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_eventsProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('イベント'),
        actions: [
          PopupMenuButton<EventStatus?>(
            icon: Icon(
              Icons.filter_list,
              color: _filterStatus != null
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onSelected: (v) => setState(() => _filterStatus = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('すべて')),
              ...EventStatus.values.map((s) =>
                  PopupMenuItem(value: s, child: Text(s.label))),
            ],
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (events) {
          final filtered = _filterStatus == null
              ? events
              : events.where((e) => e.status == _filterStatus).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_outlined,
                      size: 48, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 8),
                  const Text('イベントがありません'),
                  const SizedBox(height: 12),
                  if (user?.role.canEdit ?? false)
                    FilledButton.icon(
                      onPressed: () => context.go('/events/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('イベントを追加'),
                    ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(_eventsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _EventCard(event: filtered[i]),
            ),
          );
        },
      ),
      floatingActionButton: (user?.role.canEdit ?? false)
          ? FloatingActionButton(
              onPressed: () => context.go('/events/new'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ─── EventCard ───────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final Event event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/events/${event.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // 日付
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                Text(DateFormat('d').format(event.eventDate),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer)),
                Text(DateFormat('MMM', 'ja').format(event.eventDate),
                    style: TextStyle(
                        fontSize: 11, color: cs.onPrimaryContainer)),
              ]),
            ),
            const SizedBox(width: 12),
            // 情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(event.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    _statusChip(context, event.status),
                  ]),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, children: [
                    _meta(context, Icons.category_outlined, event.eventType.label),
                    if (event.location != null)
                      _meta(context, Icons.place_outlined, event.location!),
                    if (event.startTime != null)
                      _meta(context, Icons.schedule_outlined,
                          '${event.startTime}${event.endTime != null ? " ~ ${event.endTime}" : ""}'),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ]),
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );

  Widget _statusChip(BuildContext context, EventStatus status) {
    final cs = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    switch (status) {
      case EventStatus.completed:
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
      case EventStatus.ongoing:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
      case EventStatus.cancelled:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
      default:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
