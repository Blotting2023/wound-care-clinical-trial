import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../config/cloud.dart';
import '../models/photo_metadata.dart';
import '../utils/photo_time.dart';

/// GCP W3.1 + W4.2 — 创面照片上传器（mock / real 模式自动路由）。
///
/// ## V1 demo 阶段（默认）
/// 走 mock：本地路径 + sha256 + 模拟 120ms 延时，**无需任何凭证**。
///
/// ## 真实接入（V4 规划）
/// 走真腾讯云 COS，需 `--dart-define` 注入 5 个变量：
///   - CLOUD_MODE=real
///   - COS_SECRET_ID / COS_SECRET_KEY / COS_BUCKET / COS_REGION
///
/// 真实模式下当前客户端**只占位**（抛 `UnsupportedError`），由后续 V4
/// 接腾讯云 COS SDK 或自实现 HMAC-SHA1 签名请求。
/// 接口契约（参数 / 返回类型）保持不变，避免上游大改。
class CosUploader {
  /// demo 校准卡尺寸（硬编码 2.0 cm × 2.0 cm）。
  static const double demoCardDimensionCm = 2.0;

  /// demo 校准卡识别码（生产阶段由 AI 模型识别）。
  static const String demoQcCardId = 'QC-CARD-DEMO-001';

  CosUploader();

  /// 单例，调用方复用同一实例即可。
  static final CosUploader I = CosUploader._internal();
  CosUploader._internal();

  /// W4.2 — 读取云配置（mock/real 自动判断）
  final CloudConfig _cloud = CloudConfig.fromEnvironment();

  /// 当前是否真实云模式（供 UI / 调试用）
  bool get isRealCloud => _cloud.isReadyForReal;

  /// 主入口：上传一张 [localPath] 的照片并返回不可篡改的元数据。
  ///
  /// [assessmentId] — 用于生成 cosKey 路径；
  /// [subjectCode] — 鉴认代码，便于跨表溯源；
  /// [capturedByRole] — demo 默认 'CRC'。
  Future<PhotoMetadata> uploadPhoto({
    required String localPath,
    required String assessmentId,
    String? subjectCode,
    String? capturedBy,
    String capturedByRole = 'CRC',
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw FileSystemException('照片文件不存在', localPath);
    }

    // 1. 读前 64 KB + SHA256（避免大图整读）
    final sha256Hash = await _sha256OfFirst64KB(file);

    // 2. 完整 EXIF + 时间（自动 strip GPS）
    final fullInfo = await readFullPhotoInfo(localPath);
    final exifJson = fullInfo?.exifJson ?? '{}';
    final capturedAt = fullInfo?.time?.takenAt ?? DateTime.now();
    final capturedTimeSource = fullInfo?.time?.source ?? 'now';

    // 3. 设备指纹（demo 实现：基于平台 + 目录稳定路径）
    final fp = await _deviceFingerprint();

    // 4. 文件大小
    final bytes = await file.length();

    // 5. 生成 COS key（时间格式化避免冒号被 URL 转义问题）
    final stamp = _safeTimestamp(capturedAt);
    final cosKey = '/original/$assessmentId/$stamp.jpg';
    final thumbKey = '/thumb/$assessmentId/$stamp.jpg';

    // 6. 上传（mock / real 路由）
    String? realUrl;
    if (_cloud.isReadyForReal) {
      realUrl = await _uploadToRealCos(
        localPath: localPath,
        cosKey: cosKey,
      );
    } else {
      // mock 模式：模拟 120ms 网络延时
      await Future.delayed(const Duration(milliseconds: 120));
    }

    return PhotoMetadata(
      cosKey: cosKey,
      thumbKey: thumbKey,
      sha256: sha256Hash,
      exifJson: exifJson,
      deviceFingerprint: fp,
      deviceModel: _deviceModel(),
      osVersion: _osVersion(),
      appVersion: '0.1.0',
      capturedAt: capturedAt,
      capturedTimeSource: capturedTimeSource,
      capturedBy: capturedBy,
      capturedByRole: capturedByRole,
      qcCardId: demoQcCardId,
      qcPassed: true,
      cardDimensionCm: demoCardDimensionCm,
      gpsStripped: true,
      mimeType: _guessMimeType(localPath),
      bytes: bytes,
      uploadedAt: DateTime.now().toUtc(),
      subjectCode: subjectCode,
      remoteUrl: realUrl, // null 表示 mock 模式
    );
  }

  /// 真云上传占位（V4 接入）。
  ///
  /// 接口契约：返回 COS 远程 URL（让 PhotoMetadata 持有）。
  /// 当前实现抛 `UnsupportedError`，由 V4 替换。
  Future<String> _uploadToRealCos({
    required String localPath,
    required String cosKey,
  }) async {
    // V4 计划：
    // 1) 用 `dio.put` 发到 `https://{bucket}-{appid}.cos.{region}.myqcloud.com{cosKey}`
    // 2) Header 带 `x-cos-security-token` (如果用临时密钥)
    // 3) Body = 文件字节流
    // 4) 服务端返回 200 后用 `https://...{cosKey}` 作为 remoteUrl
    throw UnsupportedError(
      '真 COS 上传尚未实现（V4 任务）。当前 cos_uploader 仍走 mock；'
      '如需启用，请把 CLOUD_MODE 改为 mock 或先在 V4 接腾讯云 SDK。',
    );
  }

  /// 旧版兼容接口：仅算 sha256（保持现有 photo_test 工具脚本可用）。
  Future<String> sha256OfFile(String localPath) async {
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  // ─────────── 私有 ───────────

  Future<String> _sha256OfFirst64KB(File file) async {
    final raf = await file.open();
    try {
      const len = 64 * 1024;
      final bytes = await raf.read(len);
      return sha256.convert(bytes).toString();
    } finally {
      await raf.close();
    }
  }

  String _safeTimestamp(DateTime t) {
    // 把 2026-09-04T15:30:12Z 改成 2026-09-04T15-30-12Z 安全文件名形式。
    return t.toUtc().toIso8601String().replaceAll(':', '-');
  }

  /// 设备指纹 — demo 阶段基于平台 + 临时目录路径哈希合成。
  /// 真实场景应使用 device_info_plus + UUID 持久化（生产阶段迁移）。
  Future<String> _deviceFingerprint() async {
    final plat = Platform.operatingSystem;
    final ver = Platform.operatingSystemVersion;
    // 用 path_provider 临时目录哈希得到一个稳定的 per-install 串。
    String rootSig = 'noTmpDir';
    try {
      final dir = await getTemporaryDirectory();
      final h = sha256.convert(utf8.encode(dir.path)).toString();
      rootSig = h.substring(0, 12);
    } catch (_) {/* 兜底 */}
    return '$plat-${ver.replaceAll(' ', '_')}-$rootSig';
  }

  String _deviceModel() {
    final os = Platform.operatingSystem;
    if (os == 'ios') {
      // iOS 模拟器实际无法直接读 model identifier；
      // demo 阶段写死 'iPhone Simulator'，生产再接 device_info_plus。
      return 'iPhone Simulator';
    }
    if (os == 'macos') return 'Mac (desktop)';
    if (os == 'android') return 'Android Device';
    return os;
  }

  String _osVersion() {
    final v = Platform.operatingSystemVersion;
    if (Platform.operatingSystem == 'ios') return 'iOS $v (Simulator)';
    if (Platform.operatingSystem == 'macos') return 'macOS $v';
    if (Platform.operatingSystem == 'android') return 'Android $v';
    return v;
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
