/// A research centre (医院/科室分中心) executing one or more protocols.
///
/// Each `ResearchCenter` carries its IRB approval number, principal
/// investigator, address.  Per GCP §2022 第28号 第三章，every
/// participating site must have IRB approval on file before any
/// subject is enrolled.
class ResearchCenter {
  final String id;
  final String code; // e.g. "SD-HOSP-001"
  final String name;
  final String department;
  final String? address;
  final String? irbNumber;
  final DateTime? irbApprovalDate;
  final String? leadPiId;
  final String? leadPiName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ResearchCenter({
    required this.id,
    required this.code,
    required this.name,
    required this.department,
    this.address,
    this.irbNumber,
    this.irbApprovalDate,
    this.leadPiId,
    this.leadPiName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ResearchCenter.fromJson(Map<String, dynamic> json) {
    return ResearchCenter(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      address: json['address'] as String?,
      irbNumber: json['irbNumber'] as String?,
      irbApprovalDate: json['irbApprovalDate'] != null
          ? DateTime.parse(json['irbApprovalDate'] as String)
          : null,
      leadPiId: json['leadPiId'] as String?,
      leadPiName: json['leadPiName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'department': department,
        'address': address,
        'irbNumber': irbNumber,
        'irbApprovalDate': irbApprovalDate?.toIso8601String(),
        'leadPiId': leadPiId,
        'leadPiName': leadPiName,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  ResearchCenter copyWith({
    String? id,
    String? code,
    String? name,
    String? department,
    String? address,
    String? irbNumber,
    DateTime? irbApprovalDate,
    String? leadPiId,
    String? leadPiName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ResearchCenter(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      department: department ?? this.department,
      address: address ?? this.address,
      irbNumber: irbNumber ?? this.irbNumber,
      irbApprovalDate: irbApprovalDate ?? this.irbApprovalDate,
      leadPiId: leadPiId ?? this.leadPiId,
      leadPiName: leadPiName ?? this.leadPiName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayLabel => '$name · $department';
}
