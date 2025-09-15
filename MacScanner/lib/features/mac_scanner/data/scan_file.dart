class ScanFile {
  final int? id;
  final String name;
  final String description;
  final int createdAt;
  final int updatedAt;
  int recordCount;

  ScanFile({
    this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.recordCount = 0,
  });

  factory ScanFile.fromMap(Map<String, dynamic> map) {
    return ScanFile(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      recordCount: map['record_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  ScanFile copyWith({
    int? id,
    String? name,
    String? description,
    int? createdAt,
    int? updatedAt,
    int? recordCount,
  }) {
    return ScanFile(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      recordCount: recordCount ?? this.recordCount,
    );
  }
}
