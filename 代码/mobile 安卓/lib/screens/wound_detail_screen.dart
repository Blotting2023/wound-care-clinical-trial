import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../main.dart';
import '../models/assessment.dart';
import '../models/enums.dart';
import '../models/wound.dart';
import '../providers/assessment_provider.dart';
import '../services/api_client.dart';
import '../services/wound_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/assessment_photo_view.dart';

/// 部位详情页：展示单一部位的评估历史 + 数值变化曲线。
class WoundDetailScreen extends StatefulWidget {
  final String woundId;
  const WoundDetailScreen({super.key, required this.woundId});

  @override
  State<WoundDetailScreen> createState() => _WoundDetailScreenState();
}

class _WoundDetailScreenState extends State<WoundDetailScreen>
    with RouteAware {
  final WoundService _woundService = WoundService(apiClient: ApiClient.instance);
  Wound? _wound;
  String? _error;

  /// 当前曲线指标：面积 / NRS 疼痛 / VSS 总分。
  _TrendMetric _trendMetric = _TrendMetric.area;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // 从记录详情/签名流程返回时刷新评估历史与照片。
    _load();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _load() async {
    final wResult = await _woundService.getWound(widget.woundId);
    if (!mounted) return;
    setState(() {
      _wound = wResult.success ? wResult.data : null;
      _error = wResult.success ? null : wResult.message;
    });
    await context.read<AssessmentProvider>().loadHistory(widget.woundId);
  }

  void _startNewAssessment() {
    final w = _wound;
    if (w == null) return;
    Navigator.pushNamed(context, '/capture', arguments: {
      'patientId': w.patientId,
      'woundId': w.id,
      'patientName': '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssessmentProvider>();
    final history = provider.history
        .where((a) => a.woundId == widget.woundId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_wound?.displayLabel ?? '部位详情'),
      ),
      body: _buildBody(history),
      bottomNavigationBar: _wound != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton.icon(
                  onPressed: _startNewAssessment,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('新增记录'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(List<Assessment> history) {
    if (_wound == null && _error == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.actionBlue));
    }
    if (_error != null) {
      return Center(child: Text('加载失败: $_error', style: AppTheme.caption));
    }
    final w = _wound!;

    return RefreshIndicator(
      color: AppTheme.actionBlue,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // 部位信息卡
          _buildWoundInfoCard(w),
          const SizedBox(height: 16),

          // 最近一次记录（照片 + 关键数据，置顶展示）
          if (history.isNotEmpty) ...[
            const SectionTitle('最近一次记录'),
            const SizedBox(height: 10),
            _buildLatestRecordCard(history.last),
            const SizedBox(height: 16),
          ],

          // 多指标趋势曲线（面积 / NRS 疼痛 / VSS 总分）
          if (history.isNotEmpty) ...[
            const SectionTitle('数值变化趋势'),
            const SizedBox(height: 10),
            _buildTrendChart(history),
            const SizedBox(height: 16),
          ],

          // 评估历史
          const SectionTitle('评估历史'),
          const SizedBox(height: 10),
          if (history.isEmpty)
            AppCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('暂无评估记录', style: AppTheme.caption),
                ),
              ),
            )
          else
            for (final a in history.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildHistoryCard(a),
              ),
        ],
      ),
    );
  }

  /// 最近一次记录卡：照片（含轮廓叠加）+ 关键数据 + 状态。
  Widget _buildLatestRecordCard(Assessment a) {
    final area = a.finalAreaCm2 ?? a.aiAreaCm2;
    final length = a.finalLengthCm ?? a.aiLengthCm;
    final width = a.finalWidthCm ?? a.aiWidthCm;
    return AppCard(
      onTap: () => Navigator.pushNamed(context, '/assessment-record',
          arguments: a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('评估 · ${_fmtDate(a.createdAt)}',
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              _statusChip(a.status),
            ],
          ),
          const SizedBox(height: 10),
          AssessmentPhotoView(
            photoPath: a.photoPath,
            polygonJson: a.finalPolygonJson ?? a.aiPolygonJson,
            aiLengthCm: a.finalLengthCm ?? a.aiLengthCm,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniStat('面积', '${(area ?? 0).toStringAsFixed(1)} cm²'),
              _miniStat('最长径', '${(length ?? 0).toStringAsFixed(1)} cm'),
              _miniStat('宽度', '${(width ?? 0).toStringAsFixed(1)} cm'),
            ],
          ),
          if (a.nrsPainScore != null || a.vssTotal != null) ...[
            const Divider(height: 20, color: AppTheme.cardBorder),
            Text(
              [
                if (a.nrsPainScore != null) 'NRS 疼痛 ${a.nrsPainScore} 分',
                if (a.vssTotal != null) 'VSS 总分 ${a.vssTotal} 分',
              ].join(' · '),
              style: AppTheme.caption
                  .copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWoundInfoCard(Wound w) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.pageBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: const Icon(Icons.healing_rounded,
                    color: AppTheme.textHint, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.anatomicalLocation,
                        style: AppTheme.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(w.woundType ?? '—',
                        style: AppTheme.micro),
                    const SizedBox(height: 2),
                    Text('起病 ${_fmtDate(w.onsetDate)}',
                        style: AppTheme.micro),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(List<Assessment> history) {
    final candidates = <(_TrendMetric, String, String, Color)>[
      (_TrendMetric.area, '面积', 'cm²', AppTheme.actionBlue),
      (_TrendMetric.nrs, 'NRS 疼痛评分', '分', const Color(0xFFFF6B6B)),
      (_TrendMetric.vss, 'VSS 总分', '分', const Color(0xFF9C6BFF)),
    ];
    // 保留至少含 1 个数据点的指标
    final available = candidates
        .where((c) => history.any((a) => _extractValue(a, c.$1) != null))
        .toList();
    if (available.isEmpty) {
      return AppCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('尚无评分数据', style: AppTheme.caption),
          ),
        ),
      );
    }
    // 若默认指标无数据，自动切换到第一个可用的。
    if (!available.any((c) => c.$1 == _trendMetric)) {
      _trendMetric = available.first.$1;
    }
    final current = available.firstWhere(
      (c) => c.$1 == _trendMetric,
      orElse: () => available.first,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 指标切换：紧凑胶囊式 Segmented Control
          SizedBox(
            height: 32,
            child: Row(
              children: [
                for (final c in available) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _trendMetric = c.$1),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.$1 == _trendMetric
                              ? c.$4.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: c.$1 == _trendMetric
                                ? c.$4
                                : AppTheme.cardBorder,
                          ),
                        ),
                        child: Text(
                          c.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.$1 == _trendMetric
                                ? c.$4
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (c != available.last) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _drawSeries(
            history: history,
            metric: current.$1,
            label: current.$2,
            unit: current.$3,
            color: current.$4,
          ),
        ],
      ),
    );
  }

  double? _extractValue(Assessment a, _TrendMetric m) {
    switch (m) {
      case _TrendMetric.area:
        return a.finalAreaCm2 ?? a.aiAreaCm2;
      case _TrendMetric.nrs:
        return a.nrsPainScore?.toDouble();
      case _TrendMetric.vss:
        return a.vssTotal?.toDouble();
    }
  }

  Widget _drawSeries({
    required List<Assessment> history,
    required _TrendMetric metric,
    required String label,
    required String unit,
    required Color color,
  }) {
    final pairs = <_Point>[];
    for (final a in history) {
      final v = _extractValue(a, metric);
      if (v != null) pairs.add(_Point(a.createdAt, v));
    }
    pairs.sort((a, b) => a.t.compareTo(b.t));

    if (pairs.length == 1) {
      // 单点：数值卡片
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('最新 $label', style: AppTheme.micro),
                const SizedBox(height: 4),
                Text(
                  '${pairs.first.v.toStringAsFixed(metric == _TrendMetric.area ? 1 : 0)} $unit',
                  style: AppTheme.metricNumber
                      .copyWith(color: color, fontSize: 22),
                ),
              ],
            ),
          ),
          Text(_fmtDate(pairs.first.t), style: AppTheme.micro),
        ],
      );
    }

    final values = pairs.map((p) => p.v).toList();
    final dates = pairs.map((p) => p.t).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label ($unit)', style: AppTheme.caption),
            Text(
              '${_fmtDate(dates.first)} ~ ${_fmtDate(dates.last)}',
              style: AppTheme.micro,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: CustomPaint(
            size: const Size(double.infinity, 140),
            painter: _AreaTrendPainter(
              values: values,
              lineColor: color,
              fillColor: color.withValues(alpha: 0.08),
              pointColor: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _miniStat('最新',
                '${values.last.toStringAsFixed(metric == _TrendMetric.area ? 1 : 0)}'),
            _miniStat(
                '最小',
                '${values.reduce((a, b) => a < b ? a : b).toStringAsFixed(metric == _TrendMetric.area ? 1 : 0)}'),
            _miniStat(
                '最大',
                '${values.reduce((a, b) => a > b ? a : b).toStringAsFixed(metric == _TrendMetric.area ? 1 : 0)}'),
          ],
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: AppTheme.body.copyWith(
                fontWeight: FontWeight.w600, color: AppTheme.actionBlue)),
        Text(label, style: AppTheme.micro),
      ],
    );
  }

  Widget _buildHistoryCard(Assessment a) {
    final area = a.finalAreaCm2 ?? a.aiAreaCm2;
    return AppCard(
      onTap: () => Navigator.pushNamed(context, '/assessment-record',
          arguments: a),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_fmtDate(a.createdAt)} · VSS${a.vssTotal ?? '—'} · NRS${a.nrsPainScore ?? '—'}',
                  style: AppTheme.body
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                if (area != null)
                  Text('${area.toStringAsFixed(1)} cm²',
                      style: AppTheme.caption.copyWith(
                          color: AppTheme.actionBlue,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          _statusChip(a.status),
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
        return StatusChip.custom(label: status.value);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 部位页曲线指标。
enum _TrendMetric { area, nrs, vss }

class _Point {
  final DateTime t;
  final double v;
  const _Point(this.t, this.v);
}

/// 手绘面积趋势折线图（无需外部图表库）。
class _AreaTrendPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final Color pointColor;

  _AreaTrendPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
    required this.pointColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    const padLeft = 28.0;
    const padRight = 12.0;
    const padTop = 16.0;
    const padBottom = 24.0;

    final w = size.width - padLeft - padRight;
    final h = size.height - padTop - padBottom;

    double dx(int i) => padLeft + (i / (values.length - 1)) * w;
    double dy(double v) => padTop + h - ((v - minV) / range) * h;

    final path = Path();
    path.moveTo(dx(0), dy(values[0]));
    for (int i = 1; i < values.length; i++) {
      path.lineTo(dx(i), dy(values[i]));
    }

    // 填充区域
    final fillPath = Path.from(path);
    fillPath.lineTo(dx(values.length - 1), size.height - padBottom);
    fillPath.lineTo(dx(0), size.height - padBottom);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    // 折线
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 数据点
    for (int i = 0; i < values.length; i++) {
      final center = Offset(dx(i), dy(values[i]));
      canvas.drawCircle(
        center,
        4,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        center,
        4,
        Paint()
          ..color = pointColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Y轴刻度（最小、最大）
    final labelStyle = TextStyle(
      color: lineColor.withValues(alpha: 0.7),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );
    _drawText(canvas, maxV.toStringAsFixed(1), padLeft - 4, padTop - 6,
        labelStyle, align: TextAlign.right, width: 24);
    _drawText(canvas, minV.toStringAsFixed(1), padLeft - 4,
        size.height - padBottom - 6, labelStyle,
        align: TextAlign.right, width: 24);
  }

  void _drawText(Canvas canvas, String text, double x, double y,
      TextStyle style,
      {TextAlign align = TextAlign.left, double width = 100}) {
    final span = TextSpan(text: text, style: style);
    final tp = TextPainter(
      text: span,
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: width);
    tp.paint(canvas, Offset(x - (align == TextAlign.right ? width : 0), y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
