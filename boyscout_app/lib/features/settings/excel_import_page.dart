import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/import/excel_import_service.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/event_stats_service.dart';
import '../../data/providers/app_state_provider.dart';
import '../../data/sync/sync_service.dart';
import '../../core/supabase_config.dart';
import '../dashboard/dashboard_page.dart';
import '../badges/badges_page.dart';

class ExcelImportPage extends ConsumerStatefulWidget {
  const ExcelImportPage({super.key});

  @override
  ConsumerState<ExcelImportPage> createState() => _ExcelImportPageState();
}

class _ExcelImportPageState extends ConsumerState<ExcelImportPage> {
  bool _isLoading = false;
  String? _fileName;
  ImportResult? _result;
  String? _error;

  Future<void> _pickAndImport() async {
    final troopId = ref.read(currentTroopIdProvider);
    if (troopId == null) {
      setState(() => _error = '団IDが取得できません。ログインし直してください。');
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'ファイルの読み込みに失敗しました。');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('インポートの確認'),
        content: Text(
          '「${file.name}」をインポートします。\n\n'
          '現在のスカウト・リーダー・活動・出欠データはすべて上書きされます。\n\n'
          'この操作は取り消せません。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('インポート'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() { _isLoading = true; _fileName = file.name; _result = null; _error = null; });

    try {
      final db = await DatabaseHelper.instance.database;
      final result = await ExcelImportService.instance.importFromBytes(
        bytes: bytes,
        troopId: troopId,
        db: db,
      );

      // Supabase同期
      try {
        await _clearSupabaseData(troopId);
        await SyncService.instance.syncToSupabase(troopId);
        await SyncService.instance.syncFromSupabase(troopId);
      } catch (e) {
        debugPrint('Supabase sync error: $e');
        if (mounted) setState(() => _error = 'Supabase同期エラー: $e');
      }

      // 確定済みイベントの参加統計を現在のデータで再計算
      try {
        await EventStatsService.instance.rebuildAllForTroop(troopId);
      } catch (e) {
        debugPrint('EventStats rebuild error: $e');
      }

      if (mounted) {
        setState(() { _result = result; _isLoading = false; });
        ref.invalidate(dashboardProvider);
        ref.invalidate(badgesProvider);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Excelインポート')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline, color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('インポートについて', style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary)),
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                      '「BVS隊務管理」Excelファイル（.xlsx）を読み込み、'
                      'スカウト・リーダー・活動・出欠・表彰データを一括登録します。\n\n'
                      '⚠️ 既存のデータはすべて上書きされます。',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _isLoading ? null : _pickAndImport,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file),
              label: Text(_isLoading ? 'インポート中...' : 'Excelファイルを選択してインポート'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),

            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Text('ファイル: $_fileName',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: cs.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: TextStyle(color: cs.onErrorContainer, fontSize: 13))),
                  ]),
                ),
              ),
            ],

            if (_result != null) ...[
              const SizedBox(height: 16),
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.check_circle, color: cs.primary),
                        const SizedBox(width: 8),
                        Text('インポート完了',
                            style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
                      ]),
                      const SizedBox(height: 12),
                      _row('スカウト', _result!.scouts),
                      _row('リーダー', _result!.leaders),
                      _row('団委員ほか', _result!.committees),
                      _row('保護者', _result!.guardians),
                      _row('活動', _result!.events),
                      _row('出欠レコード', _result!.attendances),
                      _row('小枝章授与履歴', _result!.twigHistories),
                      if (_result!.warnings.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(),
                        Text('⚠️ スキップ項目 (${_result!.warnings.length}件)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        ...(_result!.warnings.map((w) => Text('• $w',
                            style: const TextStyle(fontSize: 11)))),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _clearSupabaseData(String troopId) async {
    final client = SupabaseConfig.client;
    final eventIds = (await client.from('events').select('id').eq('troop_id', troopId) as List)
        .map((r) => r['id'] as String).toList();
    if (eventIds.isNotEmpty) {
      await client.from('attendances').delete().inFilter('event_id', eventIds);
      await client.from('event_leaf_badges').delete().inFilter('event_id', eventIds);
    }
    final scoutIds = (await client.from('scouts').select('id').eq('troop_id', troopId) as List)
        .map((r) => r['id'] as String).toList();
    if (scoutIds.isNotEmpty) {
      await client.from('scout_guardians').delete().inFilter('scout_id', scoutIds);
    }
    await client.from('events').delete().eq('troop_id', troopId);
    await client.from('scouts').delete().eq('troop_id', troopId);
    await client.from('leaders').delete().eq('troop_id', troopId);
    await client.from('committee_members').delete().eq('troop_id', troopId);
    if (scoutIds.isNotEmpty) {
      await client.from('guardians').delete().eq('troop_id', troopId);
    }
  }

  Widget _row(String label, int count) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text('$count 件', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
