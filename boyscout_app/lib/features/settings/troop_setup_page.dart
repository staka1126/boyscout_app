import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';

class TroopSetupPage extends ConsumerStatefulWidget {
  const TroopSetupPage({super.key});

  @override
  ConsumerState<TroopSetupPage> createState() => _TroopSetupPageState();
}

class _TroopSetupPageState extends ConsumerState<TroopSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  Troop? _existing;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final troop = await ref.read(troopRepositoryProvider).getFirst();
    if (troop != null && mounted) {
      _existing = troop;
      _nameCtrl.text = troop.name;
      _locationCtrl.text = troop.location ?? '';
      _contactCtrl.text = troop.contact ?? '';
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final troop = await ref.read(troopRepositoryProvider).upsert(
        id: _existing?.id,
        name: _nameCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        contact: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('troop_id', troop.id);
      ref.read(currentTroopIdProvider.notifier).state = troop.id;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存しました')));
        if (_existing == null) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dlgCtx) => AlertDialog(
              title: const Text('団情報を登録しました'),
              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('次に以下を登録してください。'),
                const SizedBox(height: 16),
                _bulletRow('リーダーを１名以上登録'),
                const SizedBox(height: 6),
                _bulletRow('スカウトを１名以上登録'),
                const SizedBox(height: 12),
                Text('リーダー・スカウトが揃うとイベントを作成できます。',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
              actions: [
                FilledButton(onPressed: () => Navigator.of(dlgCtx).pop(), child: const Text('わかりました')),
              ],
            ),
          );
          if (mounted) context.go('/dashboard');
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失敗: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('団情報'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(icon: const Icon(Icons.save_outlined), tooltip: '保存', onPressed: _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '団名 *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(labelText: '所在地', prefixIcon: Icon(Icons.place_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactCtrl,
              decoration: const InputDecoration(labelText: '連絡先', prefixIcon: Icon(Icons.phone_outlined)),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }
}

Widget _bulletRow(String text) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text('・ ', style: TextStyle(fontWeight: FontWeight.w600)),
    Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
  ],
);
