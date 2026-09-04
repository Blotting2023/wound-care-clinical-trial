import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../models/photo_metadata.dart';
import '../utils/photo_time.dart';

/// GCP W3.1 — V1 demo 阶段的 "COS 上传器"。
///
/// ## 关键约束（来自 `V1开发任务卡.md` W3.1）
///
/// > `lib/services/cos_uploader.dart` 🆕 — 走腾讯云 COS（V1 demo
/// > 阶段用本地路径 + sha256 模拟）。
///
/// ## 模拟逻辑（V1）
///
/// 1. 读前 64 KB → 算 SHA256（避免大文件整体读入）
/// 2. 生成 cosKey = `/original/{assessmentId}/{ISO8601-safe}.jpg`
///    + thumbKey = `/thumb/{assessmentId}/{ISO8601-safe}.jpg`
/// 3. 模拟延时 120 ms（等效一次网络往返）
/// 4. 返回完整 [PhotoMetadata] 给调用方
///
/// 真实接入时把"模拟"换成腾讯云 COS SDK 或自实现 HMAC-SHA1 签名请求，
/// 路径规则保持不变以兼容存储分层。
class CosUploader {
  /// demo 校准卡尺寸（硬编码 2.0 cm × 2.0 cm）。
  static const double demoCardDimensionCm = 2.0;

  /// demo 校准卡识别码（生产阶段由 AI 模型识别）。
  static const String demoQcCardId = 'QC-CARD-DEMO-001';

  CosUploader();

  /// 单例，调用方复用同一实例即可。
  static final CosUploader I = CosUploader._internal();
  CosUploader._internal();

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

    // 6. 模拟上传延时（一次网络往返）
    await Future.delayed(const Duration(milliseconds: 120));

    return PhotoMetadata(
      cosKey: cosKey,
      thumbKey: thumbKey,
      sha256: sha256Hash,
      exifJson: exifJson,
      deviceFingerprint: fp,
      deviceModel: _deviceModel(),
      osVersion: _osVersion(),
      appVersion: '0.1.0', // demo 写死；生产从 package_info_plus 读
      capturedAt: capturedAt,
      capturedTimeSource: capturedTimeSource,
      capturedBy: capturedBy,
      capturedByRole: capturedByRole,
      qcCardId: demoQcCardId,
      qcPassed: true,
      cardDimensionCm: demoCardDimensionCm,
      gpsStripped: true, // invariant
      mimeType: _guessMimeType(localPath),
      bytes: bytes,
      uploadedAt: DateTime.now().toUtc(),
      subjectCode: subjectCode,
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
