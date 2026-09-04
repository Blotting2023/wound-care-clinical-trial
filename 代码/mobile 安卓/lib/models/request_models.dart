/// Request payloads used by providers -> services.
library;

/// Clinician confirmation of an AI-analyzed assessment.
/// Values override the AI results; if unchanged the AI values are copied.
///
/// GCP W3 — 把 CRF 必填三态字段搬到这里。
class ClinicianConfirmRequest {
  final double? finalAreaCm2;
  final double? finalLengthCm;
  final double? finalWidthCm;
  final String? finalPolygonJson;
  final Map<String, double>? finalTissuePercentages;
  final bool confirmedWithoutChange;
  final String? manualOverrideReason;

  // 临床评分（VSS / NRS / 创面分期等），写入 final* 字段用于前值对比。
  final int? nrsPainScore;
  final int? vssVascularity;
  final int? vssPigmentation;
  final int? vssPliability;
  final int? vssHeight;
  final int? vssTotal;
  final String? woundStage;

  /// GCP W3.2 — CRF 必填字段（ND/UN/NA 三态 list）。
  /// 每个 list 至少有一项的 `triState` ∈ {ND, UN, NA}。
  final List<Map<String, dynamic>>? concomitantMedications;
  final List<Map<String, dynamic>>? concomitantDiseases;
  final List<Map<String, dynamic>>? aeRefs;

  /// GCP W3.1 — 创面照片源数据快照（SHA256 + EXIF + 设备指纹）。
  /// V1 demo 阶段从 `CosUploader.I.uploadPhoto()` 模拟生成。
  final Map<String, dynamic>? photoMetadataSnapshot;

  const ClinicianConfirmRequest({
    this.finalAreaCm2,
    this.finalLengthCm,
    this.finalWidthCm,
    this.finalPolygonJson,
    this.finalTissuePercentages,
    this.confirmedWithoutChange = false,
    this.manualOverrideReason,
    this.nrsPainScore,
    this.vssVascularity,
    this.vssPigmentation,
    this.vssPliability,
    this.vssHeight,
    this.vssTotal,
    this.woundStage,
    this.concomitantMedications,
    this.concomitantDiseases,
    this.aeRefs,
    this.photoMetadataSnapshot,
  });

  Map<String, dynamic> toJson() {
    return {
      'finalAreaCm2': finalAreaCm2,
      'finalLengthCm': finalLengthCm,
      'finalWidthCm': finalWidthCm,
      'finalPolygonJson': finalPolygonJson,
      'finalTissuePercentages': finalTissuePercentages,
      'confirmedWithoutChange': confirmedWithoutChange,
      'manualOverrideReason': manualOverrideReason,
      'nrsPainScore': nrsPainScore,
      'vssVascularity': vssVascularity,
      'vssPigmentation': vssPigmentation,
      'vssPliability': vssPliability,
      'vssHeight': vssHeight,
      'vssTotal': vssTotal,
      'woundStage': woundStage,
      'concomitantMedications': concomitantMedications,
      'concomitantDiseases': concomitantDiseases,
      'aeRefs': aeRefs,
      'photoMetadataSnapshot': photoMetadataSnapshot,
    };
  }
}
