/// Trial-protocol document — 方案 / 方案修正案附件（Word / PDF）。
///
/// GCP 2022 第 28 号 第四章：试验方案必须版本化、签字盖章并经 IRB
/// 批准后方可执行；每次修版都应保留历史版本可溯源。
///
/// V1 demo：本模型只存**元数据**（文件名/大小/类型/上传人/版本），
/// 文件字节在 V4 接入对象存储（腾讯云 COS）后落 `/protocol/{id}/` 前缀，
/// 届时补充 `remoteUrl` 支持在线预览 / 下载。
class ProtocolDocument {
  final String id;
  final String protocolId;
  final String fileName; // 含扩展名，e.g. "WOUND-2026-A_v1.1.pdf"
  final String fileExt; // pdf / doc / docx（小写）
  final int fileSizeBytes;
  final String version; // 关联的方案版本，e.g. "1.1"
  final String? note; // 备注（如"修版原因 / IRB 批件号"）
  final String uploadedBy; // 操作人（operatorId）
  final String? uploadedByName;
  final DateTime uploadedAt;
  final String? remoteUrl; // V4 预留：COS 对象地址

  const ProtocolDocument({
    required this.id,
    required this.protocolId,
    required this.fileName,
    required this.fileExt,
    required this.fileSizeBytes,
    required this.version,
    this.note,
    required this.uploadedBy,
    this.uploadedByName,
    required this.uploadedAt,
    this.remoteUrl,
  });

  bool get isPdf => fileExt == 'pdf';

  factory ProtocolDocument.fromJson(Map<String, dynamic> json) {
    return ProtocolDocument(
      id: json['id'] as String,
      protocolId: json['protocolId'] as String,
      fileName: json['fileName'] as String? ?? '',
      fileExt:
          (json['fileExt'] as String? ?? '').toLowerCase(),
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      version: json['version'] as String? ?? '1.0',
      note: json['note'] as String?,
      uploadedBy: json['uploadedBy'] as String? ?? '',
      uploadedByName: json['uploadedByName'] as String?,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      remoteUrl: json['remoteUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'protocolId': protocolId,
        'fileName': fileName,
        'fileExt': fileExt,
        'fileSizeBytes': fileSizeBytes,
        'version': version,
        'note': note,
        'uploadedBy': uploadedBy,
        'uploadedByName': uploadedByName,
        'uploadedAt': uploadedAt.toIso8601String(),
        'remoteUrl': remoteUrl,
      };

  /// 人类可读的文件大小。
  String get fileSizeLabel {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
