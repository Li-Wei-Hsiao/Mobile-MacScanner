// lib/core/services/file_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileService {
  // Default export: write to App Documents directory
  Future<File> exportCsv(String content, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${_safeFilename(filename)}.csv');
    return file.writeAsString(content, flush: true);
  }

  // Write CSV to user-specified path with optional timestamp
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

  // Get list of files in a directory
  Future<Directory> getAppDirectory() async {
    return getApplicationDocumentsDirectory();
  }

  // Get list of files in a directory
  String _safeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*\n\r\t]'), '_').trim();
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
