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

  // Export CSV file for a given ScanFile, using No column from 1 to N sorted by MAC ascending
  Future<File> exportCsv(int fileId, String fileName) async {
    // 1. fetch records and sort by MAC ascending
    final records = await repo.fetchByFile(fileId);
    records.sort((a, b) => a.mac.compareTo(b.mac));

    // 2. combine CSV content
    final csv = StringBuffer()..writeln('No,MAC,Suffix,Timestamp,Note');
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      final no = i + 1;
      final ts = DateTime.fromMillisecondsSinceEpoch(r.timestamp).toIso8601String();
      String esc(String v) => v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
      csv.writeln('$no,${esc(r.mac)},${esc(r.suffix)},${esc(ts)},${esc(r.note ?? '')}');
    }

    // 3. Check user-preferred export directory from SharedPreferences
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
