import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      '${dir.path}/mac_scanner.db',
      version: 2,
      onCreate: (db, version) async {
        // 檔案表
        await db.execute('''
          CREATE TABLE scan_files(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');

        // 掃描記錄表
        await db.execute('''
          CREATE TABLE scan_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id INTEGER NOT NULL,
            local_id INTEGER,
            mac TEXT NOT NULL,
            suffix TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            note TEXT,
            FOREIGN KEY (file_id) REFERENCES scan_files (id) ON DELETE CASCADE
          );
        ''');

        // 索引
        await db.execute('CREATE INDEX idx_file_id ON scan_records(file_id);');
        await db.execute('CREATE INDEX idx_suffix ON scan_records(suffix);');
        await db.execute('CREATE UNIQUE INDEX ux_records_file_local ON scan_records(file_id, local_id);');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // 為既有資料庫新增 local_id 欄位
          await db.execute('ALTER TABLE scan_records ADD COLUMN local_id INTEGER;');
          await db.execute('CREATE UNIQUE INDEX ux_records_file_local ON scan_records(file_id, local_id);');
        }
      },
    );
    return _db!;
  }

  // 檔案操作
  Future<int> createFile(String name, String description) async {
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await database.insert('scan_files', {
      'name': name,
      'description': description,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> getAllFiles() async {
    final database = await db;
    // Join with record count
    return await database.rawQuery('''
      SELECT f.*, COUNT(r.id) as record_count
      FROM scan_files f
      LEFT JOIN scan_records r ON f.id = r.file_id
      GROUP BY f.id
      ORDER BY f.updated_at DESC
    ''');
  }

  Future<int> updateFile(int id, String name, String description) async {
    final database = await db;
    return await database.update(
      'scan_files',
      {
        'name': name,
        'description': description,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteFile(int id) async {
    final database = await db;
    return await database.delete('scan_files', where: 'id = ?', whereArgs: [id]);
  }

  // 記錄操作
  Future<int> insertRecord(int fileId, String mac, String suffix, {String? note}) async {
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    print('insertRecord SQL begin for fileId=$fileId, mac=$mac, suffix=$suffix, note=$note');

    return await database.transaction((txn) async {
      // 取得該檔案的下一個 local_id
      final maxRow = await txn.rawQuery(
        'SELECT COALESCE(MAX(local_id), 0) AS m FROM scan_records WHERE file_id = ?',
        [fileId],
      );
      final nextLocalId = (maxRow.first['m'] as int) + 1;

      // 更新檔案的 updated_at
      print('Updating scan_files.updated_at for fileId=$fileId to $now');
      await txn.update(
        'scan_files',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [fileId],
      );

      // 插入新紀錄
      final recordId = await txn.insert('scan_records', {
        'file_id': fileId,
        'local_id': nextLocalId,
        'mac': mac,
        'suffix': suffix,
        'timestamp': now,
        'note': note,
      });
      print('insertRecord SQL end, recordId=$recordId, localId=$nextLocalId');

      return recordId;
    });
  }

  Future<List<Map<String, dynamic>>> getRecordsByFileId(int fileId) async {
    final database = await db;
    return await database.query(
      'scan_records',
      where: 'file_id = ?',
      whereArgs: [fileId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<bool> suffixExistsInFile(int fileId, String suffix) async {
    final database = await db;
    final result = await database.query(
      'scan_records',
      where: 'file_id = ? AND suffix = ?',
      whereArgs: [fileId, suffix],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<int> deleteRecord(int recordId) async {
    final database = await db;
    return await database.delete('scan_records', where: 'id = ?', whereArgs: [recordId]);
  }

  // 新增：重新整理檔案內的 local_id 連號
  Future<void> resequenceFile(int fileId) async {
    final database = await db;
    await database.transaction((txn) async {
      // 0. 先将该 fileId 下所有 local_id 设为 NULL，清除旧编号
      await txn.rawUpdate(
        'UPDATE scan_records SET local_id = NULL WHERE file_id = ?',
        [fileId],
      );

      // 1. 按 MAC 升序（相同时按 id）取出所有记录
      final rows = await txn.query(
        'scan_records',
        where: 'file_id = ?',
        whereArgs: [fileId],
        orderBy: 'mac ASC, id ASC',
      );

      // 2. 依此顺序连号赋值
      var seq = 1;
      for (final r in rows) {
        await txn.update(
          'scan_records',
          {'local_id': seq++},
          where: 'id = ?',
          whereArgs: [r['id']],
        );
      }
    });
  }
}
