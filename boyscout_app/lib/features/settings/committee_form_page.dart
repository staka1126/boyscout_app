import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';

class CommitteeFormPage extends ConsumerStatefulWidget {
  final String? memberId;
  const CommitteeFormPage({super.key, this.memberId});

  @override
  ConsumerState<CommitteeFormPage> createState() => _CommitteeFormPageState();
}

class _CommitteeFormPageState extends ConsumerState<CommitteeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _gender;
  CommitteeCategory _category = CommitteeCategory.committee;
  bool _isRetired = false;
  CommitteeMember? _original;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.memberId != null) _load();
  }

  Future<void> _load() async {
    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) return;
    final all = await ref.read(committeeRepositoryProvider).getByTroop(troopId);
    final m = all.where((x) => x.id == widget.memberId).firstOrNull;
    if (m != null && mounted) {
      _original = m;
      _lastNameCtrl.text = m.name.contains(' ') ? m.name.split(' ').first : m.name;
      _firstNameCtrl.text = m.name.contains(' ') ? m.name.split(' ').skip(1).join(' ') : '';
      _emailCtrl.text = m.email ?? '';
      _phoneCtrl.text = m.phone ?? '';
      _gender = m.gender;
      _category = m.category;
      _isRetired = m.isRetired;
      setState(() {});
    }
  }

  String get _fullName => '${_lastNameCtrl.text.trim()} ${_firstNameCtrl.text.trim()}';

  bool get _isDirty {
    if (_original == null) {
      return _lastNameCtrl.text.trim().isNotEmpty || _firstNameCtrl.text.trim().isNotEmpty;
    }
    final origLast = _original!.name.contains(' ') ? _original!.name.split(' ').first : _original!.name;
    final origFirst = _original!.name.contains(' ') ? _original!.name.split(' ').skip(1).join(' ') : '';
    return _lastNameCtrl.text.trim() != origLast ||
        _firstNameCtrl.text.trim() != origFirst ||
        _emailCtrl.text.trim() != (_original!.email ?? '') ||
        _phoneCtrl.text.trim() != (_original!.phone ?? '') ||
        _gender != _original!.gender ||
        _category != _original!.category ||
        _isRetired != _original!.isRetired;
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('編集内容を破棄しますか？'),
            content: const Text('保存されていない変更があります。'),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('編集を続ける')),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.of(c).pop(true), child: const Text('破棄する')),
            ],
          ),
        ) ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(committeeRepositoryProvider);
      if (_original == null) {
        await repo.create(
          troopId: troopId, name: _fullName, category: _category, gender: _gender,
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        );
      } else {
        await repo.update(_original!.copyWith(
          name: _fullName, category: _category, gender: _gender,
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          isRetired: _isRetired,
        ));
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失敗: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.memberId == null ? '団委員追加' : '団委員編集')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
              DropdownButtonFormField<CommitteeCategory>(
                value: _category,
                decoration: const InputDecoration(labelText: '分類 *'),
                items: CommitteeCategory.values
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: '電話番号'),
                keyboardType: TextInputType.phone,
              ),
              if (widget.memberId != null) ...[
                const SizedBox(height: 4),
                SwitchListTile(
                  value: _isRetired,
                  onChanged: (v) => setState(() => _isRetired = v),
                  title: const Text('引退'),
                  subtitle: const Text('引退した団委員は出席者追加の対象外になります'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('保存する'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
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
      Text('性別', style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
