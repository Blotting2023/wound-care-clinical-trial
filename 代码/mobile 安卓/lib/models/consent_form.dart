/// ConsentForm — 知情同意书数据模型。
///
/// 字段跟任务卡 W4.1 完全对齐。
/// - A 通道（`E_CONSENT`）：电子知情同意，签名坐标 + 笔迹 PNG + 设备指纹
/// - B 通道（`PAPER_PHOTO`）：纸质件拍照存档，PI 录入签署日期 + 见证人
///
/// 撤回字段 `withdrawnAt` / `withdrawnBy` / `withdrawReason` 任一非空
/// 即视为已撤回。撤回后所有依赖此 consent 的评估记录应被冻结（V1 demo
/// 阶段只展示状态，不强制阻断）。
library;

enum ConsentMode {
  E_CONSENT,
  PAPER_PHOTO;

  String get displayName {
    switch (this) {
      case ConsentMode.E_CONSENT:
        return '电子知情同意（eConsent）';
      case ConsentMode.PAPER_PHOTO:
        return '纸质件拍照存档';
    }
  }

  String get shortName {
    switch (this) {
      case ConsentMode.E_CONSENT:
        return 'A 通道';
      case ConsentMode.PAPER_PHOTO:
        return 'B 通道';
    }
  }

  static ConsentMode? tryParse(String? s) {
    if (s == null) return null;
    for (final m in ConsentMode.values) {
      if (m.name == s) return m;
    }
    return null;
  }
}

class ConsentForm {
  final String id;
  final String patientId;
  final String protocolId;
  final String? centerId;
  final String version;
  final ConsentMode mode;

  final DateTime signedAt;
  final String signedBy;
  final String? signedByName;

  // A 通道
  final String? pdfPath;
  final String? signaturePath; // 签名 PNG
  final String? signatureStrokeJson; // 笔迹坐标数组 JSON（防事后修改）
  final String? deviceFingerprint;
  final String? operatorIp;

  // B 通道
  final String? signedPaperPath; // 纸质件图像
  final DateTime? paperSignedDate; // PI 录入的签署日期
  final String? witnessName;

  // 撤回
  final DateTime? withdrawnAt;
  final String? withdrawnBy;
  final String? withdrawReason;

  // 审核（B 通道）
  final bool reviewedByPi;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ConsentForm({
    required this.id,
    required this.patientId,
    required this.protocolId,
    this.centerId,
    required this.version,
    required this.mode,
    required this.signedAt,
    required this.signedBy,
    this.signedByName,
    this.pdfPath,
    this.signaturePath,
    this.signatureStrokeJson,
    this.deviceFingerprint,
    this.operatorIp,
    this.signedPaperPath,
    this.paperSignedDate,
    this.witnessName,
    this.withdrawnAt,
    this.withdrawnBy,
    this.withdrawReason,
    this.reviewedByPi = false,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isWithdrawn => withdrawnAt != null;

  /// 是否为 A 通道（电子版）
  bool get isElectronic => mode == ConsentMode.E_CONSENT;

  factory ConsentForm.fromJson(Map<String, dynamic> json) {
    return ConsentForm(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      protocolId: json['protocolId'] as String,
      centerId: json['centerId'] as String?,
      version: json['version'] as String? ?? '1.0',
      mode: ConsentMode.tryParse(json['mode'] as String?) ?? ConsentMode.PAPER_PHOTO,
      signedAt: DateTime.parse(json['signedAt'] as String),
      signedBy: json['signedBy'] as String? ?? '',
      signedByName: json['signedByName'] as String?,
      pdfPath: json['pdfPath'] as String?,
      signaturePath: json['signaturePath'] as String?,
      signatureStrokeJson: json['signatureStrokeJson'] as String?,
      deviceFingerprint: json['deviceFingerprint'] as String?,
      operatorIp: json['operatorIp'] as String?,
      signedPaperPath: json['signedPaperPath'] as String?,
      paperSignedDate: json['paperSignedDate'] != null
          ? DateTime.parse(json['paperSignedDate'] as String)
          : null,
      witnessName: json['witnessName'] as String?,
      withdrawnAt: json['withdrawnAt'] != null
          ? DateTime.parse(json['withdrawnAt'] as String)
          : null,
      withdrawnBy: json['withdrawnBy'] as String?,
      withdrawReason: json['withdrawReason'] as String?,
      reviewedByPi: json['reviewedByPi'] as bool? ?? false,
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'] as String)
          : null,
      reviewNote: json['reviewNote'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'protocolId': protocolId,
        'centerId': centerId,
        'version': version,
        'mode': mode.name,
        'signedAt': signedAt.toIso8601String(),
        'signedBy': signedBy,
        'signedByName': signedByName,
        'pdfPath': pdfPath,
        'signaturePath': signaturePath,
        'signatureStrokeJson': signatureStrokeJson,
        'deviceFingerprint': deviceFingerprint,
        'operatorIp': operatorIp,
        'signedPaperPath': signedPaperPath,
        'paperSignedDate': paperSignedDate?.toIso8601String(),
        'witnessName': witnessName,
        'withdrawnAt': withdrawnAt?.toIso8601String(),
        'withdrawnBy': withdrawnBy,
        'withdrawReason': withdrawReason,
        'reviewedByPi': reviewedByPi,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'reviewNote': reviewNote,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  ConsentForm copyWith({
    String? version,
    String? pdfPath,
    String? signaturePath,
    String? signatureStrokeJson,
    String? signedPaperPath,
    DateTime? paperSignedDate,
    String? witnessName,
    DateTime? withdrawnAt,
    String? withdrawnBy,
    String? withdrawReason,
    bool? reviewedByPi,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewNote,
    DateTime? updatedAt,
  }) =>
      ConsentForm(
        id: id,
        patientId: patientId,
        protocolId: protocolId,
        centerId: centerId,
        version: version ?? this.version,
        mode: mode,
        signedAt: signedAt,
        signedBy: signedBy,
        signedByName: signedByName,
        pdfPath: pdfPath ?? this.pdfPath,
        signaturePath: signaturePath ?? this.signaturePath,
        signatureStrokeJson: signatureStrokeJson ?? this.signatureStrokeJson,
        deviceFingerprint: deviceFingerprint,
        operatorIp: operatorIp,
        signedPaperPath: signedPaperPath ?? this.signedPaperPath,
        paperSignedDate: paperSignedDate ?? this.paperSignedDate,
        witnessName: witnessName ?? this.witnessName,
        withdrawnAt: withdrawnAt ?? this.withdrawnAt,
        withdrawnBy: withdrawnBy ?? this.withdrawnBy,
        withdrawReason: withdrawReason ?? this.withdrawReason,
        reviewedByPi: reviewedByPi ?? this.reviewedByPi,
        reviewedBy: reviewedBy ?? this.reviewedBy,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        reviewNote: reviewNote ?? this.reviewNote,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
