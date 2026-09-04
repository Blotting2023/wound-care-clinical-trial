import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/assessment.dart';
import '../models/enums.dart';
import '../providers/assessment_provider.dart';
import '../widgets/app_ui.dart';
import '../widgets/assessment_photo_view.dart';

/// 评估记录只读详情页：从部位页"评估历史"进入，展示该次评估完整数据。
/// 全部只读，无任何编辑控件（合规：锁定记录不可篡改）。
class AssessmentRecordScreen extends StatefulWidget {
  final Assessment assessment;
  const AssessmentRecordScreen({super.key, required this.assessment});

  @override
  State<AssessmentRecordScreen> createState() => _AssessmentRecordScreenState();
}

class _AssessmentRecordScreenState extends State<AssessmentRecordScreen> {
  Map<String, dynamic>? _photoMeta;
  bool _photoMetaLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPhotoMeta();
  }

  Future<void> _loadPhotoMeta() async {
    final snap = widget.assessment.photoMetadataSnapshot;
    if (snap != null) {
      setState(() => _photoMeta = snap);
      return;
    }
    setState(() => _photoMetaLoading = true);
    try {
      final provider = context.read<AssessmentProvider>();
      final md = await provider.loadPhotoMetadata(widget.assessment.id);
      if (md != null && mounted) {
        setState(() => _photoMeta = md['photoMetadata'] as Map<String, dynamic>?);
      }
    } catch (_) {/* 忽略 — 详情页仍可打开 */}
    if (mounted) setState(() => _photoMetaLoading = false);
  }

  /// "下载原始" 按钮 — V1 demo 阶段用 AlertDialog 显示格式化 JSON。
  /// 生产场景换成 zipStream 流式下载（jpg + exif.json + photo_metadata.json）。
  Future<void> _showPhotoMetadata() async {
    final md = _photoMeta;
    if (md == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('该评估没有照片源数据快照'),
      ));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _PhotoMetadataDialog(metadata: md),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assessment;
    final area = a.finalAreaCm2 ?? a.aiAreaCm2;
    final length = a.finalLengthCm ?? a.aiLengthCm;
    final width = a.finalWidthCm ?? a.aiWidthCm;
    final tissue = a.finalTissuePercentages ?? a.aiTissuePercentages;
    final modified = a.finalAreaCm2 != null && a.aiAreaCm2 != a.finalAreaCm2;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('评估记录'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Center(child: Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.textHint)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _buildHeaderCard(a),
          const SizedBox(height: 12),

          // 创面照片（只读回看，叠加轮廓与长宽指示线）
          if (a.aiPolygonJson != null || a.photoPath != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('创面照片',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  AssessmentPhotoView(
                    photoPath: a.photoPath,
                    polygonJson: a.finalPolygonJson ?? a.aiPolygonJson,
                    aiLengthCm: a.finalLengthCm ?? a.aiLengthCm,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // GCP W3.1 — 创面照片源数据（SHA256 + COS 路径 + 设备指纹 + 拍摄时间）
          if (_photoMeta != null || _photoMetaLoading) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fingerprint_rounded,
                          size: 18, color: AppTheme.actionBlue),
                      const SizedBox(width: 6),
                      const Text('创面照片源数据（W3.1）',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('下载原始'),
                        onPressed: _photoMeta == null ? null : _showPhotoMetadata,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_photoMetaLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_photoMeta != null) ...[
                    _infoRow('SHA256',
                        '${(_photoMeta!['sha256'] as String? ?? '—').substring(
                                0,
                                ((_photoMeta!['sha256'] as String? ?? '').length)
                                    .clamp(0, 16))}…'),
                    _infoRow('COS 原图',
                        _photoMeta!['cosKey'] as String? ?? '—'),
                    _infoRow('缩略图',
                        _photoMeta!['thumbKey'] as String? ?? '—'),
                    _infoRow('设备',
                        '${_photoMeta!['deviceModel'] ?? '—'}（${_photoMeta!['osVersion'] ?? '—'}）'),
                    _infoRow('设备指纹',
                        _photoMeta!['deviceFingerprint'] as String? ?? '—'),
                    _infoRow('拍摄时间',
                        '${_photoMeta!['capturedAt'] ?? '—'}（${_photoMeta!['capturedTimeSource'] ?? '—'}）'),
                    _infoRow('校准卡',
                        '${_photoMeta!['qcCardId'] ?? '—'}（${_photoMeta!['qcPassed'] == true ? "已识别" : "未识别"}，${_photoMeta!['cardDimensionCm'] ?? '—'} cm）'),
                    _infoRow('GPS', '已 strip（合规 · 间接可识别个人信息）'),
                    _infoRow('拍摄者',
                        '${_photoMeta!['capturedByRole'] ?? '—'} · ${_photoMeta!['capturedBy'] ?? '—'}'),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.noticeBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.cloud_done_outlined,
                              size: 16, color: AppTheme.actionBlue),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'V1 demo 阶段 · COS 上传走本地模拟 · 真实阶段改走腾讯云',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.actionBlue,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 测量结果
          if (area != null || length != null) ...[
            AppCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('测量结果',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (modified) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.statusPendingSign.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('医生已修正',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.statusPendingSign,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  MetricTriple(
                    metrics: [
                      (label: '面积', value: (area ?? 0).toStringAsFixed(1), unit: 'cm²'),
                      (label: '最长径', value: (length ?? 0).toStringAsFixed(1), unit: 'cm'),
                      (label: '宽度', value: (width ?? 0).toStringAsFixed(1), unit: 'cm'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 组织构成
          if (tissue != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('组织构成',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  TissueBar(
                    granulation: _tissueVal(tissue, 'granulation'),
                    slough: _tissueVal(tissue, 'slough'),
                    necrosis: _tissueVal(tissue, 'necrosis'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 评分量表
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('评分量表',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _scoreRow('NRS 疼痛评分', a.nrsPainScore?.toString(), suffix: '分'),
                _scoreRow('VSS 血管分布', a.vssVascularity?.toString(), suffix: '分'),
                _scoreRow('VSS 色素沉着', a.vssPigmentation?.toString(), suffix: '分'),
                _scoreRow('VSS 柔软度', a.vssPliability?.toString(), suffix: '分'),
                _scoreRow('VSS 厚度', a.vssHeight?.toString(), suffix: '分'),
                Divider(height: 20, color: AppTheme.cardBorder),
                Row(
                  children: [
                    Text('VSS 总分', style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${a.vssTotal ?? '—'} 分',
                        style: AppTheme.body.copyWith(
                            color: AppTheme.actionBlue,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 签名信息
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('签名信息',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (a.crfCompletionDeclaredAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.statusLocked
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified_rounded,
                                size: 14, color: AppTheme.statusLocked),
                            SizedBox(width: 4),
                            Text('CRF 已声明',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.statusLocked,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow('记录状态', _statusLabel(a.status)),
                _infoRow('签名医生', a.signedBy ?? '—'),
                _infoRow('签名时间',
                    a.signedAt != null ? _fmtDateTime(a.signedAt!) : '—'),
                _infoRow('签名方式', a.signOffMethod != null ? 'PIN 签名' : '—'),
                _infoRow('评估医生', a.clinicianName ?? '—'),
                if (a.crfCompletionDeclaredAt != null) ...[
                  Divider(height: 20, color: AppTheme.cardBorder),
                  _infoRow('CRF 声明',
                      _fmtDateTime(a.crfCompletionDeclaredAt!)),
                  _infoRow('CRF 声明 PI',
                      a.crfCompletedByName ?? a.crfCompletedBy ?? '—'),
                ],
              ],
            ),
          ),

          // GCP W3.2 — CRF 字段只读展示
          if (_hasCrf(a)) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CRF 字段三态',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildCrfRow('合并用药', a.concomitantMedications),
                  const SizedBox(height: 8),
                  _buildCrfRow('合并疾病', a.concomitantDiseases),
                  const SizedBox(height: 8),
                  _buildCrfRow('AE 占位', a.aeRefs),
                ],
              ),
            ),
          ],

          // 备注
          if (a.notes != null && a.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('备注',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(a.notes!, style: AppTheme.caption.copyWith(height: 1.7)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          Center(
            child: Text('本记录已锁定 · 只读查看 · 修改需修订流程（21 CFR Part 11）',
                style: AppTheme.micro),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Assessment a) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.actionBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.description_outlined,
                color: AppTheme.actionBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('评估 · ${_fmtDate(a.createdAt)}',
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('创建于 ${_fmtDateTime(a.createdAt)}',
                    style: AppTheme.micro),
              ],
            ),
          ),
          _statusChip(a.status),
        ],
      ),
    );
  }

  Widget _scoreRow(String label, String? value, {String suffix = ''}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: AppTheme.caption),
          const Spacer(),
          Text(value != null ? '$value$suffix' : '—',
              style: AppTheme.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: value != null ? AppTheme.textPrimary : AppTheme.textHint)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: AppTheme.micro)),
          Expanded(child: Text(value, style: AppTheme.caption)),
        ],
      ),
    );
  }

  Widget _statusChip(AssessmentStatus status) {
    switch (status) {
      case AssessmentStatus.locked:
        return const StatusChip.locked();
      case AssessmentStatus.pendingSignature:
        return const StatusChip.pendingSign();
      default:
        return StatusChip.custom(label: _statusLabel(status));
    }
  }

  String _statusLabel(AssessmentStatus status) {
    switch (status) {
      case AssessmentStatus.draft:
        return '草稿';
      case AssessmentStatus.pendingSignature:
        return '待签名';
      case AssessmentStatus.locked:
        return '已锁定';
      case AssessmentStatus.archived:
        return '已归档';
    }
  }

  double _tissueVal(Map<String, double> tissue, String key) {
    final v = tissue[key] ?? tissue['${key}_red_percent'];
    if (v != null) return (v <= 1.0 ? v : v / 100.0).clamp(0.0, 1.0);
    for (final e in tissue.entries) {
      if (e.key.contains(key)) {
        return (e.value <= 1.0 ? e.value : e.value / 100.0).clamp(0.0, 1.0);
      }
    }
    return 0.0;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  bool _hasCrf(Assessment a) =>
      (a.concomitantMedications != null && a.concomitantMedications!.isNotEmpty) ||
      (a.concomitantDiseases != null && a.concomitantDiseases!.isNotEmpty) ||
      (a.aeRefs != null && a.aeRefs!.isNotEmpty);

  Widget _buildCrfRow(String label, List<Map<String, dynamic>>? list) {
    if (list == null || list.isEmpty) {
      return _infoRow(label, '—');
    }
    final item = list.firstWhere(
      (m) =>
          m['triState'] is String &&
          (m['triState'] == 'ND' ||
              m['triState'] == 'UN' ||
              m['triState'] == 'NA'),
      orElse: () => const {},
    );
    final triState = item['triState'] as String?;
    final note = item['note'] as String?;
    final buf = StringBuffer();
    if (triState != null) buf.write(triState);
    if (note != null && note.isNotEmpty) {
      buf.write(buf.isEmpty ? note : ' — $note');
    }
    return _infoRow(label, buf.toString().isEmpty ? '—' : buf.toString());
  }
}

/// 创面照片源数据下载弹窗（V1 demo 阶段用 AlertDialog 显示 JSON，
/// 真实阶段换成 zipStream 流式下载到本地）。
class _PhotoMetadataDialog extends StatelessWidget {
  final Map<String, dynamic> metadata;
  const _PhotoMetadataDialog({required this.metadata});

  @override
  Widget build(BuildContext context) {
    // 把 Map 转成 pretty JSON
    const encoder = JsonEncoder.withIndent('  ');
    final pretty = encoder.convert(_sanitizeForPretty(metadata));
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.fingerprint_rounded,
                    color: AppTheme.actionBlue, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('创面照片源数据 · GCP §59 ALCOA+',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.pageBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  pretty,
                  style: const TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 11,
                      height: 1.45,
                      color: AppTheme.textPrimary),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('V1 demo 阶段：JSON 已显示在弹窗中，生产阶段替换为 zip 下载'),
                        ),
                      );
                    },
                    child: const Text('导出 zip（demo 占位）'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 截掉 uuid 类过长的字段避免 UI 卡顿。
  Map<String, dynamic> _sanitizeForPretty(Map<String, dynamic> src) {
    final out = <String, dynamic>{};
    src.forEach((k, v) {
      if (v is String && v.length > 200) {
        out[k] = '${v.substring(0, 200)}…(${v.length})';
      } else if (v is Map) {
        out[k] = _sanitizeForPretty(v.cast<String, dynamic>());
      } else {
        out[k] = v;
      }
    });
    return out;
  }
}
