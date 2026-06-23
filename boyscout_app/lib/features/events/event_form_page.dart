import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../dashboard/dashboard_page.dart';
import '../events/events_page.dart';

class EventFormPage extends ConsumerStatefulWidget {
  final String? eventId;
  const EventFormPage({super.key, this.eventId});

  @override
  ConsumerState<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends ConsumerState<EventFormPage> {
  final _formKey = GlobalKey<FormState>();
  Event? _original;
  bool _loading = false;
  bool _saving = false;

  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _eventDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      _load();
    } else {
      _startTime = const TimeOfDay(hour: 9, minute: 30);
      _endTime = const TimeOfDay(hour: 12, minute: 0);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final e = await ref.read(eventRepositoryProvider).getById(widget.eventId!);
      if (e != null && mounted) {
        _original = e;
        _titleCtrl.text = e.title;
        _locationCtrl.text = e.location ?? '';
        _notesCtrl.text = e.notes ?? '';
        _eventDate = e.eventDate;
        if (e.startTime != null) {
          final parts = e.startTime!.split(':');
          _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
        if (e.endTime != null) {
          final parts = e.endTime!.split(':');
          _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('読み込み失敗: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('開催日を選択してください')));
      return;
    }
    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先に設定から団情報を登録してください')));
      return;
    }
    setState(() => _saving = true);
    try {
      final eventRepo = ref.read(eventRepositoryProvider);
      Event saved;
      if (_original == null) {
        saved = await eventRepo.create(
          troopId: troopId,
          title: _titleCtrl.text.trim(),
          eventType: EventType.other,
          eventDate: _eventDate!,
          location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
          startTime: _startTime != null ? _fmtTime(_startTime!) : null,
          endTime: _endTime != null ? _fmtTime(_endTime!) : null,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        try {
          final users = await ref.read(userRepositoryProvider).getByTroop(troopId);
          final scouts = await ref.read(scoutRepositoryProvider).getByTroop(troopId);
          await ref.read(attendanceRepositoryProvider).createDefaults(eventId: saved.id, users: users, scouts: scouts);

          // ビーバー・ビッグビーバー・仮入隊スカウトの保護者をデフォルト追加
          const guardianTargetCategories = [
            ScoutCategory.bigBeaver,
            ScoutCategory.beaver,
            ScoutCategory.provisional,
          ];
          final targetScouts = scouts.where((s) => guardianTargetCategories.contains(s.category));
          final guardianRepo = ref.read(guardianRepositoryProvider);
          final attendanceRepo = ref.read(attendanceRepositoryProvider);
          final addedGuardianIds = <String>{};
          for (final scout in targetScouts) {
            final guardians = await guardianRepo.getByScout(scout.id);
            for (final g in guardians) {
              if (addedGuardianIds.contains(g.id)) continue;
              addedGuardianIds.add(g.id);
              await attendanceRepo.add(Attendance(
                id: const Uuid().v4(),
                eventId: saved.id,
                memberType: MemberType.guardian,
                memberId: g.id,
                memberName: g.name,
                status: AttendanceStatus.pending,
                isDefault: true,
              ));
            }
          }
        } catch (e) {
          debugPrint('出席者自動生成エラー（無視）: $e');
        }
      } else {
        final updated = _original!.copyWith(
          title: _titleCtrl.text.trim(),
          eventDate: _eventDate!,
          location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
          startTime: _startTime != null ? _fmtTime(_startTime!) : null,
          endTime: _endTime != null ? _fmtTime(_endTime!) : null,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        await eventRepo.update(updated);
        saved = updated;
      }
      if (mounted) {
        ref.invalidate(dashboardProvider);
        ref.invalidate(eventsProvider);
        context.pop();
      }
    } catch (e, st) {
      debugPrint('イベント保存エラー: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失敗: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.eventId == null;
    final troopId = ref.watch(currentTroopIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'イベント追加' : 'イベント編集'),
      ),
      floatingActionButton: troopId != null ? FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_outlined),
        label: const Text('保存'),
      ) : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : troopId == null
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.warning_amber_outlined, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    const Text('先に団情報を登録してください'),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => context.go('/settings/troop'), child: const Text('団情報を登録する')),
                  ]),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(labelText: 'タイトル *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _eventDate ?? DateTime.now(),
                            firstDate: DateTime(2000), lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _eventDate = d);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: '開催日 *'),
                          child: Text(
                            _eventDate != null ? DateFormat('yyyy/MM/dd (E)', 'ja').format(_eventDate!) : '日付を選択',
                            style: TextStyle(color: _eventDate != null ? null : Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final t = await showTimePicker(
                                context: context, initialTime: _startTime ?? const TimeOfDay(hour: 10, minute: 0),
                              );
                              if (t != null) setState(() => _startTime = t);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: '開始時間'),
                              child: Text(_startTime != null ? _fmtTime(_startTime!) : '選択'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final t = await showTimePicker(
                                context: context, initialTime: _endTime ?? const TimeOfDay(hour: 12, minute: 0),
                              );
                              if (t != null) setState(() => _endTime = t);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: '終了時間'),
                              child: Text(_endTime != null ? _fmtTime(_endTime!) : '選択'),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationCtrl,
                        decoration: const InputDecoration(labelText: '場所', prefixIcon: Icon(Icons.place_outlined)),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesCtrl,
                        decoration: const InputDecoration(labelText: '備考'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                    ]),
                  ),
                ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }
}
