import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';
import '../../core/supabase_config.dart';
import '../../core/wbgt_prefecture_master.dart';

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
  String? _selectedPrefCode; // 熱中症アラート：選択中の都道府県
  String? _selectedPointCode; // 熱中症アラート：選択中の地点

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) return;

    try {
      final troopData = await SupabaseConfig.client
          .from('troops')
          .select('id, name, location, contact, prefecture_code, point_code')
          .eq('id', troopId)
          .maybeSingle();

      if (troopData != null && mounted) {
        final troop = await ref.read(troopRepositoryProvider).upsert(
          id: troopData['id'] as String,
          name: troopData['name'] as String,
          location: troopData['location'] as String?,
          contact: troopData['contact'] as String?,
          prefectureCode: troopData['prefecture_code'] as String?,
          pointCode: troopData['point_code'] as String?,
        );
        _existing = troop;
        _nameCtrl.text = troop.name;
        _locationCtrl.text = troop.location ?? '';
        _contactCtrl.text = troop.contact ?? '';
        _selectedPrefCode = troop.prefectureCode;
        _selectedPointCode = troop.pointCode;
        setState(() {});
      }
    } catch (_) {
      final troop = await ref.read(troopRepositoryProvider).getFirst();
      if (troop != null && mounted) {
        _existing = troop;
        _nameCtrl.text = troop.name;
        _locationCtrl.text = troop.location ?? '';
        _contactCtrl.text = troop.contact ?? '';
        _selectedPrefCode = troop.prefectureCode;
        _selectedPointCode = troop.pointCode;
        setState(() {});
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // ① ローカルDBに保存
      final troop = await ref.read(troopRepositoryProvider).upsert(
        id: _existing?.id,
        name: _nameCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        contact: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
        prefectureCode: _selectedPrefCode,
        pointCode: _selectedPointCode,
      );

      // ② Supabase に同期
      await _syncToSupabase(troop);

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失敗: $e'), duration: const Duration(seconds: 8)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Supabase の troops・troop_members テーブルに同期する
  /// INSERT を試みて、Primary Key 重複なら UPDATE にフォールバック
  Future<void> _syncToSupabase(Troop troop) async {
    final user = SupabaseConfig.currentUser;
    if (user == null) return;

    final client = SupabaseConfig.client;

    // troops: まずUPDATEを試みる（既存行があれば更新）
    final updated = await client
        .from('troops')
        .update({
          'name': troop.name,
          'prefecture_code': troop.prefectureCode,
          'point_code': troop.pointCode,
        })
        .eq('id', troop.id)
        .eq('created_by', user.id)
        .select();

    // UPDATEで0行だった場合はINSERT
    if ((updated as List).isEmpty) {
      await client.from('troops').insert({
        'id': troop.id,
        'name': troop.name,
        'prefecture_code': troop.prefectureCode,
        'point_code': troop.pointCode,
        'created_by': user.id,
      });
    }

    // troop_members: UPDATEを試みる
    final memberUpdated = await client
        .from('troop_members')
        .update({'troop_id': troop.id, 'role': 'admin'})
        .eq('user_id', user.id)
        .select();

    // 0行だった場合はINSERT
    if ((memberUpdated as List).isEmpty) {
      await client.from('troop_members').insert({
        'user_id': user.id,
        'troop_id': troop.id,
        'role': 'admin',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('団情報'),
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
            const SizedBox(height: 24),
            Text('熱中症アラートの地域設定',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'ダッシュボードに熱中症警戒度を表示するための都道府県・地点を選択してください（任意）。',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedPrefCode,
              decoration: const InputDecoration(labelText: '都道府県', prefixIcon: Icon(Icons.map_outlined)),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('未設定')),
                ...wbgtPrefectureMaster.map(
                  (p) => DropdownMenuItem<String>(value: p.prefCode, child: Text(p.prefName)),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedPrefCode = v;
                  // 都道府県を変えたら地点はデフォルト（先頭）にリセット
                  final pref = wbgtPrefectureMaster.where((e) => e.prefCode == v);
                  _selectedPointCode = pref.isEmpty ? null : pref.first.points.first.pointCode;
                });
              },
            ),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final pref = wbgtPrefectureMaster.where((e) => e.prefCode == _selectedPrefCode);
              final points = pref.isEmpty ? const <WbgtPoint>[] : pref.first.points;
              final enabled = points.length > 1;
              return DropdownButtonFormField<String>(
                value: _selectedPointCode,
                decoration: const InputDecoration(labelText: '地点', prefixIcon: Icon(Icons.location_on_outlined)),
                items: points
                    .map((pt) => DropdownMenuItem<String>(value: pt.pointCode, child: Text(pt.pointName)))
                    .toList(),
                onChanged: enabled ? (v) => setState(() => _selectedPointCode = v) : null,
              );
            }),
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
