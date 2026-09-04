/// Wound data model representing a single wound on a patient.
class Wound {
  final String id;
  final String patientId;
  final String anatomicalLocation;
  final String? woundType; // pressure injury, surgical, diabetic, etc.
  final String? etiology;
  final DateTime onsetDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// GCP W2 — 关联到 Protocol + Center + 试用器械.
  /// Patient 入组前必须先有 Protocol + Center, 故这三项对临床评估场景必填.
  final String? protocolId;
  final String? centerId;
  final String? deviceId;

  const Wound({
    required this.id,
    required this.patientId,
    required this.anatomicalLocation,
    this.woundType,
    this.etiology,
    required this.onsetDate,
    required this.createdAt,
    required this.updatedAt,
    this.protocolId,
    this.centerId,
    this.deviceId,
  });

  factory Wound.fromJson(Map<String, dynamic> json) {
    return Wound(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      anatomicalLocation: json['anatomicalLocation'] as String? ?? '',
      woundType: json['woundType'] as String?,
      etiology: json['etiology'] as String?,
      onsetDate: DateTime.parse(json['onsetDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      protocolId: json['protocolId'] as String?,
      centerId: json['centerId'] as String?,
      deviceId: json['deviceId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'anatomicalLocation': anatomicalLocation,
      'woundType': woundType,
      'etiology': etiology,
      'onsetDate': onsetDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'protocolId': protocolId,
      'centerId': centerId,
      'deviceId': deviceId,
    };
  }

  Wound copyWith({
    String? id,
    String? patientId,
    String? anatomicalLocation,
    String? woundType,
    String? etiology,
    DateTime? onsetDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? protocolId,
    String? centerId,
    String? deviceId,
  }) {
    return Wound(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      anatomicalLocation: anatomicalLocation ?? this.anatomicalLocation,
      woundType: woundType ?? this.woundType,
      etiology: etiology ?? this.etiology,
      onsetDate: onsetDate ?? this.onsetDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      protocolId: protocolId ?? this.protocolId,
      centerId: centerId ?? this.centerId,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  String get displayLabel =>
      '$anatomicalLocation${woundType != null ? ' ($woundType)' : ''}';
}
