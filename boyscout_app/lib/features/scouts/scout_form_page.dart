import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';

class ScoutFormPage extends ConsumerStatefulWidget {
  final String? scoutId;
  const ScoutFormPage({super.key, this.scoutId});

  @override
  ConsumerState<ScoutFormPage> createState() => _ScoutFormPageState();
}

class _ScoutFormPageState extends ConsumerState<ScoutFormPage> {
  final _formKey = GlobalKey<FormState>();
  Scout? _original;
  bool _loading = false;
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _enrollmentYearCtrl = TextEditingController();
  final _offsetCtrl = TextEditingController();
  String? _gender;
  ScoutCategory _category = ScoutCategory.beaver;
  DateTime? _joinedAt;

  @override
  void initState() {
    super.initState();
    if (widget.scoutId != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await ref.read(scoutRepositoryProvider).getById(widget.scoutId!);
    if (s != null && mounted) {
      _original = s;
      _nameCtrl.text = s.name;
      _gradeCtrl.text = s.grade ?? '';
      _enrollmentYearCtrl.text = s.enrollmentYear?.toString() ?? '';
      _offsetCtrl.text = s.leafBadgeOffset.toString();
      _gender = s.gender;
      _category = s.category;
      _joinedAt = s.joinedAt;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('先に団情報を登録してください')));
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(scoutRepositoryProvider);

    try {
      if (_original == null) {
        await repo.create(
          troopId: troopId,
          name: _nameCtrl.text.trim(),
          category: _category,
          gender: _gender,
          grade: _gradeCtrl.text.trim().isEmpty ? null : _gradeCtrl.text.trim(),
          enrollmentYear: int.tryParse(_enrollmentYearCtrl.text),
          joinedAt: _joinedAt,
          leafBadgeOffset: int.tryParse(_offsetCtrl.text) ?? 0,
        );
      } else {
        await repo.update(_original!.copyWith(
          name: _nameCtrl.text.trim(),
          category: _category,
          gender: _gender,
          grade: _gradeCtrl.text.trim().isEmpty ? null : _gradeCtrl.text.trim(),
          enrollmentYear: int.tryParse(_enrollmentYearCtrl.text),
          joinedAt: _joinedAt,
          leafBadgeOffset: int.tryParse(_offsetCtrl.text) ?? 0,
        ));
      }
      if (mounted) context.pop(); // push で来たので pop で戻る
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.scoutId == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'スカウト追加' : 'スカウト編集')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section('基本情報'),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: '氏名 *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '必須です' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: '性別'),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('男性')),
                        DropdownMenuItem(value: 'female', child: Text('女性')),
                        DropdownMenuItem(value: 'other', child: Text('その他')),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _gradeCtrl,
                      decoration: const InputDecoration(labelText: '学年'),
                    ),
                    const SizedBox(height: 24),
                    _section('分類・入隊情報'),
                    DropdownButtonFormField<ScoutCategory>(
                      value: _category,
                      decoration: const InputDecoration(labelText: '分類 *'),
                      items: ScoutCategory.values
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c.label)))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _enrollmentYearCtrl,
                      decoration:
                          const InputDecoration(labelText: '小学校入学年度'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _joinedAt ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _joinedAt = d);
                      },
                      child: InputDecorator(
                        decoration:
                            const InputDecoration(labelText: '入隊日'),
                        child: Text(
                          _joinedAt != null
                              ? DateFormat('yyyy/MM/dd').format(_joinedAt!)
                              : '選択してください',
                          style: TextStyle(
                              color: _joinedAt != null
                                  ? null
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _section('木の葉章'),
                    TextFormField(
                      controller: _offsetCtrl,
                      decoration: const InputDecoration(
                        labelText: '入隊時補正枚数',
                        helperText: '入隊前に取得済みの木の葉章枚数',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : Text(isNew ? '追加する' : '保存する'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gradeCtrl.dispose();
    _enrollmentYearCtrl.dispose();
    _offsetCtrl.dispose();
    super.dispose();
  }
}
