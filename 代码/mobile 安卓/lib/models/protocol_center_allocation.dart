/// Many-to-many link between Protocol and Center plus site-level metadata.
class ProtocolCenterAllocation {
  final String id;
  final String protocolId;
  final String centerId;
  final DateTime? irbApprovalDate;
  final String? irbDocumentPath;
  final String? piId;
  final String? piName;
  final DateTime? activatedAt;
  final String status; // pending / active / suspended / closed
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProtocolCenterAllocation({
    required this.id,
    required this.protocolId,
    required this.centerId,
    this.irbApprovalDate,
    this.irbDocumentPath,
    this.piId,
    this.piName,
    this.activatedAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProtocolCenterAllocation.fromJson(Map<String, dynamic> json) {
    return ProtocolCenterAllocation(
      id: json['id'] as String,
      protocolId: json['protocolId'] as String,
      centerId: json['centerId'] as String,
      irbApprovalDate: json['irbApprovalDate'] != null
          ? DateTime.parse(json['irbApprovalDate'] as String)
          : null,
      irbDocumentPath: json['irbDocumentPath'] as String?,
      piId: json['piId'] as String?,
      piName: json['piName'] as String?,
      activatedAt: json['activatedAt'] != null
          ? DateTime.parse(json['activatedAt'] as String)
          : null,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'protocolId': protocolId,
        'centerId': centerId,
        'irbApprovalDate': irbApprovalDate?.toIso8601String(),
        'irbDocumentPath': irbDocumentPath,
        'piId': piId,
        'piName': piName,
        'activatedAt': activatedAt?.toIso8601String(),
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  bool get isActive => status == 'active';
}
