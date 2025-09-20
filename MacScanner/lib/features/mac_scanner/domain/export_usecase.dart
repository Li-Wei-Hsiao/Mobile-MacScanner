import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/file_service.dart';
import '../data/file_repository.dart';
import '../data/scan_file.dart';
import '../data/scan_repository.dart';

class ExportUseCase {
  final FileRepository fileRepo;
  final ScanRepository scanRepo;
  final FileService fileService;

  ExportUseCase({
    required this.fileRepo,
    required this.scanRepo,
    required this.fileService,
  });

  // Export CSV file for a given ScanFile, using local_id as ascending No column
  Future<String> exportFileToCSV(ScanFile file) async {
    final fileId = file.id!;
    final fileName = file.name;

    // Reload and resequence local_id to ensure continuity
    await scanRepo.resequenceFile(fileId);

    // Get records, sort by MAC ascending
    final records = await scanRepo.fetchByFile(fileId);
    records.sort((a, b) => a.mac.compareTo(b.mac));

    // 3. Build CSV content
    final csv = StringBuffer()..writeln('No,MAC,Suffix,Timestamp,Note');
    for (var r in records) {
      final no = r.localId ?? 0;
      final ts = DateTime.fromMillisecondsSinceEpoch(r.timestamp).toIso8601String();
      String esc(String v) => v.contains(RegExp(r'[",\n]'))
          ? '"${v.replaceAll('"', '""')}"'
          : v;
      csv.writeln('$no,${esc(r.mac)},${esc(r.suffix)},${esc(ts)},${esc(r.note ?? '')}');
    }

    // 4. Get user-preferred export directory from SharedPreferences
    String dirPath;
    if (Platform.isIOS) {
      final appDocDir = await getApplicationDocumentsDirectory();
      dirPath = appDocDir.path;
    }
    else {
      // Android：使用使用者偏好設定的目錄
      final prefs = await SharedPreferences.getInstance();
      final exportDir = prefs.getString('exportDir') ?? '';
      if (exportDir.isEmpty) {
        throw Exception('Export directory not set');
      }
      dirPath = exportDir;
    }

//    final prefs = await SharedPreferences.getInstance();
//    final dir = prefs.getString('exportDir') ?? '';

    // 5. Write to file and return path
    final fileObj = dirPath.isNotEmpty
        ? await fileService.exportCsvToPath(
          dirPath: dirPath,
          filename: 'scan_$fileName',
          content: csv.toString(),
          appendTimestamp: true,
    )
    : await fileService.exportCsv(
      csv.toString(),
      'scan_${fileName}_${DateTime.now().millisecondsSinceEpoch}',
    );

    return fileObj.path;
  }
}
