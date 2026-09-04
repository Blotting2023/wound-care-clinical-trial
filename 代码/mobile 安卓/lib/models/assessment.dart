import 'enums.dart';

/// Assessment data model capturing the full wound assessment.
/// AI-generated values are stored alongside clinician-confirmed final values.
class Assessment {
  final String id;
  final String patientId;
  final String woundId;
  final String clinicianId;
  final String? clinicianName;

  // Status
  final AssessmentStatus status;

  // AI-generated measurements
  final double? aiAreaCm2;
  final double? aiLengthCm;
  final double? aiWidthCm;
  final double? aiDepthCm;
  final Map<String, double>? aiTissuePercentages; // e.g. {'granulation': 0.7}
  final String? aiPolygonJson; // JSON-serialized List<Offset>

  // Clinician-confirmed measurements
  final double? finalAreaCm2;
  final double? finalLengthCm;
  final double? finalWidthCm;
  final double? finalDepthCm;
  final Map<String, double>? finalTissuePercentages;
  final String? finalPolygonJson;

  // Clinical observations
  final ExudateLevel? exudateLevel;
  final WoundEdge? woundEdge;
  final PeriWoundSkin? periWoundSkin;
  final String? infectionSigns;

  // Vancouver Scar Scale
  final int? vssVascularity;
  final int? vssPigmentation;
  final int? vssPliability;
  final int? vssHeight;
  final int? vssTotal;

  // NRS Pain
  final int? nrsPainScore;

  // Tunnel / undermining
  final String? tunnelClockDirection; // e.g. '3 o'clock'
  final double? tunnelDepthCm;

  // Signature
  final String? signedBy;
  final DateTime? signedAt;
  final SignOffMethod? signOffMethod;

  final String? notes;
  final String? photoPath; // 本地照片路径（demo：合成图；真实：拍照压缩后路径）

  /// GCP W2 — 每条评估记录必须挂上方案/中心/试用器械, 否则无法做多中心
  /// 数据汇总也无法正确计入 SAE 报告流. 生产场景必填; V1 demo 允许
  /// 留空但会触发审计日志 "未绑定方案中心" 事件.
  final String? protocolId;
  final String? centerId;
  final String? deviceId;
  final String? deviceUsageLogId;

  /// GCP W3.2 — CRF 必填字段（与 2016 年第 58 号通告 CRF 范本对齐）。
  ///
  /// * [concomitantMedications] — 合并用药 JSON / null，未知则改成显式三态
  ///   (`ND` = 不知道, `UN` = 未做, `NA` = 不适用)。结构：
  ///   `[{name, dose, frequency, startDate, endDate, ongoing}]`
  /// * [concomitantDiseases] — 合并疾病 JSON，结构同上但保留自由文本。
  /// * [aeRefs] — 关联 AE 占位数组，结构：`[aeRefId]`；V2 接 SAE 流程。
  /// * [crfCompletionDeclaredAt] — CRF 完成声明时间（PI 必签，签完临床
  ///   数据字段锁死）。
  ///
  /// ND/UN/NA 三态字符串值会被 [CrfTriState] 工具方法识别。
  final List<Map<String, dynamic>>? concomitantMedications;
  final List<Map<String, dynamic>>? concomitantDiseases;
  final List<Map<String, dynamic>>? aeRefs;
  final DateTime? crfCompletionDeclaredAt;

  /// CRF 完成声明的 PI 鉴认（subjectCode + name）；不可篡改。
  final String? crfCompletedBy;
  final String? crfCompletedByName;

  /// 创面照片元数据快照（W3.1）—— 在 confirm / lock 时随评估永久挂定。
  final Map<String, dynamic>? photoMetadataSnapshot;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Assessment({
    required this.id,
    required this.patientId,
    required this.woundId,
    required this.clinicianId,
    this.clinicianName,
    required this.status,
    this.aiAreaCm2,
    this.aiLengthCm,
    this.aiWidthCm,
    this.aiDepthCm,
    this.aiTissuePercentages,
    this.aiPolygonJson,
    this.finalAreaCm2,
    this.finalLengthCm,
    this.finalWidthCm,
    this.finalDepthCm,
    this.finalTissuePercentages,
    this.finalPolygonJson,
    this.exudateLevel,
    this.woundEdge,
    this.periWoundSkin,
    this.infectionSigns,
    this.vssVascularity,
    this.vssPigmentation,
    this.vssPliability,
    this.vssHeight,
    this.vssTotal,
    this.nrsPainScore,
    this.tunnelClockDirection,
    this.tunnelDepthCm,
    this.signedBy,
    this.signedAt,
    this.signOffMethod,
    this.notes,
    this.photoPath,
    this.protocolId,
    this.centerId,
    this.deviceId,
    this.deviceUsageLogId,
    this.concomitantMedications,
    this.concomitantDiseases,
    this.aeRefs,
    this.crfCompletionDeclaredAt,
    this.crfCompletedBy,
    this.crfCompletedByName,
    this.photoMetadataSnapshot,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      woundId: json['woundId'] as String,
      clinicianId: json['clinicianId'] as String,
      clinicianName: json['clinicianName'] as String?,
      status: AssessmentStatus.fromString(json['status'] as String? ?? 'draft'),
      aiAreaCm2: (json['aiAreaCm2'] as num?)?.toDouble(),
      aiLengthCm: (json['aiLengthCm'] as num?)?.toDouble(),
      aiWidthCm: (json['aiWidthCm'] as num?)?.toDouble(),
      aiDepthCm: (json['aiDepthCm'] as num?)?.toDouble(),
      aiTissuePercentages: json['aiTissuePercentages'] != null
          ? Map<String, double>.from(
              (json['aiTissuePercentages'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : null,
      aiPolygonJson: json['aiPolygonJson'] as String?,
      finalAreaCm2: (json['finalAreaCm2'] as num?)?.toDouble(),
      finalLengthCm: (json['finalLengthCm'] as num?)?.toDouble(),
      finalWidthCm: (json['finalWidthCm'] as num?)?.toDouble(),
      finalDepthCm: (json['finalDepthCm'] as num?)?.toDouble(),
      finalTissuePercentages: json['finalTissuePercentages'] != null
          ? Map<String, double>.from(
              (json['finalTissuePercentages'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : null,
      finalPolygonJson: json['finalPolygonJson'] as String?,
      exudateLevel: json['exudateLevel'] != null
          ? ExudateLevel.fromString(json['exudateLevel'] as String)
          : null,
      woundEdge: json['woundEdge'] != null
          ? WoundEdge.fromString(json['woundEdge'] as String)
          : null,
      periWoundSkin: json['periWoundSkin'] != null
          ? PeriWoundSkin.fromString(json['periWoundSkin'] as String)
          : null,
      infectionSigns: json['infectionSigns'] as String?,
      vssVascularity: json['vssVascularity'] as int?,
      vssPigmentation: json['vssPigmentation'] as int?,
      vssPliability: json['vssPliability'] as int?,
      vssHeight: json['vssHeight'] as int?,
      vssTotal: json['vssTotal'] as int?,
      nrsPainScore: json['nrsPainScore'] as int?,
      tunnelClockDirection: json['tunnelClockDirection'] as String?,
      tunnelDepthCm: (json['tunnelDepthCm'] as num?)?.toDouble(),
      signedBy: json['signedBy'] as String?,
      signedAt: json['signedAt'] != null
          ? DateTime.tryParse(json['signedAt'] as String)
          : null,
      signOffMethod: json['signOffMethod'] != null
          ? SignOffMethod.fromString(json['signOffMethod'] as String)
          : null,
      notes: json['notes'] as String?,
      photoPath: json['photoPath'] as String?,
      protocolId: json['protocolId'] as String?,
      centerId: json['centerId'] as String?,
      deviceId: json['deviceId'] as String?,
      deviceUsageLogId: json['deviceUsageLogId'] as String?,
      concomitantMedications: json['concomitantMedications'] != null
          ? List<Map<String, dynamic>>.from(
              (json['concomitantMedications'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : null,
      concomitantDiseases: json['concomitantDiseases'] != null
          ? List<Map<String, dynamic>>.from(
              (json['concomitantDiseases'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : null,
      aeRefs: json['aeRefs'] != null
          ? List<Map<String, dynamic>>.from(
              (json['aeRefs'] as List).map(
                (e) => e is Map
                    ? Map<String, dynamic>.from(e)
                    : <String, dynamic>{'triState': e},
              ),
            )
          : null,
      crfCompletionDeclaredAt: json['crfCompletionDeclaredAt'] != null
          ? DateTime.tryParse(json['crfCompletionDeclaredAt'] as String)
          : null,
      crfCompletedBy: json['crfCompletedBy'] as String?,
      crfCompletedByName: json['crfCompletedByName'] as String?,
      photoMetadataSnapshot: json['photoMetadataSnapshot'] != null
          ? Map<String, dynamic>.from(json['photoMetadataSnapshot'] as Map)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'woundId': woundId,
      'clinicianId': clinicianId,
      'clinicianName': clinicianName,
      'status': status.value,
      'aiAreaCm2': aiAreaCm2,
      'aiLengthCm': aiLengthCm,
      'aiWidthCm': aiWidthCm,
      'aiDepthCm': aiDepthCm,
      'aiTissuePercentages': aiTissuePercentages,
      'aiPolygonJson': aiPolygonJson,
      'finalAreaCm2': finalAreaCm2,
      'finalLengthCm': finalLengthCm,
      'finalWidthCm': finalWidthCm,
      'finalDepthCm': finalDepthCm,
      'finalTissuePercentages': finalTissuePercentages,
      'finalPolygonJson': finalPolygonJson,
      'exudateLevel': exudateLevel?.value,
      'woundEdge': woundEdge?.value,
      'periWoundSkin': periWoundSkin?.value,
      'infectionSigns': infectionSigns,
      'vssVascularity': vssVascularity,
      'vssPigmentation': vssPigmentation,
      'vssPliability': vssPliability,
      'vssHeight': vssHeight,
      'vssTotal': vssTotal,
      'nrsPainScore': nrsPainScore,
      'tunnelClockDirection': tunnelClockDirection,
      'tunnelDepthCm': tunnelDepthCm,
      'signedBy': signedBy,
      'signedAt': signedAt?.toIso8601String(),
      'signOffMethod': signOffMethod?.value,
      'notes': notes,
      'photoPath': photoPath,
      'protocolId': protocolId,
      'centerId': centerId,
      'deviceId': deviceId,
      'deviceUsageLogId': deviceUsageLogId,
      'concomitantMedications': concomitantMedications,
      'concomitantDiseases': concomitantDiseases,
      'aeRefs': aeRefs,
      'crfCompletionDeclaredAt': crfCompletionDeclaredAt?.toIso8601String(),
      'crfCompletedBy': crfCompletedBy,
      'crfCompletedByName': crfCompletedByName,
      'photoMetadataSnapshot': photoMetadataSnapshot,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Assessment copyWith({
    String? id,
    String? patientId,
    String? woundId,
    String? clinicianId,
    String? clinicianName,
    AssessmentStatus? status,
    double? aiAreaCm2,
    double? aiLengthCm,
    double? aiWidthCm,
    double? aiDepthCm,
    Map<String, double>? aiTissuePercentages,
    String? aiPolygonJson,
    double? finalAreaCm2,
    double? finalLengthCm,
    double? finalWidthCm,
    double? finalDepthCm,
    Map<String, double>? finalTissuePercentages,
    String? finalPolygonJson,
    ExudateLevel? exudateLevel,
    WoundEdge? woundEdge,
    PeriWoundSkin? periWoundSkin,
    String? infectionSigns,
    int? vssVascularity,
    int? vssPigmentation,
    int? vssPliability,
    int? vssHeight,
    int? vssTotal,
    int? nrsPainScore,
    String? tunnelClockDirection,
    double? tunnelDepthCm,
    String? signedBy,
    DateTime? signedAt,
    SignOffMethod? signOffMethod,
    String? notes,
    String? photoPath,
    String? protocolId,
    String? centerId,
    String? deviceId,
    String? deviceUsageLogId,
    List<Map<String, dynamic>>? concomitantMedications,
    List<Map<String, dynamic>>? concomitantDiseases,
    List<Map<String, dynamic>>? aeRefs,
    DateTime? crfCompletionDeclaredAt,
    String? crfCompletedBy,
    String? crfCompletedByName,
    Map<String, dynamic>? photoMetadataSnapshot,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Assessment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      woundId: woundId ?? this.woundId,
      clinicianId: clinicianId ?? this.clinicianId,
      clinicianName: clinicianName ?? this.clinicianName,
      status: status ?? this.status,
      aiAreaCm2: aiAreaCm2 ?? this.aiAreaCm2,
      aiLengthCm: aiLengthCm ?? this.aiLengthCm,
      aiWidthCm: aiWidthCm ?? this.aiWidthCm,
      aiDepthCm: aiDepthCm ?? this.aiDepthCm,
      aiTissuePercentages: aiTissuePercentages ?? this.aiTissuePercentages,
      aiPolygonJson: aiPolygonJson ?? this.aiPolygonJson,
      finalAreaCm2: finalAreaCm2 ?? this.finalAreaCm2,
      finalLengthCm: finalLengthCm ?? this.finalLengthCm,
      finalWidthCm: finalWidthCm ?? this.finalWidthCm,
      finalDepthCm: finalDepthCm ?? this.finalDepthCm,
      finalTissuePercentages: finalTissuePercentages ?? this.finalTissuePercentages,
      finalPolygonJson: finalPolygonJson ?? this.finalPolygonJson,
      exudateLevel: exudateLevel ?? this.exudateLevel,
      woundEdge: woundEdge ?? this.woundEdge,
      periWoundSkin: periWoundSkin ?? this.periWoundSkin,
      infectionSigns: infectionSigns ?? this.infectionSigns,
      vssVascularity: vssVascularity ?? this.vssVascularity,
      vssPigmentation: vssPigmentation ?? this.vssPigmentation,
      vssPliability: vssPliability ?? this.vssPliability,
      vssHeight: vssHeight ?? this.vssHeight,
      vssTotal: vssTotal ?? this.vssTotal,
      nrsPainScore: nrsPainScore ?? this.nrsPainScore,
      tunnelClockDirection: tunnelClockDirection ?? this.tunnelClockDirection,
      tunnelDepthCm: tunnelDepthCm ?? this.tunnelDepthCm,
      signedBy: signedBy ?? this.signedBy,
      signedAt: signedAt ?? this.signedAt,
      signOffMethod: signOffMethod ?? this.signOffMethod,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      protocolId: protocolId ?? this.protocolId,
      centerId: centerId ?? this.centerId,
      deviceId: deviceId ?? this.deviceId,
      deviceUsageLogId: deviceUsageLogId ?? this.deviceUsageLogId,
      concomitantMedications:
          concomitantMedications ?? this.concomitantMedications,
      concomitantDiseases: concomitantDiseases ?? this.concomitantDiseases,
      aeRefs: aeRefs ?? this.aeRefs,
      crfCompletionDeclaredAt:
          crfCompletionDeclaredAt ?? this.crfCompletionDeclaredAt,
      crfCompletedBy: crfCompletedBy ?? this.crfCompletedBy,
      crfCompletedByName: crfCompletedByName ?? this.crfCompletedByName,
      photoMetadataSnapshot:
          photoMetadataSnapshot ?? this.photoMetadataSnapshot,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
