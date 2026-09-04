/// Per-subject device-usage record (受试者使用某台研究器械的台账).
class DeviceUsageLog {
  final String id;
  final String deviceId;
  final String centerId;
  final String patientId;
  final String protocolId;
  final String operatorId;
  final String operatorName;
  final DateTime allocatedAt;
  final DateTime? returnedAt;
  final String? returnCondition; // intact / partial / damaged
  final String? disposalReason; // expired / damaged / completed
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeviceUsageLog({
    required this.id,
    required this.deviceId,
    required this.centerId,
    required this.patientId,
    required this.protocolId,
    required this.operatorId,
    required this.operatorName,
    required this.allocatedAt,
    this.returnedAt,
    this.returnCondition,
    this.disposalReason,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeviceUsageLog.fromJson(Map<String, dynamic> json) {
    return DeviceUsageLog(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      centerId: json['centerId'] as String,
      patientId: json['patientId'] as String,
      protocolId: json['protocolId'] as String,
      operatorId: json['operatorId'] as String? ?? '',
      operatorName: json['operatorName'] as String? ?? '',
      allocatedAt: DateTime.parse(json['allocatedAt'] as String),
      returnedAt: json['returnedAt'] != null
          ? DateTime.parse(json['returnedAt'] as String)
          : null,
      returnCondition: json['returnCondition'] as String?,
      disposalReason: json['disposalReason'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceId': deviceId,
        'centerId': centerId,
        'patientId': patientId,
        'protocolId': protocolId,
        'operatorId': operatorId,
        'operatorName': operatorName,
        'allocatedAt': allocatedAt.toIso8601String(),
        'returnedAt': returnedAt?.toIso8601String(),
        'returnCondition': returnCondition,
        'disposalReason': disposalReason,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  bool get isActive => returnedAt == null;
}
