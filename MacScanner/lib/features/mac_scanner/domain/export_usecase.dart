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

  /// 匯出檔案，依 MAC 升冪排序，使用 local_id 作 No 欄
  Future<String> exportFileToCSV(ScanFile file) async {
    final fileId = file.id!;
    final fileName = file.name;

    // 1. 先重新整理 local_id，確保連號
    await scanRepo.resequenceFile(fileId);

    // 2. 取得記錄並以 MAC 升冪排序
    final records = await scanRepo.fetchByFile(fileId);
    records.sort((a, b) => a.mac.compareTo(b.mac));

    // 3. 組 CSV 內容
    final csv = StringBuffer()..writeln('No,MAC,Suffix,Timestamp,Note');
    for (var r in records) {
      final no = r.localId ?? 0;
      final ts = DateTime.fromMillisecondsSinceEpoch(r.timestamp).toIso8601String();
      String esc(String v) => v.contains(RegExp(r'[",\n]'))
          ? '"${v.replaceAll('"', '""')}"'
          : v;
      csv.writeln('$no,${esc(r.mac)},${esc(r.suffix)},${esc(ts)},${esc(r.note ?? '')}');
    }

    // 4. 獲取匯出目錄
    final prefs = await SharedPreferences.getInstance();
    final dir = prefs.getString('exportDir') ?? '';

    // 5. 寫檔並回傳路徑
    final fileObj = dir.isNotEmpty
        ? await fileService.exportCsvToPath(
          dirPath: dir,
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
