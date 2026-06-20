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

  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _enrollmentYearCtrl = TextEditingController();
  final _offsetCtrl = TextEditingController();
  String? _gender = 'male';
  ScoutCategory _category = ScoutCategory.beaver;
  DateTime? _joinedAt;
  DateTime? _birthday;
  List<AllergyType> _allergies = [];
  final _specialNotesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.scoutId != null) {
      _load();
    } else {
      _gradeCtrl.text = '小1';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await ref.read(scoutRepositoryProvider).getById(widget.scoutId!);
    if (s != null && mounted) {
      _original = s;
      _lastNameCtrl.text = s.name.contains(' ') ? s.name.split(' ').first : s.name;
      _firstNameCtrl.text = s.name.contains(' ') ? s.name.split(' ').skip(1).join(' ') : '';
      _gradeCtrl.text = s.grade ?? '';
      _enrollmentYearCtrl.text = s.enrollmentYear?.toString() ?? '';
      _offsetCtrl.text = s.leafBadgeOffset.toString();
      _gender = s.gender;
      _category = s.category;
      _joinedAt = s.joinedAt;
      _birthday = s.birthday;
      _allergies = List.from(s.allergies);
      _specialNotesCtrl.text = s.specialNotes ?? '';
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _isDirty {
    if (_original == null) {
      return _lastNameCtrl.text.trim().isNotEmpty || _firstNameCtrl.text.trim().isNotEmpty;
    }
    final origLast = _original!.name.contains(' ') ? _original!.name.split(' ').first : _original!.name;
    final origFirst = _original!.name.contains(' ') ? _original!.name.split(' ').skip(1).join(' ') : '';
    return _lastNameCtrl.text.trim() != origLast ||
        _firstNameCtrl.text.trim() != origFirst ||
        _gender != _original!.gender ||
        _gradeCtrl.text != (_original!.grade ?? '') ||
        _category != _original!.category ||
        _joinedAt != _original!.joinedAt ||
        _birthday != _original!.birthday ||
        _allergies.length != _original!.allergies.length ||
        _specialNotesCtrl.text.trim() != (_original!.specialNotes ?? '');
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dlgCtx) => AlertDialog(
            title: const Text('編集内容を破棄しますか？'),
            content: const Text('保存されていない変更があります。'),
            actions: [
              TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('編集を続ける')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(dlgCtx).pop(true),
                child: const Text('破棄する'),
              ),
            ],
          ),
        ) ?? false;
  }

  Future<void> _onBack() async {
    if (await _confirmDiscard() && mounted) context.pop();
  }

  String get _fullName => '${_lastNameCtrl.text.trim()} ${_firstNameCtrl.text.trim()}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先に団情報を登録してください')));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(scoutRepositoryProvider);
    try {
      if (_original == null) {
        await repo.create(
          troopId: troopId, name: _fullName, category: _category, gender: _gender,
          grade: _gradeCtrl.text.trim().isEmpty ? null : _gradeCtrl.text.trim(),
          enrollmentYear: int.tryParse(_enrollmentYearCtrl.text),
          joinedAt: _joinedAt, birthday: _birthday, allergies: _allergies,
          specialNotes: _specialNotesCtrl.text.trim().isEmpty ? null : _specialNotesCtrl.text.trim(),
          leafBadgeOffset: int.tryParse(_offsetCtrl.text) ?? 0,
        );
      } else {
        await repo.update(_original!.copyWith(
          name: _fullName, category: _category, gender: _gender,
          grade: _gradeCtrl.text.trim().isEmpty ? null : _gradeCtrl.text.trim(),
          enrollmentYear: int.tryParse(_enrollmentYearCtrl.text),
          joinedAt: _joinedAt, birthday: _birthday, allergies: _allergies,
          specialNotes: _specialNotesCtrl.text.trim().isEmpty ? null : _specialNotesCtrl.text.trim(),
          leafBadgeOffset: int.tryParse(_offsetCtrl.text) ?? 0,
        ));
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.scoutId == null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isNew ? 'スカウト追加' : 'スカウト編集'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _onBack),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined),
          label: const Text('保存'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _section('基本情報'),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: _lastNameCtrl,
                        decoration: const InputDecoration(labelText: '氏 *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(
                        controller: _firstNameCtrl,
                        decoration: const InputDecoration(labelText: '名 *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
                      )),
                    ]),
                    const SizedBox(height: 12),
                    _GenderRadio(value: _gender, onChanged: (v) => setState(() => _gender = v)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: () {
                        const valid = ['小2', '小1', '年長', '年中', '年少', '未就学', 'その他'];
                        final v = _gradeCtrl.text.isEmpty ? '小1' : _gradeCtrl.text;
                        return valid.contains(v) ? v : 'その他';
                      }(),
                      decoration: const InputDecoration(labelText: '学年'),
                      items: const [
                        DropdownMenuItem(value: '小2', child: Text('小2')),
                        DropdownMenuItem(value: '小1', child: Text('小1')),
                        DropdownMenuItem(value: '年長', child: Text('年長')),
                        DropdownMenuItem(value: '年中', child: Text('年中')),
                        DropdownMenuItem(value: '年少', child: Text('年少')),
                        DropdownMenuItem(value: '未就学', child: Text('未就学')),
                        DropdownMenuItem(value: 'その他', child: Text('その他')),
                      ],
                      onChanged: (v) => setState(() => _gradeCtrl.text = v ?? ''),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _birthday ?? DateTime(DateTime.now().year - 5),
                          firstDate: DateTime(2000), lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _birthday = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: '誕生日'),
                        child: Row(children: [
                          Expanded(child: Text(
                            _birthday != null ? DateFormat('yyyy/MM/dd').format(_birthday!) : '選択してください',
                            style: TextStyle(color: _birthday != null ? null : Theme.of(context).colorScheme.onSurfaceVariant),
                          )),
                          if (_birthday != null)
                            GestureDetector(
                              onTap: () => setState(() => _birthday = null),
                              child: Icon(Icons.clear, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _section('分類・入隊情報'),
                    DropdownButtonFormField<ScoutCategory>(
                      value: _category,
                      decoration: const InputDecoration(labelText: '分類 *'),
                      items: ScoutCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _enrollmentYearCtrl,
                      decoration: const InputDecoration(labelText: '小学校入学年度'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _joinedAt ?? DateTime.now(),
                          firstDate: DateTime(2000), lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _joinedAt = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: '入隊日'),
                        child: Text(
                          _joinedAt != null ? DateFormat('yyyy/MM/dd').format(_joinedAt!) : '選択してください',
                          style: TextStyle(color: _joinedAt != null ? null : Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _section('木の葉章補正'),
                    TextFormField(
                      controller: _offsetCtrl,
                      decoration: const InputDecoration(
                        labelText: '入隊前の取得枚数',
                        helperText: '入隊時にそれまでの取得枚数を入力してください\nこの数値で補正したうえで小枝賞を計算します',
                        helperMaxLines: 2,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    _section('アレルギー・特記'),
                    Text('アレルギー（該当するものを選択）',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 4,
                      children: AllergyType.values.map((a) {
                        final selected = _allergies.contains(a);
                        return FilterChip(
                          label: Text(a.label), selected: selected,
                          onSelected: (v) => setState(() { if (v) { _allergies.add(a); } else { _allergies.remove(a); } }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _specialNotesCtrl,
                      decoration: const InputDecoration(labelText: '特記事項', helperText: 'アレルギーの詳細やその他特記事項'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _gradeCtrl.dispose();
    _enrollmentYearCtrl.dispose();
    _offsetCtrl.dispose();
    _specialNotesCtrl.dispose();
    super.dispose();
  }
}

class _GenderRadio extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _GenderRadio({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('性別', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      Row(children: [
        Radio<String>(value: 'male', groupValue: value, onChanged: onChanged),
        const Text('男性'),
        const SizedBox(width: 16),
        Radio<String>(value: 'female', groupValue: value, onChanged: onChanged),
        const Text('女性'),
      ]),
    ]);
  }
}
