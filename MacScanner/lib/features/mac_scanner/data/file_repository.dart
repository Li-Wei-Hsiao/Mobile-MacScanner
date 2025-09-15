import '../../../core/services/database_service.dart';
import 'scan_file.dart';

class FileRepository {
  final _db = DatabaseService();

  Future<int> createFile(String name, String description) async {
    return _db.createFile(name, description);
  }

  Future<List<ScanFile>> getAllFiles() async {
    final maps = await _db.getAllFiles();
    return maps.map(ScanFile.fromMap).toList();
  }

  Future<int> updateFile(ScanFile file) async {
    return _db.updateFile(file.id!, file.name, file.description);
  }

  Future<int> deleteFile(int id) async {
    return _db.deleteFile(id);
  }
}
