import 'package:flutter/material.dart';
import '../../core/wood_grain_background.dart';
import 'report_service.dart';
import 'report_exporter.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  List<EventReportRecord>? _records;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final records = await ReportService.generateEventRecords();
      setState(() { _records = records; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _exportCsv() async {
    if (_records == null) return;
    setState(() => _isExporting = true);
    try {
      await ReportExporter.exportCsv(context, _records!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('CSV出力に失敗しました: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('レポート出力')),
      body: Stack(children: [
        const WoodGrainBackground(),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('エラー: $_error',
                    style: const TextStyle(color: Colors.red)))
                : _buildContent(cs),
      ]),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    final records = _records!;
    final troopName = records.isNotEmpty ? records.first.troopName : '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined, size: 48, color: cs.primary),
            const SizedBox(height: 12),
            Text(troopName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              records.isEmpty
                  ? 'データがありません'
                  : '確定済みイベント ${records.length} 件',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'イベント情報＋参加者統計を1行1イベントで出力します',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (_isExporting)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.table_rows_outlined),
                  label: const Text('CSV で出力'),
                  onPressed: records.isEmpty ? null : _exportCsv,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
