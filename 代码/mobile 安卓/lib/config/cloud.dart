/// 腾讯云 / S3 兼容的对象存储配置（任务卡 W4.2）。
///
/// V1 demo 阶段：默认走 mock 模式（本地路径 + sha256），无需任何凭证。
/// 真实接入时通过 `--dart-define` 注入：
///
/// ```
/// flutter build ios --simulator --debug \
///   --dart-define=CLOUD_MODE=real \
///   --dart-define=COS_SECRET_ID=AKIDxxxxx \
///   --dart-define=COS_SECRET_KEY=xxxxx \
///   --dart-define=COS_BUCKET=wound-clinical-trial-1300000000 \
///   --dart-define=COS_REGION=ap-guangzhou
/// ```
///
/// 地域约束：医疗合规必须 `ap-guangzhou` 或 `ap-shanghai`（白名单）。
library;

enum CloudMode { mock, real }

class CloudConfig {
  final CloudMode mode;
  final String secretId;
  final String secretKey;
  final String bucket;
  final String region;
  final String? kmsKeyId;

  const CloudConfig({
    required this.mode,
    required this.secretId,
    required this.secretKey,
    required this.bucket,
    required this.region,
    this.kmsKeyId,
  });

  /// 加载 dart-define；缺凭证时静默降级到 mock。
  static CloudConfig fromEnvironment() {
    const modeRaw = String.fromEnvironment('CLOUD_MODE', defaultValue: 'mock');
    final mode = modeRaw == 'real' ? CloudMode.real : CloudMode.mock;
    const secretId = String.fromEnvironment('COS_SECRET_ID', defaultValue: '');
    const secretKey = String.fromEnvironment('COS_SECRET_KEY', defaultValue: '');
    const bucket = String.fromEnvironment('COS_BUCKET', defaultValue: '');
    const region = String.fromEnvironment('COS_REGION',
        defaultValue: 'ap-guangzhou');
    const kmsKeyId = String.fromEnvironment('KMS_KEY_ID', defaultValue: '');
    return CloudConfig(
      mode: mode,
      secretId: secretId,
      secretKey: secretKey,
      bucket: bucket,
      region: region,
      kmsKeyId: kmsKeyId.isEmpty ? null : kmsKeyId,
    );
  }

  bool get isReadyForReal =>
      mode == CloudMode.real &&
      secretId.isNotEmpty &&
      secretKey.isNotEmpty &&
      bucket.isNotEmpty &&
      _isAllowedRegion(region);

  /// 医疗合规白名单：仅允许广州/上海/北京（具体看老胡跟腾讯云签的白名单）。
  static bool _isAllowedRegion(String r) {
    const allowed = {
      'ap-guangzhou',
      'ap-shanghai',
      'ap-beijing',
      'ap-beijing-2',
    };
    return allowed.contains(r);
  }

  /// 给 UI 展示用：当前是否真云
  String get modeLabel => mode == CloudMode.real ? '真云（COS）' : '本地 mock';

  /// 给 UI 展示用：地域标签
  String get regionLabel => 'COS 地域: $region';
}
