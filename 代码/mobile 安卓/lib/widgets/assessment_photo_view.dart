import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/demo_image_generator.dart';
import 'canvas_adjust_overlay.dart';

/// 评估照片回看视图（只读）：
/// - [photoPath] 存在且可读 → 显示真实照片；
/// - 否则（demo 历史种子数据）→ 生成一张合成创面图兜底（静态缓存）。
/// - [polygonJson]（图片像素坐标）叠加轮廓 + 长宽指示线，全部只读。
class AssessmentPhotoView extends StatefulWidget {
  final String? photoPath;
  final String? polygonJson;
  final double? aiLengthCm;
  final double fallbackAspect; // 无轮廓时按此比例展示

  const AssessmentPhotoView({
    super.key,
    this.photoPath,
    this.polygonJson,
    this.aiLengthCm,
    this.fallbackAspect = 3 / 4,
  });

  @override
  State<AssessmentPhotoView> createState() => _AssessmentPhotoViewState();
}

class _AssessmentPhotoViewState extends State<AssessmentPhotoView> {
  static String? _demoCache; // 演示兜底图（一次生成，全局复用）

  String? _resolvedPath;
  double _aspect = 3 / 4;
  double _imgW = 900, _imgH = 1200;
  List<Offset>? _points;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    // 1) 照片路径：本地文件存在 → 用之；否则生成演示图兜底。
    String? path;
    if (widget.photoPath != null && File(widget.photoPath!).existsSync()) {
      path = widget.photoPath;
    } else {
      if (_demoCache == null || !File(_demoCache!).existsSync()) {
        final dir = await getTemporaryDirectory();
        _demoCache = await DemoImageGenerator.generateWoundImage(dir.path);
      }
      path = _demoCache;
    }

    // 2) 解码图片尺寸（轮廓像素坐标归一化基准）。
    double w = 900, h = 1200;
    try {
      final bytes = await File(path!).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (frame.image.width > 0 && frame.image.height > 0) {
        w = frame.image.width.toDouble();
        h = frame.image.height.toDouble();
      }
      frame.image.dispose();
      codec.dispose();
    } catch (_) {/* 使用兜底尺寸 */}

    // 3) 解析轮廓（图片像素坐标 → 归一化 0..1）。
    List<Offset>? pts;
    final poly = widget.polygonJson;
    if (poly != null && poly.isNotEmpty) {
      try {
        final list = jsonDecode(poly) as List;
        final parsed = list
            .map((p) => Offset(
                ((p['x'] as num).toDouble() / w).clamp(0.0, 1.0),
                ((p['y'] as num).toDouble() / h).clamp(0.0, 1.0)))
            .toList();
        if (parsed.length >= 3) pts = parsed;
      } catch (_) {/* 忽略非法轮廓 */ }
    }

    if (!mounted) return;
    setState(() {
      _resolvedPath = path;
      _imgW = w;
      _imgH = h;
      _aspect = pts != null ? w / h : widget.fallbackAspect;
      _points = pts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: _aspect,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_resolvedPath != null)
              Image.file(File(_resolvedPath!),
                  fit: BoxFit.cover, filterQuality: FilterQuality.medium)
            else
              Container(color: Colors.black12),
            if (_points != null)
              IgnorePointer(
                child: CanvasAdjustOverlay(
                  initialPoints: _points!,
                  imageAspect: _imgW / _imgH,
                  aiLengthCm: widget.aiLengthCm,
                  mode: WoundOverlayMode.adjust,
                  readonly: true,
                  onChanged: (_) {},
                  onMetrics: (_) {},
                ),
              ),
          ],
        ),
      ),
    );
  }
}
