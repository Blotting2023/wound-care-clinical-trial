/// A research centre (医院/科室分中心) executing one or more protocols.
///
/// Each `ResearchCenter` carries its IRB approval number, principal
/// investigator, address.  Per GCP §2022 第28号 第三章，every
/// participating site must have IRB approval on file before any
/// subject is enrolled.
///
/// W4.1: 加了 `consentMode` 字段 — 中心维度配置 eConsent 接受态度。
/// `consentModeSetAt` / `consentModeSetBy` 记录切换时间与操作员，
/// 切换写 AuditLog（CONFIG_CHANGE opType）。
library;

import 'consent_form.dart';

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

  /// W6 — 中心负责人（PI）联系电话/邮箱等联系方式，自由格式。
  final String? piContact;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// W4.1 — 中心维度的知情同意模式。
  /// 默认 PAPER_PHOTO（B 通道，老胡所在医院默认走这个）。
  final ConsentMode consentMode;
  final DateTime? consentModeSetAt;
  final String? consentModeSetBy;

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
    this.piContact,
    required this.createdAt,
    required this.updatedAt,
    this.consentMode = ConsentMode.PAPER_PHOTO,
    this.consentModeSetAt,
    this.consentModeSetBy,
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
      piContact: json['piContact'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      consentMode: ConsentMode.tryParse(json['consentMode'] as String?) ??
          ConsentMode.PAPER_PHOTO,
      consentModeSetAt: json['consentModeSetAt'] != null
          ? DateTime.parse(json['consentModeSetAt'] as String)
          : null,
      consentModeSetBy: json['consentModeSetBy'] as String?,
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
        'piContact': piContact,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'consentMode': consentMode.name,
        'consentModeSetAt': consentModeSetAt?.toIso8601String(),
        'consentModeSetBy': consentModeSetBy,
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
    String? piContact,
    DateTime? createdAt,
    DateTime? updatedAt,
    ConsentMode? consentMode,
    DateTime? consentModeSetAt,
    String? consentModeSetBy,
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
      piContact: piContact ?? this.piContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      consentMode: consentMode ?? this.consentMode,
      consentModeSetAt: consentModeSetAt ?? this.consentModeSetAt,
      consentModeSetBy: consentModeSetBy ?? this.consentModeSetBy,
    );
  }

  String get displayLabel => '$name · $department';
}
