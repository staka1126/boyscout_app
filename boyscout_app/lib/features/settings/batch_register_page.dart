import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/import/batch_import_service.dart';
import '../../data/local/database_helper.dart';
import '../../data/providers/app_state_provider.dart';
import '../../data/sync/sync_service.dart';
import '../../core/supabase_config.dart';

class BatchRegisterPage extends ConsumerStatefulWidget {
  const BatchRegisterPage({super.key});

  @override
  ConsumerState<BatchRegisterPage> createState() => _BatchRegisterPageState();
}

class _BatchRegisterPageState extends ConsumerState<BatchRegisterPage> {
  bool _isLoading = false;
  String? _fileName;
  BatchImportResult? _result;
  String? _error;
  bool _showSkipped = false;

  // ── テンプレートをassetsからDL ──────────────────────────────
  Future<void> _downloadTemplate() async {
    try {
      // assetsに同梱済みのテンプレートを取得してファイル保存ダイアログへ渡す
      final ByteData data = await rootBundle.load(
          'assets/templates/batch_register_template.xlsx');
      final bytes = data.buffer.asUint8List();

      // FilePicker経由では保存ができないため、
      // ここでは共有 or 保存先ダイアログを呼ぶ（save_file方式）
      // Androidでは Downloads に書き出す
      await _saveTemplateFile(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('テンプレートの取得に失敗しました: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _saveTemplateFile(Uint8List bytes) async {
    const fileName = 'batch_register_template.xlsx';
    try {
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        // デスクトップ: Downloads フォルダに直接書き出す
        final dir = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('テンプレートを保存しました: ${file.path}'),
            action: SnackBarAction(label: '閉じる', onPressed: () {}),
          ));
        }
      } else {
        // Android / iOS: FilePicker のダイアログ
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'テンプレートの保存先を選択',
          fileName: fileName,
          bytes: bytes,
        );
        if (path != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('テンプレートを保存しました'),
            action: SnackBarAction(label: '閉じる', onPressed: () {}),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('保存に失敗しました: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  // ── Excelファイルを選択してインポート ─────────────────────────
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
        title: const Text('バッチ登録の確認'),
        content: Text(
          '「${file.name}」を読み込みます。\n\n'
          '既存のデータは変更されません。\n'
          '同じ名前のメンバーは重複登録をスキップします。',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('登録する')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _fileName = file.name;
      _result = null;
      _error = null;
      _showSkipped = false;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final result = await BatchImportService.instance.importFromBytes(
        bytes: bytes,
        troopId: troopId,
        db: db,
      );

      // Supabase へ追記同期
      if (SupabaseConfig.isSignedIn) {
        try {
          await SyncService.instance.syncToSupabase(troopId);
        } catch (e) {
          debugPrint('Supabase sync error: $e');
          if (mounted) {
            setState(() => _error = 'Supabase同期エラー（ローカルには保存済み）: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('バッチ登録')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── STEP 1: テンプレートDL ─────────────────────────
            _StepCard(
              step: '1',
              title: 'テンプレートをダウンロード',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Excelテンプレートに登録したいメンバーを記入してください。\n'
                    '「リーダー」「スカウト」「団委員ほか」「保護者」の4シートがあります。',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  // シート説明チップ
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: const [
                      _SheetChip(label: 'リーダー', icon: Icons.manage_accounts),
                      _SheetChip(label: 'スカウト', icon: Icons.child_care),
                      _SheetChip(label: '団委員ほか', icon: Icons.groups),
                      _SheetChip(label: '保護者', icon: Icons.family_restroom),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download),
                    label: const Text('テンプレートをダウンロード'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── STEP 2: 入力ルール ─────────────────────────────
            _StepCard(
              step: '2',
              title: 'テンプレートに記入',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ruleRow(cs, '1行目', '注意書き行（削除してください）'),
                  _ruleRow(cs, '2行目', 'ヘッダ行（変更不要）'),
                  _ruleRow(cs, '3行目〜', 'サンプル行を削除してから登録データを入力'),
                  const SizedBox(height: 8),
                  _noteCard(cs,
                      '同じ名前のメンバーが既に登録されている場合はスキップします。\n'
                      '既存データは変更されません。'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── STEP 3: インポート ─────────────────────────────
            _StepCard(
              step: '3',
              title: '記入済みファイルをインポート',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _pickAndImport,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_file),
                    label: Text(_isLoading ? '登録中...' : 'Excelファイルを選択して登録'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                  if (_fileName != null) ...[
                    const SizedBox(height: 6),
                    Text('ファイル: $_fileName',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                        textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),

            // ── エラー表示 ────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: cs.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: TextStyle(
                                color: cs.onErrorContainer, fontSize: 13))),
                  ]),
                ),
              ),
            ],

            // ── 結果表示 ──────────────────────────────────────
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
                        Text('登録完了',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                                fontSize: 15)),
                      ]),
                      const SizedBox(height: 12),
                      _resultRow('リーダー', _result!.leaders, cs),
                      _resultRow('スカウト', _result!.scouts, cs),
                      _resultRow('団委員ほか', _result!.committees, cs),
                      _resultRow('保護者', _result!.guardians, cs),
                      const Divider(height: 20),
                      _resultRow('合計登録', _result!.total, cs, bold: true),

                      // スキップ
                      if (_result!.skipped.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showSkipped = !_showSkipped),
                          child: Row(children: [
                            Icon(Icons.skip_next,
                                size: 16, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              'スキップ ${_result!.skipped.length} 件'
                              '（重複）',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant),
                            ),
                            Icon(
                              _showSkipped
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                          ]),
                        ),
                        if (_showSkipped)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _result!.skipped
                                  .map((s) => Text('• $s',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant)))
                                  .toList(),
                            ),
                          ),
                      ],

                      // 警告
                      if (_result!.warnings.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('⚠️ 注意 ${_result!.warnings.length} 件',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        ...(_result!.warnings.map((w) => Text('• $w',
                            style: const TextStyle(fontSize: 11)))),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _ruleRow(ColorScheme cs, String label, String desc) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 60,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary)),
            ),
            Expanded(
                child:
                    Text(desc, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );

  Widget _noteCard(ColorScheme cs, String text) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      );

  Widget _resultRow(String label, int count, ColorScheme cs,
      {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
            Text('$count 件',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: bold ? cs.primary : null)),
          ],
        ),
      );
}

// ── ステップカード ──────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final Widget child;

  const _StepCard({
    required this.step,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: cs.primary,
                child: Text(step,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

// ── シートチップ ────────────────────────────────────────────────
class _SheetChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SheetChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: cs.primary),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
