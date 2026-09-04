import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/assessment.dart';
import '../models/photo_metadata.dart';
import '../models/request_models.dart';
import '../providers/assessment_provider.dart';
import '../utils/photo_time.dart';
import '../widgets/app_ui.dart';
import '../widgets/canvas_adjust_overlay.dart';
import '../widgets/vss_scale_widget.dart';
import '../widgets/nrs_pain_widget.dart';
import 'concomitant_med_screen.dart';
import 'contour_edit_screen.dart';
import 'crf_completion_dialog.dart';

/// 拍照后评估页（设计稿 04 测量结果 + 05 临床量表合并）：
/// AI 测量 + 轮廓手工调整/手绘（实时计算尺寸）+ 组织构成 + VSS/NRS/创面分期 + 提交签名。
/// 照片右上角"调整"入口 → 全屏放大编辑轮廓。
class AssessmentReviewScreen extends StatefulWidget {
  final String patientId;
  final String woundId;
  final String imagePath;
  /// 导入照片时携带：EXIF 拍摄时间（ISO8601）。拍照时为空，使用当前时间。
  final DateTime? recordTime;
  /// 'exif_original' / 'exif_digitized' / 'exif_datetime' / 'file_mtime' / 'now'
  final String photoTimeSource;
  /// GCP W3.1 — 创面照片源数据快照（COS 路径 + SHA256 + EXIF + 设备指纹）。
  final Map<String, dynamic>? photoMetadata;
  const AssessmentReviewScreen({
    super.key,
    required this.patientId,
    required this.woundId,
    required this.imagePath,
    this.recordTime,
    this.photoTimeSource = 'now',
    this.photoMetadata,
  });

  @override
  State<AssessmentReviewScreen> createState() => _AssessmentReviewScreenState();
}

class _AssessmentReviewScreenState extends State<AssessmentReviewScreen> {
  final _scrollCtrl = ScrollController();
  double _imgAspect = 3 / 4; // 图片宽高比（异步解码）
  double _imgW = 900, _imgH = 1200; // demo 合成图尺寸兜底
  List<Offset>? _normPoints; // 轮廓（归一化 0..1）
  bool _outlineModified = false;
  Key _overlayKey = UniqueKey();
  // 实时测量值（编辑轮廓后更新），初始为 AI 值。
  double? _liveArea, _liveLength, _liveWidth;
  int? _nrsScore, _vssVascularity, _vssPigmentation, _vssPliability, _vssHeight;
  String _stage = '2期'; // 创面分期（演示）

  /// GCP W3.2 — CRF 三态字段（ND/UN/NA）。
  /// 每个 list 至少一项必须有 triState ∈ {ND, UN, NA}。
  List<Map<String, dynamic>>? _meds;
  List<Map<String, dynamic>>? _diseases;
  List<Map<String, dynamic>>? _aeRefs;

  @override
  void initState() {
    super.initState();
    _loadImageInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<AssessmentProvider>();
      // 先确保 history 已加载（用于量表前值提示）。
      await provider.loadHistory(widget.woundId);
      if (!mounted) return;
      final draft = await provider.createDraft(
        widget.patientId,
        widget.woundId,
        null,
        recordTime: widget.recordTime,
      );
      if (draft != null && mounted) {
        await provider.saveAiResults(draft.id, widget.imagePath);
        // GCP W3.1 — 若 capture 阶段已经算出 photoMetadata，把它也提交到
        // 服务端（demo 阶段模拟），让详情页"下载原始"按钮拿到完整数据。
        final md = widget.photoMetadata;
        if (md != null) {
          try {
            final meta = PhotoMetadata.fromJson(md);
            // 这里只是把 metadata 存到 provider.current 准备 confirm 时携带；
            // 真正落到 demo_backend 的时机在 _confirmAll() 调 PUT /confirm。
            // demo 阶段 metadata 同步 PUT /confirm 内嵌 photoMetadataSnapshot。
            // 仅为提示用, 暂不做额外网络调用 (cos uploader 已经模拟).
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('创面照片源数据已落地 · sha256=${meta.sha256.substring(0, 8)}…'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ));
            }
          } catch (_) {/* 忽略非致命错误 */}
        }
      }
    });
  }

  Future<void> _loadImageInfo() async {
    double w = 900, h = 1200; // demo 合成图尺寸兜底
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (frame.image.width > 0 && frame.image.height > 0) {
        w = frame.image.width.toDouble();
        h = frame.image.height.toDouble();
      }
      frame.image.dispose();
      codec.dispose();
    } catch (_) {/* 使用兜底尺寸 */}
    if (mounted) {
      setState(() {
        _imgW = w;
        _imgH = h;
        _imgAspect = w / h;
      });
    }
  }

  /// 解析 AI 轮廓（图片像素坐标）→ 归一化 0..1。
  List<Offset> _parsePolygon(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((p) => Offset(
              ((p['x'] as num).toDouble() / _imgW).clamp(0.0, 1.0),
              ((p['y'] as num).toDouble() / _imgH).clamp(0.0, 1.0)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _openContourEditor(double? aiLengthCm) async {
    final pts = _normPoints;
    if (pts == null || pts.length < 3) return;
    final result = await Navigator.push<ContourEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ContourEditScreen(
          imagePath: widget.imagePath,
          initialPoints: pts,
          aiLengthCm: aiLengthCm,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _normPoints = result.points;
        if (result.modified) _outlineModified = true;
        _liveArea = result.metrics.areaCm2;
        _liveLength = result.metrics.lengthCm;
        _liveWidth = result.metrics.widthCm;
        _overlayKey = UniqueKey();
      });
    }
  }

  /// 顶部"照片取自：yyyy-MM-dd HH:mm"提示。
  /// 仅在导入照片（或 demo 真实拍照带了 recordTime）时显示。
  Widget _buildPhotoTimeBanner() {
    final t = widget.recordTime!;
    final sourceLabel = switch (widget.photoTimeSource) {
      'exif_original' => 'EXIF 拍摄时间',
      'exif_digitized' => '数字化时间',
      'exif_datetime' => 'EXIF 写入时间',
      'file_mtime' => '文件修改时间',
      _ => '照片时间',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.actionBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.actionBlue.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 18, color: AppTheme.actionBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '记录时间：${fmtPhotoTime(t)}（来自$sourceLabel）',
              style: AppTheme.micro.copyWith(
                color: AppTheme.actionBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assessment = context.watch<AssessmentProvider>().current;
    final aiData = assessment?.aiPolygonJson;
    final tissue = assessment?.aiTissuePercentages;
    // AI 轮廓就绪后初始化归一化点集（含 key 变更触发 overlay 重建）。
    if (_normPoints == null && aiData != null) {
      final pts = _parsePolygon(aiData);
      if (pts.length >= 3) {
        _normPoints = pts;
        _overlayKey = UniqueKey();
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('评估')),
      body: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepIndicator(
                step: 2, total: 4, label: '拍照 + AI 测量已完成 · 请核对并完成临床量表'),
            const SizedBox(height: 12),
            if (widget.recordTime != null) _buildPhotoTimeBanner(),
            const SizedBox(height: 16),

            // 照片 + AI 轮廓（只读预览，点右上角"调整"进入全屏编辑）
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: _imgAspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(widget.imagePath),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium),
                    if (_normPoints != null)
                      IgnorePointer(
                        child: CanvasAdjustOverlay(
                          key: _overlayKey,
                          initialPoints: _normPoints!,
                          imageAspect: _imgAspect,
                          aiLengthCm: assessment?.aiLengthCm,
                          mode: WoundOverlayMode.adjust,
                          readonly: true,
                          onChanged: (_) {},
                          onMetrics: (m) {
                            // 仅在没有手工调整值时以 AI 轮廓初始化实时值
                            if (!_outlineModified && mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && !_outlineModified) {
                                  setState(() {
                                    _liveArea ??= m.areaCm2;
                                    _liveLength ??= m.lengthCm;
                                    _liveWidth ??= m.widthCm;
                                  });
                                }
                              });
                            }
                          },
                        ),
                      ),
                    // 左上状态
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _outlineModified
                              ? '轮廓已手工调整 · 测量实时更新'
                              : 'AI 已识别创面轮廓',
                          style:
                              const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                    // 右上角"调整"入口（半透明）
                    Positioned(
                      right: 12,
                      top: 12,
                      child: GestureDetector(
                        onTap: () =>
                            _openContourEditor(assessment?.aiLengthCm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text('调整',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 测量结果三宫格（实时）
            if (_liveArea != null || assessment?.aiAreaCm2 != null) ...[
              AppCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('测量结果',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        if (_outlineModified) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.statusPendingSign
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('已修正',
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
                        (
                          label: '面积',
                          value: (_liveArea ?? assessment?.aiAreaCm2 ?? 0)
                              .toStringAsFixed(1),
                          unit: 'cm²'
                        ),
                        (
                          label: '最长径',
                          value:
                              (_liveLength ?? assessment?.aiLengthCm ?? 0)
                                  .toStringAsFixed(1),
                          unit: 'cm'
                        ),
                        (
                          label: '宽度',
                          value: (_liveWidth ?? assessment?.aiWidthCm ?? 0)
                              .toStringAsFixed(1),
                          unit: 'cm'
                        ),
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
                    const Text('组织构成（AI 分析）',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

            // NRS + VSS（均带前值提示）
            _PreviousScoresLoader(
              woundId: widget.woundId,
              builder: (prev) => Column(
                children: [
                  NrsPainWidget(
                    previousValue: prev.nrs,
                    onChanged: (v) => _nrsScore = v,
                  ),
                  const SizedBox(height: 12),
                  VssScaleWidget(
                    previousVascularity: prev.vssVascularity,
                    previousPigmentation: prev.vssPigmentation,
                    previousPliability: prev.vssPliability,
                    previousHeight: prev.vssHeight,
                    onVascularity: (v) => _vssVascularity = v,
                    onPigmentation: (v) => _vssPigmentation = v,
                    onPliability: (v) => _vssPliability = v,
                    onHeight: (v) => _vssHeight = v,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 创面分期
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('创面分期',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in ['1期', '2期', '3期', '4期', '不可分期'])
                        ScaleChip(
                          label: s,
                          selected: _stage == s,
                          onTap: () => setState(() => _stage = s),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // GCP W3.2 — CRF 录入卡：合并用药 / 合并疾病 / AE / CRF 完成声明。
            _buildCrfEntryCard(),
            const SizedBox(height: 8),
            Text('拍摄建议：光线充足 · 垂直拍摄 · 距离 15–20 cm',
                style: AppTheme.micro),

            const SizedBox(height: 20),

            // 底部操作
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('重新拍摄'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('提交签名'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _tissueVal(Map<String, double> tissue, String key) {
    // 兼容两套 key 命名（granulation / granulation_red_percent）
    final v = tissue[key] ?? tissue['${key}_red_percent'];
    if (v != null) return (v <= 1.0 ? v : v / 100.0).clamp(0.0, 1.0);
    // 兜底匹配包含关键词的 key
    for (final e in tissue.entries) {
      if (e.key.contains(key)) {
        return (e.value <= 1.0 ? e.value : e.value / 100.0).clamp(0.0, 1.0);
      }
    }
    return 0.0;
  }

  /// GCP W3.2 — CRF 录入卡。
  /// 三态录入按钮 + CRF 完成声明按钮（PI 必签）+ 状态指示。
  Widget _buildCrfEntryCard() {
    final medsFilled = _meds != null && _hasTriState(_meds!);
    final diseasesFilled =
        _diseases != null && _hasTriState(_diseases!);
    final aeFilled = _aeRefs != null && _hasTriState(_aeRefs!);
    final allFilled = medsFilled && diseasesFilled && aeFilled;
    final declared =
        context.read<AssessmentProvider>().current?.crfCompletionDeclaredAt !=
            null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('CRF 必填字段',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (declared)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.statusLocked.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified_rounded,
                          size: 14, color: AppTheme.statusLocked),
                      SizedBox(width: 4),
                      Text('已声明 · 临床字段锁定',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.statusLocked,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '合并用药 / 合并疾病 / AE 占位都必须填 ND/UN/NA 三态之一；PI 必签后才可锁定。',
            style: AppTheme.micro,
          ),
          const SizedBox(height: 12),

          // CRF 三态录入入口
          OutlinedButton.icon(
            icon: Icon(allFilled ? Icons.check_circle_outline : Icons.edit_note),
            label: Text(allFilled
                ? '已录入 CRF 三态（可点击重新编辑）'
                : '录入 CRF 三态（合并用药 / 合并疾病 / AE）'),
            onPressed: declared ? null : _openConcomitant,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              side: BorderSide(
                color: allFilled
                    ? AppTheme.statusLocked
                    : AppTheme.actionBlue,
              ),
              foregroundColor: allFilled
                  ? AppTheme.statusLocked
                  : AppTheme.actionBlue,
            ),
          ),
          const SizedBox(height: 10),

          // CRF 完成声明（PI 必签）
          ElevatedButton.icon(
            icon: const Icon(Icons.verified_user_outlined, size: 20),
            label: Text(declared
                ? 'CRF 完成声明已提交'
                : 'PI CRF 完成声明（PIN 二次鉴别 + 锁定临床字段）'),
            onPressed: declared ? null : _openCrfComplete,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              backgroundColor:
                  declared ? AppTheme.statusLocked : AppTheme.actionBlue,
            ),
          ),

          if (allFilled && !declared) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (medsFilled) _triStateBadge('合并用药', _meds!),
                if (diseasesFilled) _triStateBadge('合并疾病', _diseases!),
                if (aeFilled) _triStateBadge('AE', _aeRefs!),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _hasTriState(List<Map<String, dynamic>> list) {
    return list.any((m) {
      final ts = m['triState'];
      return ts is String && (ts == 'ND' || ts == 'UN' || ts == 'NA');
    });
  }

  Widget _triStateBadge(String label, List<Map<String, dynamic>> list) {
    final ts = list.firstWhere(
      (m) =>
          m['triState'] is String &&
          (m['triState'] == 'ND' ||
              m['triState'] == 'UN' ||
              m['triState'] == 'NA'),
      orElse: () => const {},
    )['triState'] as String? ?? '—';
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.actionBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$label: $ts',
          style: const TextStyle(
              fontSize: 11,
              color: AppTheme.actionBlue,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _submit() async {
    await _confirmAll();
    if (!mounted) return;
    Navigator.pushNamed(context, '/sign', arguments: _currentAssessmentId());
  }

  String _currentAssessmentId() {
    final c = context.read<AssessmentProvider>().current;
    return c?.id ?? '';
  }

  /// GCP W3 — confirm 同时带上 CRF 4 字段 + photoMetadataSnapshot。
  Future<void> _confirmAll() async {
    final provider = context.read<AssessmentProvider>();
    final current = provider.current;
    if (current == null) return;
    // 提交实时测量值（轮廓调整/手绘后自动计算），留痕记录修正方式。
    final area = _liveArea ?? current.aiAreaCm2;
    final length = _liveLength ?? current.aiLengthCm;
    final width = _liveWidth ?? current.aiWidthCm;
    final vssTotal = (_vssVascularity ?? 0) +
        (_vssPigmentation ?? 0) +
        (_vssPliability ?? 0) +
        (_vssHeight ?? 0);
    final reason = <String>[
      if (_outlineModified) '测量轮廓已由医生手工调整/手绘修正',
      if (_nrsScore != null) 'NRS疼痛评分=$_nrsScore',
      if (_vssVascularity != null) 'VSS血管化=$_vssVascularity',
      if (_vssPigmentation != null) 'VSS色素=$_vssPigmentation',
      if (_vssPliability != null) 'VSS柔软度=$_vssPliability',
      if (_vssHeight != null) 'VSS厚度=$_vssHeight',
      '创面分期=$_stage',
    ].join('; ');
    await provider.confirm(current.id, ClinicianConfirmRequest(
      finalAreaCm2: area,
      finalLengthCm: length,
      finalWidthCm: width,
      finalPolygonJson: jsonEncode(
          _normPoints?.map((p) => {'x': p.dx, 'y': p.dy}).toList()),
      confirmedWithoutChange: !_outlineModified,
      manualOverrideReason: reason.isEmpty ? null : reason,
      nrsPainScore: _nrsScore,
      vssVascularity: _vssVascularity,
      vssPigmentation: _vssPigmentation,
      vssPliability: _vssPliability,
      vssHeight: _vssHeight,
      vssTotal: vssTotal,
      woundStage: _stage,
      concomitantMedications: _meds,
      concomitantDiseases: _diseases,
      aeRefs: _aeRefs,
      photoMetadataSnapshot: widget.photoMetadata,
    ));
    await provider.submit(current.id);
  }

  /// GCP W3.2 — 弹出合并用药/合并疾病/AE 三态录入页。
  Future<void> _openConcomitant() async {
    final result = await Navigator.push<CrfTriStateResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ConcomitantMedScreen(
          initialMeds: _meds,
          initialDiseases: _diseases,
          initialAeRefs: _aeRefs,
        ),
      ),
    );
    if (result != null && mounted) {
setState(() {
        _meds = result.medications;
        _diseases = result.diseases;
        _aeRefs = result.aeRefs;
      });
  }
  }

  /// GCP W3.2 — PI 必签的 CRF 完成声明。
  /// 要求 CRF 三态字段已录入 + NRS/VSS 已填 + 拍摄/分析已完成；
  /// 否则提示用户先补全，最后调 PATCH declare-crf-complete 锁定临床字段。
  Future<void> _openCrfComplete() async {
    final provider = context.read<AssessmentProvider>();
    final current = provider.current;
    if (current == null) return;

    if (_meds == null || _diseases == null || _aeRefs == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('请先点击"CRF 三态录入"完成合并用药 / 合并疾病 / AE 三态选择'),
      ));
      return;
    }
    if (_nrsScore == null || _vssVascularity == null ||
        _vssPigmentation == null || _vssPliability == null ||
        _vssHeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('请先完成 NRS + VSS 全部 4 项分值'),
      ));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const CrfCompletionDialog(),
    );
    if (ok != true || !mounted) return;

    // 先 confirm 落 CRF + photoMetadataSnapshot，再 declare-crf-complete 锁定。
    await _confirmAll();
    if (!mounted) return;
    try {
      await provider.declareCrfComplete(
        assessmentId: current.id,
        pin: '123456', // demo 阶段硬编码；真实阶段弹 PIN 输入
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('CRF 完成声明已记录 · 临床字段已锁定'),
        ));
        Navigator.pushNamed(context, '/sign', arguments: current.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('CRF 完成声明失败: $e')));
      }
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }
}

/// 上一次评估的分值（NRS + VSS 四项），用于各量表前值提示。
class PreviousScores {
  final int? nrs;
  final int? vssVascularity;
  final int? vssPigmentation;
  final int? vssPliability;
  final int? vssHeight;
  const PreviousScores({
    this.nrs,
    this.vssVascularity,
    this.vssPigmentation,
    this.vssPliability,
    this.vssHeight,
  });
}

class _PreviousScoresLoader extends StatelessWidget {
  final String woundId;
  final Widget Function(PreviousScores previous) builder;
  const _PreviousScoresLoader({required this.woundId, required this.builder});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssessmentProvider>();
    final history = provider.history.where((a) => a.woundId == woundId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    Assessment? prev;
    for (final a in history) {
      if (a.nrsPainScore != null || a.vssTotal != null) {
        prev = a;
        break;
      }
    }
    return builder(PreviousScores(
      nrs: prev?.nrsPainScore,
      vssVascularity: prev?.vssVascularity,
      vssPigmentation: prev?.vssPigmentation,
      vssPliability: prev?.vssPliability,
      vssHeight: prev?.vssHeight,
    ));
  }
}
