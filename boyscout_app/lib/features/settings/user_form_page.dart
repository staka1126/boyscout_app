import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';

class UserFormPage extends ConsumerStatefulWidget {
  final String? userId;
  const UserFormPage({super.key, this.userId});

  @override
  ConsumerState<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends ConsumerState<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _gender;
  UserRole _role = UserRole.assistantLeader;
  bool _isRetired = false;
  AppUser? _original;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) _load();
  }

  Future<void> _load() async {
    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) return;
    final users = await ref.read(userRepositoryProvider).getByTroop(troopId);
    final u = users.where((x) => x.id == widget.userId).firstOrNull;
    if (u != null && mounted) {
      _original = u;
      _nameCtrl.text = u.name;
      _emailCtrl.text = u.email;
      _phoneCtrl.text = u.phone ?? '';
      _gender = u.gender;
      _role = u.role;
      _isRetired = u.isRetired;
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) return;

    setState(() => _saving = true);

    final repo = ref.read(userRepositoryProvider);
    final email = _emailCtrl.text.trim();

    try {
      // メールアドレス重複チェック
      final existing = await repo.getByTroop(troopId);
      final duplicate = existing.where((u) =>
          u.email == email && u.id != (_original?.id ?? '')).toList();

      if (duplicate.isNotEmpty) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (dlgCtx) => AlertDialog(
              title: const Text('登録できません'),
              content: Text('メールアドレス「$email」は既に登録されています。'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dlgCtx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (_original == null) {
        await repo.create(
          troopId: troopId,
          name: _nameCtrl.text.trim(),
          email: email,
          role: _role,
          gender: _gender,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        );
      } else {
        await repo.update(_original!.copyWith(
          name: _nameCtrl.text.trim(),
          gender: _gender,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          role: _role,
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
      appBar: AppBar(title: Text(widget.userId == null ? 'リーダー追加' : 'リーダー編集')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '氏名 *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: '性別'),
              items: const [
                DropdownMenuItem(value: 'male',   child: Text('男性')),
                DropdownMenuItem(value: 'female', child: Text('女性')),
                DropdownMenuItem(value: 'other',  child: Text('その他')),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'メールアドレス *'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: '電話番号'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole>(
              value: _role,
              decoration: const InputDecoration(labelText: '種別 *'),
              items: UserRole.values
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                  .toList(),
              onChanged: (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 32),
            if (widget.userId != null) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                value: _isRetired,
                onChanged: (v) => setState(() => _isRetired = v),
                title: const Text('引退'),
                subtitle: const Text('引退したリーダーは出席者追加の対象外になります'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
            ],
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
