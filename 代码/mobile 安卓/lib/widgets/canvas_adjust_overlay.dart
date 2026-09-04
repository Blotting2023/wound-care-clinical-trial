import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// 测量结果（cm 单位），由轮廓点集实时计算得出。
class WoundMetrics {
  final double? areaCm2;
  final double? lengthCm;
  final double? widthCm;
  const WoundMetrics({this.areaCm2, this.lengthCm, this.widthCm});
}

/// 轮廓调整模式。
enum WoundOverlayMode { adjust, draw }

/// AI 轮廓手工调整覆盖层（归一化坐标版本）：
/// - 点集用 0..1 的归一化坐标存储（相对图片），可在任意尺寸容器中渲染。
/// - [WoundOverlayMode.adjust] 拖动多边形顶点修正关键点；
///   最长径 / 宽径指示线端点也可拖动，手动指定测量基准。
/// - [WoundOverlayMode.draw]   手绘全新轮廓。
/// - [readonly] 只读展示（部位页/记录详情页回看），不绘制把手。
/// 容器必须与图片等比（AspectRatio），否则归一化映射会变形。
/// 面积按 [imageAspect] 做长宽修正后，以 AI 长径做相对标定实时回调。
class CanvasAdjustOverlay extends StatefulWidget {
  final List<Offset> initialPoints; // 归一化 0..1
  final double imageAspect; // 图片宽高比 w/h
  final double? aiLengthCm; // 用于 px→cm 相对标定（真实场景由校准卡提供）
  final WoundOverlayMode mode;
  final bool readonly;
  final ValueChanged<List<Offset>> onChanged; // 归一化坐标
  final ValueChanged<WoundMetrics> onMetrics;
  final VoidCallback? onModified;

  const CanvasAdjustOverlay({
    super.key,
    required this.initialPoints,
    this.imageAspect = 3 / 4,
    this.aiLengthCm,
    this.mode = WoundOverlayMode.adjust,
    this.readonly = false,
    required this.onChanged,
    required this.onMetrics,
    this.onModified,
  });

  @override
  State<CanvasAdjustOverlay> createState() => _CanvasAdjustOverlayState();
}

class _CanvasAdjustOverlayState extends State<CanvasAdjustOverlay> {
  late List<Offset> _norm;
  int? _draggingIndex;
  bool _modified = false;
  List<Offset>? _drawing; // 归一化

  // 手动指示线端点（归一化坐标）；null = 由轮廓自动计算。
  Offset? _lenA, _lenB, _widA, _widB;
  _DragTarget? _dragging;

  @override
  void initState() {
    super.initState();
    _norm = List.from(widget.initialPoints);
    // 初始 metrics 推迟到帧末回调，避免在父级 build 期间触发 setState。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emit();
    });
  }

  @override
  void didUpdateWidget(covariant CanvasAdjustOverlay old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) {
      _draggingIndex = null;
      _drawing = null;
      _dragging = null;
      setState(() {});
    }
  }

  void _emit() {
    widget.onChanged(_norm);
    widget.onMetrics(_computeMetrics(_norm));
  }

  /// 归一化坐标 → 等比修正空间（x 乘 aspect），保证距离/面积几何正确。
  List<Offset> _aspectSpace(List<Offset> norm) =>
      norm.map((p) => Offset(p.dx * widget.imageAspect, p.dy)).toList();

  /// 等比空间 → 归一化坐标。
  Offset _fromAspect(Offset p) =>
      Offset(p.dx / widget.imageAspect, p.dy);

  /// px→cm 相对标定：以 AI 报告的最长径为基准（等比空间单位）。
  double _unitsPerCm(List<Offset> aspectPts) {
    final aiLen = widget.aiLengthCm;
    final len = _maxSpan(aspectPts).length;
    if (aiLen == null || aiLen <= 0 || len <= 0) return 0.19; // demo 兜底
    return len / aiLen;
  }

  WoundMetrics _computeMetrics(List<Offset> normPts) {
    if (normPts.length < 3) return const WoundMetrics();
    final pts = _aspectSpace(normPts);
    final scale = _unitsPerCm(pts);
    if (scale <= 0) return const WoundMetrics();
    final areaUnits = _shoelaceArea(pts).abs();
    final span = _maxSpan(pts);
    // 长径：手动指示线优先，否则取轮廓最大跨度。
    double lengthCm = span.length / scale;
    if (_lenA != null && _lenB != null) {
      final la = Offset(_lenA!.dx * widget.imageAspect, _lenA!.dy);
      final lb = Offset(_lenB!.dx * widget.imageAspect, _lenB!.dy);
      if ((la - lb).distance > 0) lengthCm = (la - lb).distance / scale;
    }
    // 宽径：手动指示线优先，否则取垂直方向最大投影。
    double widthCm = span.width / scale;
    if (_widA != null && _widB != null) {
      final wa = Offset(_widA!.dx * widget.imageAspect, _widA!.dy);
      final wb = Offset(_widB!.dx * widget.imageAspect, _widB!.dy);
      if ((wa - wb).distance > 0) widthCm = (wa - wb).distance / scale;
    }
    return WoundMetrics(
      areaCm2: areaUnits / (scale * scale),
      lengthCm: lengthCm,
      widthCm: widthCm,
    );
  }

  /// 自动指示线端点（归一化坐标）。长径 = 最大跨度两端；宽径 = 中点垂直方向。
  ({Offset lenA, Offset lenB, Offset widA, Offset widB, bool hasWidth})
      _autoDimensionEndpoints() {
    final span = _maxSpan(_aspectSpace(_norm));
    final lenA = _fromAspect(span.a);
    final lenB = _fromAspect(span.b);
    Offset widA = lenA, widB = lenB;
    var hasWidth = false;
    final axis = span.b - span.a;
    if (axis.distance > 0.0001 && span.width > 0.0001) {
      final mid = (span.a + span.b) / 2;
      final dir = axis / axis.distance;
      final perp = Offset(-dir.dy, dir.dx);
      widA = _fromAspect(mid - perp * (span.width / 2));
      widB = _fromAspect(mid + perp * (span.width / 2));
      hasWidth = true;
    }
    return (lenA: lenA, lenB: lenB, widA: widA, widB: widB, hasWidth: hasWidth);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (size.width <= 0 || size.height <= 0) return const SizedBox.shrink();
      Offset toLocal(Offset n) =>
          Offset(n.dx * size.width, n.dy * size.height);

      final localPts = _norm.map(toLocal).toList();
      final localDrawing = _drawing?.map(toLocal).toList();

      // 有效指示线端点：手动优先，否则自动。
      final auto = _autoDimensionEndpoints();
      final effLenA = _lenA ?? auto.lenA;
      final effLenB = _lenB ?? auto.lenB;
      final effWidA = _widA ?? auto.widA;
      final effWidB = _widB ?? auto.widB;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _onPanStart(_toNorm(d.localPosition, size)),
        onPanUpdate: (d) => _onPanUpdate(_toNorm(d.localPosition, size)),
        onPanEnd: (_) => _onPanEnd(),
        child: CustomPaint(
          painter: _WoundPolygonPainter(
            points: localPts,
            drawing: localDrawing,
            mode: widget.mode,
            readonly: widget.readonly,
            lenA: toLocal(effLenA),
            lenB: toLocal(effLenB),
            widA: toLocal(effWidA),
            widB: toLocal(effWidB),
            showWidthLine: auto.hasWidth || (_widA != null && _widB != null),
          ),
          size: size,
        ),
      );
    });
  }

  Offset _toNorm(Offset local, Size size) =>
      Offset(local.dx / size.width, local.dy / size.height);

  void _onPanStart(Offset n) {
    if (widget.mode == WoundOverlayMode.draw) {
      _drawing = [n];
      setState(() {});
      return;
    }
    // 命中半径按归一化距离（≈30px @ 宽 500 基准）
    const hit = 0.07;
    // 1) 指示线端点（青色长径 → 橙色宽径）优先于轮廓顶点。
    final auto = _autoDimensionEndpoints();
    final effLenA = _lenA ?? auto.lenA;
    final effLenB = _lenB ?? auto.lenB;
    final effWidA = _widA ?? auto.widA;
    final effWidB = _widB ?? auto.widB;
    if ((effLenA - n).distance < hit) {
      _dragging = _DragTarget.lengthA;
      setState(() {});
      return;
    }
    if ((effLenB - n).distance < hit) {
      _dragging = _DragTarget.lengthB;
      setState(() {});
      return;
    }
    if ((effWidA - n).distance < hit) {
      _dragging = _DragTarget.widthA;
      setState(() {});
      return;
    }
    if ((effWidB - n).distance < hit) {
      _dragging = _DragTarget.widthB;
      setState(() {});
      return;
    }
    // 2) 轮廓顶点。
    for (int i = 0; i < _norm.length; i++) {
      if ((_norm[i] - n).distance < 0.06) {
        _draggingIndex = i;
        setState(() {});
        return;
      }
    }
  }

  void _onPanUpdate(Offset n) {
    if (widget.mode == WoundOverlayMode.draw) {
      final last = _drawing!.last;
      if ((n - last).distance > 0.004) {
        _drawing!.add(n);
        setState(() {});
      }
      return;
    }
    final clamped = Offset(n.dx.clamp(0.0, 1.0), n.dy.clamp(0.0, 1.0));
    if (_dragging != null) {
      switch (_dragging!) {
        case _DragTarget.lengthA:
          _lenA = clamped;
        case _DragTarget.lengthB:
          _lenB = clamped;
        case _DragTarget.widthA:
          _widA = clamped;
        case _DragTarget.widthB:
          _widB = clamped;
      }
      _markModified();
      _emit();
      setState(() {});
      return;
    }
    if (_draggingIndex != null) {
      _norm[_draggingIndex!] = clamped;
      _markModified();
      _emit();
      setState(() {});
    }
  }

  void _onPanEnd() {
    if (widget.mode == WoundOverlayMode.draw && _drawing != null) {
      // 抽稀阈值按归一化距离（≈14px @ 350px 宽）
      final simplified = _simplify(_drawing!, 0.04);
      if (simplified.length >= 3) {
        _norm = simplified;
        _markModified();
        _emit();
      }
      _drawing = null;
      setState(() {});
      return;
    }
    _draggingIndex = null;
    _dragging = null;
    setState(() {});
  }

  void _markModified() {
    if (!_modified) {
      _modified = true;
      widget.onModified?.call();
    }
  }
}

enum _DragTarget { lengthA, lengthB, widthA, widthB }

// ── 几何计算 ────────────────────────────────────────────────

/// 点对最大跨度：最长径（最大点对距离）与垂直方向最大投影（宽径）。
({double length, double width, Offset a, Offset b}) _maxSpan(
    List<Offset> pts) {
  if (pts.isEmpty) return (length: 0, width: 0, a: Offset.zero, b: Offset.zero);
  // 抽稀到 ≤80 点，避免手绘点集 O(n²) 过大
  var src = pts;
  if (src.length > 80) {
    final step = src.length / 80;
    src = List.generate(80, (i) => src[(i * step).floor()]);
  }
  double best = -1;
  Offset pa = src.first, pb = src.first;
  for (int i = 0; i < src.length; i++) {
    for (int j = i + 1; j < src.length; j++) {
      final d = (src[i] - src[j]).distance;
      if (d > best) {
        best = d;
        pa = src[i];
        pb = src[j];
      }
    }
  }
  final axis = (pb - pa) == Offset.zero
      ? const Offset(1, 0)
      : (pb - pa) / (pb - pa).distance;
  final perp = Offset(-axis.dy, axis.dx);
  var minProj = double.infinity, maxProj = double.negativeInfinity;
  for (final p in src) {
    final proj = (p - pa).dx * perp.dx + (p - pa).dy * perp.dy;
    minProj = math.min(minProj, proj);
    maxProj = math.max(maxProj, proj);
  }
  return (
    length: best,
    width: math.max(0, maxProj - minProj),
    a: pa,
    b: pb,
  );
}

/// Shoelace 多边形面积。
double _shoelaceArea(List<Offset> pts) {
  double sum = 0;
  for (int i = 0; i < pts.length; i++) {
    final j = (i + 1) % pts.length;
    sum += pts[i].dx * pts[j].dy - pts[j].dx * pts[i].dy;
  }
  return sum / 2;
}

/// 等距抽稀（保留形状）。
List<Offset> _simplify(List<Offset> pts, double minDist) {
  final out = <Offset>[pts.first];
  for (final p in pts.skip(1)) {
    if ((p - out.last).distance >= minDist) out.add(p);
  }
  if (out.length < 3) out.add(pts.last);
  return out;
}

// ── 绘制 ────────────────────────────────────────────────────

class _WoundPolygonPainter extends CustomPainter {
  final List<Offset> points; // 容器坐标
  final List<Offset>? drawing; // 容器坐标
  final WoundOverlayMode mode;
  final bool readonly;
  final Offset lenA, lenB; // 最长径指示线端点（容器坐标）
  final Offset widA, widB; // 宽径指示线端点（容器坐标）
  final bool showWidthLine;

  _WoundPolygonPainter({
    required this.points,
    required this.mode,
    required this.readonly,
    required this.lenA,
    required this.lenB,
    required this.widA,
    required this.widB,
    required this.showWidthLine,
    this.drawing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 手绘进行中的轨迹
    if (drawing != null && drawing!.length > 1) {
      final path = Path()..moveTo(drawing!.first.dx, drawing!.first.dy);
      for (final p in drawing!.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppTheme.actionBlue
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    }

    if (points.length < 3) return;

    final path = Path()..addPolygon(points, true);
    canvas.drawPath(
        path,
        Paint()
          ..color = AppTheme.actionBlue.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = AppTheme.actionBlue
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);

    // 最长径指示线（青色实线）与宽径指示线（橙色虚线）
    final interactive = mode == WoundOverlayMode.adjust && !readonly;
    if ((lenB - lenA).distance > 8) {
      _drawDimensionLine(canvas, lenA, lenB, AppTheme.aiContour,
          dashed: false, handle: interactive);
      if (showWidthLine && (widB - widA).distance > 8) {
        _drawDimensionLine(canvas, widA, widB, AppTheme.statusPendingSign,
            dashed: true, handle: interactive);
      }
    }

    // 顶点把手（调整模式）
    if (interactive) {
      for (final p in points) {
        canvas.drawCircle(p, 10, Paint()..color = Colors.white);
        canvas.drawCircle(p, 8, Paint()..color = AppTheme.actionBlue);
      }
    }
  }

  void _drawDimensionLine(Canvas canvas, Offset a, Offset b, Color color,
      {bool dashed = false, bool handle = false}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(a, b, paint);
    } else {
      const dash = 7.0, gap = 5.0;
      final total = (b - a).distance;
      final dir = (b - a) / total;
      var start = a;
      var dist = 0.0;
      while (dist < total) {
        final segEnd = start + dir * math.min(dash, total - dist);
        canvas.drawLine(start, segEnd, paint);
        dist += dash + gap;
        start = a + dir * math.min(dist, total);
      }
    }
    for (final p in [a, b]) {
      if (handle) {
        // 可拖动端点：白底大圆 + 彩色内圆，便于手指命中。
        canvas.drawCircle(p, 18, Paint()..color = Colors.white);
        canvas.drawCircle(
            p,
            13,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
        // 中心实心点
        canvas.drawCircle(p, 4, Paint()..color = color);
      } else {
        canvas.drawCircle(p, 4, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WoundPolygonPainter old) =>
      old.points != points ||
      old.drawing != drawing ||
      old.mode != mode ||
      old.readonly != readonly ||
      old.lenA != lenA ||
      old.lenB != lenB ||
      old.widA != widA ||
      old.widB != widB ||
      old.showWidthLine != showWidthLine;
}
