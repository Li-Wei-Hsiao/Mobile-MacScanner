import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/scan_repository.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/audio_service.dart';

class ScanUseCase {
  final ScanRepository repo;
  final AudioService audio;
  final FileService _fileService = FileService();

  ScanUseCase({required this.repo, required this.audio});

  Future<void> processCodeForFile(String mac, String prefix, int fileId) async {
    final suffix = mac.substring(6);
    await repo.addRecord(fileId, mac, suffix);
    await audio.playSuccess();
  }

  /// 匯出指定檔案的 CSV：依 MAC 升冪排序，No 欄位從 1～N
  Future<File> exportCsv(int fileId, String fileName) async {
    // 1. 取出並排序
    final records = await repo.fetchByFile(fileId);
    records.sort((a, b) => a.mac.compareTo(b.mac));

    // 2. 組 CSV 字串
    final csv = StringBuffer()..writeln('No,MAC,Suffix,Timestamp,Note');
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      final no = i + 1;
      final ts = DateTime.fromMillisecondsSinceEpoch(r.timestamp).toIso8601String();
      String esc(String v) => v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
      csv.writeln('$no,${esc(r.mac)},${esc(r.suffix)},${esc(ts)},${esc(r.note ?? '')}');
    }

    // 3. 選擇匯出路徑
    final prefs = await SharedPreferences.getInstance();
    final dir = prefs.getString('exportDir') ?? '';
    if (dir.isNotEmpty) {
      return _fileService.exportCsvToPath(
        dirPath: dir,
        filename: 'scan_$fileName',
        content: csv.toString(),
        appendTimestamp: true,
      );
    } else {
      return _fileService.exportCsv(
        csv.toString(),
        'scan_${fileName}_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }
}
