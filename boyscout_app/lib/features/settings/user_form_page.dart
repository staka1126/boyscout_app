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
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _gender = 'male';
  UserRole _role = UserRole.leader;
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
      _lastNameCtrl.text = u.name.contains(' ') ? u.name.split(' ').first : u.name;
      _firstNameCtrl.text = u.name.contains(' ') ? u.name.split(' ').skip(1).join(' ') : '';
      _emailCtrl.text = u.email;
      _phoneCtrl.text = u.phone ?? '';
      _gender = u.gender;
      _role = u.role;
      _isRetired = u.isRetired;
      setState(() {});
    }
  }

  bool get _isDirty {
    if (_original == null) {
      return _lastNameCtrl.text.trim().isNotEmpty || _firstNameCtrl.text.trim().isNotEmpty;
    }
    final origLast = _original!.name.contains(' ') ? _original!.name.split(' ').first : _original!.name;
    final origFirst = _original!.name.contains(' ') ? _original!.name.split(' ').skip(1).join(' ') : '';
    return _lastNameCtrl.text.trim() != origLast ||
        _firstNameCtrl.text.trim() != origFirst ||
        _emailCtrl.text.trim() != _original!.email ||
        _phoneCtrl.text.trim() != (_original!.phone ?? '') ||
        _gender != _original!.gender ||
        _role != _original!.role ||
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

  Future<void> _onBack() async {
    if (await _confirmDiscard() && mounted) context.pop();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) return;
    setState(() => _saving = true);
    final repo = ref.read(userRepositoryProvider);
    final email = _emailCtrl.text.trim();
    try {
      final existing = await repo.getByTroop(troopId);
      final duplicate = existing.where((u) => u.email == email && u.id != (_original?.id ?? '')).toList();
      if (duplicate.isNotEmpty) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (dlgCtx) => AlertDialog(
              title: const Text('登録できません'),
              content: Text('メールアドレス「$email」は既に登録されています。'),
              actions: [FilledButton(onPressed: () => Navigator.of(dlgCtx).pop(), child: const Text('OK'))],
            ),
          );
        }
        return;
      }
      if (_original == null) {
        await repo.create(
          troopId: troopId,
          name: '${_lastNameCtrl.text.trim()} ${_firstNameCtrl.text.trim()}',
          email: email, role: _role, gender: _gender,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        );
      } else {
        await repo.update(_original!.copyWith(
          name: '${_lastNameCtrl.text.trim()} ${_firstNameCtrl.text.trim()}',
          gender: _gender,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          role: _role, isRetired: _isRetired,
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
        appBar: AppBar(
          title: Text(widget.userId == null ? 'リーダー追加' : 'リーダー編集'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _onBack),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined),
          label: const Text('保存'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
              _RoleRadio(value: _role, onChanged: (v) => setState(() => _role = v!)),
              if (widget.userId != null) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _isRetired,
                  onChanged: (v) => setState(() => _isRetired = v),
                  title: const Text('引退'),
                  subtitle: const Text('引退したリーダーは出席者追加の対象外になります'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              const SizedBox(height: 16),
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

class _RoleRadio extends StatelessWidget {
  final UserRole value;
  final ValueChanged<UserRole?> onChanged;
  const _RoleRadio({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('種別', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      Row(children: [
        Radio<UserRole>(value: UserRole.leader, groupValue: value, onChanged: onChanged),
        const Text('隊長'),
        const SizedBox(width: 8),
        Radio<UserRole>(value: UserRole.assistantLeader, groupValue: value, onChanged: onChanged),
        const Text('副長'),
        const SizedBox(width: 8),
        Radio<UserRole>(value: UserRole.support, groupValue: value, onChanged: onChanged),
        const Text('補助者'),
      ]),
    ]);
  }
}
