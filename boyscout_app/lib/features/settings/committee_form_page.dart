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
  final _nameCtrl = TextEditingController();
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
    final all =
        await ref.read(committeeRepositoryProvider).getByTroop(troopId);
    final m = all.where((x) => x.id == widget.memberId).firstOrNull;
    if (m != null && mounted) {
      _original = m;
      _nameCtrl.text = m.name;
      _emailCtrl.text = m.email ?? '';
      _phoneCtrl.text = m.phone ?? '';
      _gender = m.gender;
      _category = m.category;
      _isRetired = m.isRetired;
      setState(() {});
    }
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
          troopId: troopId,
          name: _nameCtrl.text.trim(),
          category: _category,
          gender: _gender,
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        );
      } else {
        await repo.update(_original!.copyWith(
          name: _nameCtrl.text.trim(),
          category: _category,
          gender: _gender,
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          isRetired: _isRetired,
        ));
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.memberId == null ? '団委員追加' : '団委員編集')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
            DropdownButtonFormField<CommitteeCategory>(
              value: _category,
              decoration: const InputDecoration(labelText: '分類 *'),
              items: CommitteeCategory.values
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c.label)))
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
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('保存する'),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }
}
