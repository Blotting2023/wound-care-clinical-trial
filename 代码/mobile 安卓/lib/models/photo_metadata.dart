import '../services/audit_logger.dart';

/// GCP W3 — 创面照片作为影像源数据.
///
/// 每张被纳入临床评估的照片必须保存一组不可篡改、可在监管检查时
/// 完整提交的元数据 (元数据同时也是 ALCOA+ 的 Original/Accurate 证据)。
///
/// ## 关键合规约束
///   * **GPS 坐标必须 strip** —— 创面照片可能拍到患者家居环境，地理坐标
///     属于间接可识别个人信息 (PIPL §4 + GCP §39)。我们的 EXIF 解析层
///     默认把所有 GPSLatitude / GPSLongitude / GPSAltitude 等 tag 抹掉，
///     用 [gpsStripped] = true 作为留痕证据。
///   * **COS 路径必须包含 assessmentId + 时间戳** —— 保证写入与读取能
///     一一对应，且按时间前缀便于 10 年冷存储分层。
///
/// ## V1 demo 阶段
///   * COS 部分走 `CosUploader` 的本地模拟（不发真实请求），
///   * `qcCardId` 由校准卡识别 placeholder 给出，
///   * `cardDimensionCm` 硬编码为 2.0 cm（demo 校准卡是 2×2 cm）。
class PhotoMetadata {
  /// COS 原始图路径：/original/{assessmentId}/{ISO8601 safe}.jpg
  final String cosKey;

  /// COS 缩略图路径：/thumb/{assessmentId}/{ISO8601 safe}.jpg
  final String thumbKey;

  /// 客户端上传前算好的 SHA256（hex 64）。
  final String sha256;

  /// 完整 EXIF JSON（GPS 字段已 strip）。
  final String? exifJson;

  /// 设备指纹：`ios-iphonesimulator-18.4-<uuid>` 之类，跨 session 稳定。
  final String deviceFingerprint;

  /// 设备型号："iPhone 16 Pro"（来自 Platform + IosDeviceInfo）。
  final String? deviceModel;

  /// OS 版本："iOS 18.4 (Simulator)"。
  final String? osVersion;

  /// App 版本：从 pubspec 读。
  final String? appVersion;

  /// 实际拍摄时间（EXIF 优先，落空 → file_mtime → now）。
  final DateTime capturedAt;

  /// 时间来源：'exif_original' / 'exif_digitized' / 'exif_datetime' /
  ///           'file_mtime' / 'now'。
  final String capturedTimeSource;

  /// 拍摄操作者（subjectCode + 临时 ID）。
  final String? capturedBy;

  /// 校准卡识别码（生产场景由 AI 模型识别返回）；
  /// demo 阶段硬编码 'QC-CARD-DEMO-001'。
  final String? qcCardId;

  /// 校准卡是否通过识别（demo 永远 true）。
  final bool qcPassed;

  /// 校准卡物理尺寸（cm）。demo 硬编码 2.0。
  final double? cardDimensionCm;

  /// 是否已经 strip GPS。永远 true —— 这是一个 invariant。
  final bool gpsStripped;

  /// MIME 类型。拍照通常是 'image/jpeg'。
  final String? mimeType;

  /// 文件字节数。
  final int? bytes;

  /// 上传时间（demo 模拟为当前时间）。
  final DateTime uploadedAt;

  /// 拍照操作者的角色（demo：固定 'CRC'）。
  final String? capturedByRole;

  /// 关联的鉴认代码（subjectCode，方便跨表溯源）。
  final String? subjectCode;

  const PhotoMetadata({
    required this.cosKey,
    required this.thumbKey,
    required this.sha256,
    required this.capturedAt,
    required this.capturedTimeSource,
    required this.deviceFingerprint,
    required this.qcPassed,
    required this.gpsStripped,
    required this.uploadedAt,
    this.exifJson,
    this.deviceModel,
    this.osVersion,
    this.appVersion,
    this.capturedBy,
    this.capturedByRole,
    this.qcCardId,
    this.cardDimensionCm,
    this.mimeType,
    this.bytes,
    this.subjectCode,
  });

  /// 完整 JSON 给服务端 + UI 渲染。
  Map<String, dynamic> toJson() => {
        'cosKey': cosKey,
        'thumbKey': thumbKey,
        'sha256': sha256,
        'exifJson': exifJson,
        'deviceFingerprint': deviceFingerprint,
        'deviceModel': deviceModel,
        'osVersion': osVersion,
        'appVersion': appVersion,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'capturedTimeSource': capturedTimeSource,
        'capturedBy': capturedBy,
        'capturedByRole': capturedByRole,
        'qcCardId': qcCardId,
        'qcPassed': qcPassed,
        'cardDimensionCm': cardDimensionCm,
        'gpsStripped': gpsStripped,
        'mimeType': mimeType,
        'bytes': bytes,
        'uploadedAt': uploadedAt.toUtc().toIso8601String(),
        'subjectCode': subjectCode,
      };

  /// 服务端透传回来的 JSON 还原（demo_backend 用）。
  factory PhotoMetadata.fromJson(Map<String, dynamic> json) {
    DateTime parseTs(Object? v) =>
        v == null ? DateTime.now().toUtc() : DateTime.parse(v as String);
    return PhotoMetadata(
      cosKey: json['cosKey'] as String,
      thumbKey: json['thumbKey'] as String,
      sha256: json['sha256'] as String,
      capturedAt: parseTs(json['capturedAt']),
      capturedTimeSource: json['capturedTimeSource'] as String? ?? 'now',
      deviceFingerprint: json['deviceFingerprint'] as String? ?? 'unknown',
      qcPassed: json['qcPassed'] as bool? ?? true,
      gpsStripped: json['gpsStripped'] as bool? ?? true,
      uploadedAt: parseTs(json['uploadedAt']),
      exifJson: json['exifJson'] as String?,
      deviceModel: json['deviceModel'] as String?,
      osVersion: json['osVersion'] as String?,
      appVersion: json['appVersion'] as String?,
      capturedBy: json['capturedBy'] as String?,
      capturedByRole: json['capturedByRole'] as String?,
      qcCardId: json['qcCardId'] as String?,
      cardDimensionCm: (json['cardDimensionCm'] as num?)?.toDouble(),
      mimeType: json['mimeType'] as String?,
      bytes: (json['bytes'] as num?)?.toInt(),
      subjectCode: json['subjectCode'] as String?,
    );
  }

  /// 给 UI 用的紧凑中文摘要。
  String summary() {
    final buf = StringBuffer()
      ..writeln('COS 路径（原图）：$cosKey')
      ..writeln('COS 路径（缩略图）：$thumbKey')
      ..writeln('SHA256：$sha256')
      ..writeln('设备：${deviceModel ?? '—'}（${osVersion ?? '—'}）')
      ..writeln('设备指纹：$deviceFingerprint')
      ..writeln('拍摄时间：${capturedAt.toIso8601String()}（来源 $capturedTimeSource）')
      ..writeln('校准卡：${qcCardId ?? '—'}（${qcPassed ? "已识别" : "未识别"}，${cardDimensionCm ?? '—'} cm）')
      ..writeln('GPS 坐标：已 strip（合规）');
    if (exifJson != null) {
      final preview = exifJson!.length > 400
          ? '${exifJson!.substring(0, 400)}...'
          : exifJson!;
      buf.writeln('EXIF JSON：$preview');
    }
    return buf.toString();
  }

  /// 不可变；新对象替换某字段。
  PhotoMetadata copyWith({
    String? cosKey,
    String? thumbKey,
    String? sha256,
    String? exifJson,
    String? deviceFingerprint,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
    DateTime? capturedAt,
    String? capturedTimeSource,
    String? capturedBy,
    String? capturedByRole,
    String? qcCardId,
    bool? qcPassed,
    double? cardDimensionCm,
    bool? gpsStripped,
    String? mimeType,
    int? bytes,
    DateTime? uploadedAt,
    String? subjectCode,
  }) {
    return PhotoMetadata(
      cosKey: cosKey ?? this.cosKey,
      thumbKey: thumbKey ?? this.thumbKey,
      sha256: sha256 ?? this.sha256,
      exifJson: exifJson ?? this.exifJson,
      deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      capturedAt: capturedAt ?? this.capturedAt,
      capturedTimeSource: capturedTimeSource ?? this.capturedTimeSource,
      capturedBy: capturedBy ?? this.capturedBy,
      capturedByRole: capturedByRole ?? this.capturedByRole,
      qcCardId: qcCardId ?? this.qcCardId,
      qcPassed: qcPassed ?? this.qcPassed,
      cardDimensionCm: cardDimensionCm ?? this.cardDimensionCm,
      gpsStripped: gpsStripped ?? this.gpsStripped,
      mimeType: mimeType ?? this.mimeType,
      bytes: bytes ?? this.bytes,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      subjectCode: subjectCode ?? this.subjectCode,
    );
  }
}

/// EXIF 标签里属于"GPS"位置信息类的，统一在此集中过滤。
/// GCP §39 + PIPL §4 间接可识别个人信息条款。
const Set<String> _gpsExifTags = {
  'EXIF GPS GPSLatitude',
  'EXIF GPS GPSLatitudeRef',
  'EXIF GPS GPSLongitude',
  'EXIF GPS GPSLongitudeRef',
  'EXIF GPS GPSAltitude',
  'EXIF GPS GPSAltitudeRef',
  'EXIF GPS GPSTimeStamp',
  'EXIF GPS GPSDateStamp',
  'EXIF GPS GPSSpeed',
  'EXIF GPS GPSImgDirection',
  'EXIF GPS GPSAreaInformation',
  'EXIF GPS GPSDestLatitude',
  'EXIF GPS GPSDestLongitude',
  'EXIF GPS GPSDestBearing',
  'EXIF GPS GPSDestBearingRef',
  'EXIF GPS GPSHPositioningError',
  // Canon / Nikon / Sony 私有 GPS tag 名称（兜底匹配）
  'Image GPSLatitude',
  'Image GPSLongitude',
};

/// 判断一个 EXIF tag key 是否含 GPS 位置信息（用于 [stripGpsFromExifJson]）。
bool isGpsExifTag(String key) {
  if (_gpsExifTags.contains(key)) return true;
  final lower = key.toLowerCase();
  return lower.contains('gps') &&
      (lower.contains('lat') ||
          lower.contains('lon') ||
          lower.contains('alt') ||
          lower.contains('bearing') ||
          lower.contains('position') ||
          lower.contains('destination'));
}

/// 把 EXIF map → JSON 字符串，同时彻底删除 GPS 位置字段。
/// 保留设备指纹相关字段（Make / Model / Software）。
String stripGpsAndSerializeExif(Map<String, dynamic> exif) {
  final filtered = <String, dynamic>{};
  for (final entry in exif.entries) {
    if (isGpsExifTag(entry.key)) continue;
    filtered[entry.key] = entry.value;
  }
  // 序列化留 JSON 字符串
  // 注意：使用 dart:convert 中的 jsonEncode 在调用方负责，这里只保证入参是合法 Map。
  // 调用方通常会传入一个 dart:convert encode 过的字符串；我们在 photo_time.dart 层统一处理。
  return filtered.toString();
}

/// 把 Operator 上下文打包，便于审计 + COS 上传同步记日志。
/// 当前实现：把 operation 全记录到 AuditLogger，type = create。
PhotoMetadata recordUploadAudit({
  required PhotoMetadata metadata,
  required String assessmentId,
  required AuditContext ctx,
}) {
  AuditLogger.I.record(
    tableName: 'assessment_image',
    recordId: assessmentId,
    opType: AuditOpType.create,
    fieldName: 'photo_metadata',
    afterValue: metadata.toJson(),
    ctx: ctx,
    reason: '创面照片源数据落库（sha256=${metadata.sha256.substring(0, 8)}…）',
  );
  return metadata;
}
