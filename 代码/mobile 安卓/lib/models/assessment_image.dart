import 'enums.dart';
import 'photo_metadata.dart';

/// Model for captured assessment images, including calibration and wound shots.
///
/// GCP W3 — 加挂完整的 [PhotoMetadata]（COS 路径 + sha256 + EXIF + 设备指纹 +
/// QC 卡 + 时间戳），保证创面照片作为影像源数据可独立溯源。
class AssessmentImage {
  final String id;
  final String assessmentId;
  final ImageType imageType;
  final String? localPath; // on-device cache path
  final String? remoteUrl; // server URL after upload
  final DateTime capturedAt;

  /// GCP W3.1 — 创面照片作为影像源数据必填元数据。
  ///
  /// 含 COS 路径、SHA256、EXIF、设备指纹、校准卡 ID、时间来源等。
  /// V1 demo 阶段从 `CosUploader.I.uploadPhoto()` 模拟生成。
  final PhotoMetadata? metadata;

  const AssessmentImage({
    required this.id,
    required this.assessmentId,
    required this.imageType,
    this.localPath,
    this.remoteUrl,
    required this.capturedAt,
    this.metadata,
  });

  factory AssessmentImage.fromJson(Map<String, dynamic> json) {
    return AssessmentImage(
      id: json['id'] as String,
      assessmentId: json['assessmentId'] as String,
      imageType: ImageType.fromString(json['imageType'] as String? ?? 'woundCapture'),
      localPath: json['localPath'] as String?,
      remoteUrl: json['remoteUrl'] as String?,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      metadata: json['metadata'] != null
          ? PhotoMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assessmentId': assessmentId,
      'imageType': imageType.value,
      'localPath': localPath,
      'remoteUrl': remoteUrl,
      'capturedAt': capturedAt.toIso8601String(),
      'metadata': metadata?.toJson(),
    };
  }

  AssessmentImage copyWith({
    String? id,
    String? assessmentId,
    ImageType? imageType,
    String? localPath,
    String? remoteUrl,
    DateTime? capturedAt,
    PhotoMetadata? metadata,
  }) {
    return AssessmentImage(
      id: id ?? this.id,
      assessmentId: assessmentId ?? this.assessmentId,
      imageType: imageType ?? this.imageType,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      capturedAt: capturedAt ?? this.capturedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
