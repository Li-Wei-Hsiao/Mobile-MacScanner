class ScanRecord {
  final int? id;
  final int fileId;
  final int? localId;
  final String mac;
  final String suffix;
  final int timestamp;
  final String? note;

  ScanRecord({
    this.id,
    required this.fileId,
    this.localId,
    required this.mac,
    required this.suffix,
    required this.timestamp,
    this.note,
  });

  factory ScanRecord.fromMap(Map<String, dynamic> map) {
    return ScanRecord(
      id: map['id'] as int?,
      fileId: map['file_id'] as int,
      localId: map['local_id'],
      mac: map['mac'] as String,
      suffix: map['suffix'] as String,
      timestamp: map['timestamp'] as int,
      note: map['note'] as String?,
    );
  }
}
