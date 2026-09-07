/// KMS 数据密钥解密客户端（任务卡 W4.2）。
///
/// V1 demo 阶段：完全 fake，直接返回"明文"（其实是派生密钥的占位）。
/// 真实接入时换成腾讯云 KMS SDK 或自实现 HMAC 派生：
///
///   1) SDK 调 `KMS.Decrypt(ciphertextBlob=...)`
///   2) 返回的 plaintext 用于本地 AES-GCM 解密创面照片 / ConsentForm PDF
///
/// 数据密钥本身用 KMS 主密钥（CMK）加密后存在数据库，App 端只持有
/// 密文 + 调用权限。Demo 阶段这个流程完全跳过。
library;

import '../config/cloud.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class KmsClient {
  final CloudConfig config;
  KmsClient({required this.config});

  static final KmsClient I = KmsClient._internal();
  KmsClient._internal() : config = CloudConfig.fromEnvironment();

  /// 解密一个密文 → 明文（V1 demo 阶段返回原密文 + 警告日志）
  Future<String> decryptString({required String ciphertext}) async {
    if (config.mode == CloudMode.real) {
      // TODO(V4): 调腾讯云 KMS.Decrypt
      throw UnsupportedError(
        'V4 才接真 KMS，当前 demo 配置 CLOUD_MODE=real 但客户端尚未实现，'
        '请先用 CLOUD_MODE=mock 跑通。',
      );
    }
    // Mock：直接反 base64，假装是解密结果
    try {
      return utf8.decode(base64Decode(ciphertext));
    } catch (_) {
      // 不是 base64 就当原文返回
      return ciphertext;
    }
  }

  /// V1 demo：派生一个稳定的"数据密钥"用于本地 AES 加密
  /// （生产环境不应在客户端派生密钥；密钥应只服务端持有）
  Future<List<int>> deriveDataKey({required String keyId}) async {
    if (config.mode == CloudMode.real) {
      throw UnsupportedError('V4 KMS 数据密钥尚未实现');
    }
    // 用 SHA256(keyId + "demo-salt") 当 32-byte key（占位）
    return sha256.convert(utf8.encode('$keyId|demo-salt')).bytes;
  }
}
