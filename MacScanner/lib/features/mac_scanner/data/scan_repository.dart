// lib/features/mac_scanner/data/scan_repository.dart
import '../../../core/services/database_service.dart';
import 'scan_record.dart';

class ScanRepository {
  final _db = DatabaseService();

  Future<int> addRecord(int fileId, String mac, String suffix) async {
    print('addRecord called with fileId=$fileId, mac=$mac, suffix=$suffix');
    final id = await _db.insertRecord(fileId, mac, suffix);
    print('insertRecord returned id=$id');
    return id;
  }


  Future<List<ScanRecord>> fetchByFile(int fileId) async {
    final maps = await _db.getRecordsByFileId(fileId);
    return maps.map(ScanRecord.fromMap).toList();
  }

  // 新增此方法：載入最近 limit 筆記錄
  Future<List<ScanRecord>> fetchRecent(int limit) async {
    final database = await _db.db;
    final maps = await database.query(
      'scan_records',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map(ScanRecord.fromMap).toList();
  }

  Future<bool> suffixExists(int fileId, String suffix) async {
    return _db.suffixExistsInFile(fileId, suffix);
  }

  Future<int> deleteRecord(int recordId) async {
    return _db.deleteRecord(recordId);
  }

  // 新增：重新整理檔案內的序號
  Future<void> resequenceFile(int fileId) async {
    print('resequenceFile called with fileId=$fileId');
    await _db.resequenceFile(fileId);
    print('resequenceFile completed');
  }
}
