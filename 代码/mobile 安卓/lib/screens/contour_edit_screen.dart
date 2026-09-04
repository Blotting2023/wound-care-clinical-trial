import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../widgets/canvas_adjust_overlay.dart';

/// 全屏轮廓编辑结果。
class ContourEditResult {
  final List<Offset> points; // 归一化 0..1
  final WoundMetrics metrics;
  final bool modified;
  const ContourEditResult({
    required this.points,
    required this.metrics,
    required this.modified,
  });
}

/// 全屏轮廓编辑页：
/// 照片放大铺满屏幕，拖动关键点或手绘轮廓，实时计算面积/最长径/宽径。
/// 点右上角"完成"返回结果。
class ContourEditScreen extends StatefulWidget {
  final String imagePath;
  final List<Offset> initialPoints; // 归一化 0..1
  final double? aiLengthCm;

  const ContourEditScreen({
    super.key,
    required this.imagePath,
    required this.initialPoints,
    this.aiLengthCm,
  });

  @override
  State<ContourEditScreen> createState() => _ContourEditScreenState();
}

class _ContourEditScreenState extends State<ContourEditScreen> {
  double _aspect = 3 / 4; // 图片宽高比，initState 异步解码后更新
  late List<Offset> _points;
  bool _modified = false;
  WoundOverlayMode _mode = WoundOverlayMode.adjust;
  WoundMetrics? _metrics;
  Key _overlayKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _points = List.from(widget.initialPoints);
    _loadImageAspect();
  }

  Future<void> _loadImageAspect() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width.toDouble();
      final h = frame.image.height.toDouble();
      if (w > 0 && h > 0 && mounted) {
        setState(() => _aspect = w / h);
      }
      frame.image.dispose();
      codec.dispose();
    } catch (_) {
      // 解码失败保持 3/4 默认
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leadingWidth: 96,
          leading: TextButton.icon(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: Colors.white),
            label: const Text('返回',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            onPressed: _onBack,
          ),
          titleSpacing: 0,
          title: const Text('调整创面轮廓',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _finish,
                child: const Text('完成',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 放大的照片 + 可交互轮廓层
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _aspect,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(widget.imagePath),
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium),
                        CanvasAdjustOverlay(
                          key: _overlayKey,
                          initialPoints: _points,
                          imageAspect: _aspect,
                          aiLengthCm: widget.aiLengthCm,
                          mode: _mode,
                          onChanged: (pts) => _points = pts,
                          onMetrics: (m) => setState(() => _metrics = m),
                          onModified: () => _modified = true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 实时测量值
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _liveMetric('面积',
                        (_metrics?.areaCm2 ?? 0).toStringAsFixed(1), 'cm²'),
                    _liveMetric('最长径',
                        (_metrics?.lengthCm ?? 0).toStringAsFixed(1), 'cm'),
                    _liveMetric('宽度',
                        (_metrics?.widthCm ?? 0).toStringAsFixed(1), 'cm'),
                  ],
                ),
              ),
              // 模式切换 + 重置
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        icon: Icons.control_camera_rounded,
                        label: '调整关键点',
                        selected: _mode == WoundOverlayMode.adjust,
                        onTap: () => setState(
                            () => _mode = WoundOverlayMode.adjust),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeButton(
                        icon: Icons.draw_rounded,
                        label: '手绘轮廓',
                        selected: _mode == WoundOverlayMode.draw,
                        onTap: () =>
                            setState(() => _mode = WoundOverlayMode.draw),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeButton(
                        icon: Icons.restart_alt_rounded,
                        label: '重置AI轮廓',
                        selected: false,
                        onTap: () => setState(() {
                          _modified = false;
                          _metrics = null;
                          _mode = WoundOverlayMode.adjust;
                          _points = List.from(widget.initialPoints);
                          _overlayKey = UniqueKey();
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _mode == WoundOverlayMode.draw
                      ? '手绘模式：沿创面边缘画一圈，松手自动闭合'
                      : '拖动蓝点修正轮廓 · 拖动青/橙端点调整长宽指示线',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 完成：返回当前轮廓与测量结果。
  void _finish() {
    Navigator.pop(
      context,
      ContourEditResult(
        points: _points,
        metrics: _metrics ?? const WoundMetrics(),
        modified: _modified,
      ),
    );
  }

  /// 返回：已修改时询问是否保留。
  Future<void> _onBack() async {
    if (!_modified) {
      Navigator.pop(context);
      return;
    }
    final keep = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('轮廓已调整'),
        content: const Text('是否保留本次轮廓调整并返回？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('放弃修改'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保留并返回'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (keep == true) {
      _finish();
    } else if (keep == false) {
      Navigator.pop(context);
    }
  }

  Widget _liveMetric(String label, String value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 2),
            Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: selected ? AppTheme.actionBlue : Colors.white12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppTheme.actionBlue : Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                )),
          ],
        ),
      ),
    );
  }
}
