class PendingOp {
  final int? id;
  final String tableName;
  final String recordId;
  final String opType; // 'insert', 'update', 'delete'
  final String? payload;
  final DateTime createdAt;

  const PendingOp({
    this.id,
    required this.tableName,
    required this.recordId,
    required this.opType,
    this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'table_name': tableName,
      'record_id': recordId,
      'op_type': opType,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory PendingOp.fromMap(Map<String, dynamic> map) {
    return PendingOp(
      id: map['id'] as int?,
      tableName: map['table_name'] as String,
      recordId: map['record_id'] as String,
      opType: map['op_type'] as String,
      payload: map['payload'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
