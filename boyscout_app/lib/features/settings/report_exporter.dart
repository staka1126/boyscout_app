import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'report_service.dart';

class ReportExporter {
  static Future<void> exportCsv(
      BuildContext context, List<EventReportRecord> records) async {
    final buf = StringBuffer();

    // ヘッダー行
    buf.writeln(EventReportRecord.csvHeaders
        .map((h) => _escape(h))
        .join(','));

    // データ行
    for (final r in records) {
      buf.writeln(r.toCsvRow().map((v) => _escape(v)).join(','));
    }

    final troopName = records.isNotEmpty ? records.first.troopName : 'report';
    final fileName = '${troopName}_活動統計レポート.csv';
    final bytes = utf8.encode(buf.toString());

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      final dir = await _desktopSaveDir();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('保存しました: ${file.path}'),
          duration: const Duration(seconds: 5),
        ));
      }
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (context.mounted) {
        await Share.shareXFiles([XFile(file.path)], subject: fileName);
      }
    }
  }

  /// カンマ・改行・ダブルクォートを含むセルをクォートで囲む
  static String _escape(String value) {
    if (value.contains(',') || value.contains('\n') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static Future<Directory> _desktopSaveDir() async {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ?? '/tmp';
    for (final sub in ['Downloads', 'ダウンロード', 'Documents', 'ドキュメント']) {
      final dir = Directory('$home/$sub');
      if (await dir.exists()) return dir;
    }
    return Directory(home);
  }
}
