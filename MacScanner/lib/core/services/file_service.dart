// lib/core/services/file_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileService {
  /// 預設匯出：寫入 App Documents 目錄
  Future<File> exportCsv(String content, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${_safeFilename(filename)}.csv');
    return file.writeAsString(content, flush: true);
  }

  /// 高階匯出：寫入使用者指定的目錄，可選擇是否附加時間戳
  Future<File> exportCsvToPath({
    required String dirPath,
    required String filename,
    required String content,
    bool appendTimestamp = false,
  }) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final ts = _timestamp();
    final base = _safeFilename(filename);
    final name = appendTimestamp ? '${base}_$ts.csv' : '$base.csv';
    final file = File('${dir.path}/$name');
    return file.writeAsString(content, flush: true);
  }

  // 取得 App Documents 目錄
  Future<Directory> getAppDirectory() async {
    return getApplicationDocumentsDirectory();
  }

  // 以下為私有工具方法
  String _safeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*\n\r\t]'), '_').trim();
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
