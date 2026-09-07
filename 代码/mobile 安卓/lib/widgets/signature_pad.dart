/// 简易手写签名画板（A 通道 eConsent 用）。
///
/// 不引入 signature 包（避免 pubspec 改动），用 Stack + GestureDetector +
/// CustomPainter 画 List<List<Offset>> 笔迹。提交时输出：
///   1) `signatureStrokeJson` = JSON 字符串
///   2) `signaturePath` = (V1 demo) 占位 string，V4 接 COS 时换 COS key
///
/// 笔迹坐标归一化到 0..1 范围（防设备分辨率不一致影响回放）。
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class SignaturePad extends StatefulWidget {
  final double height;
  final ValueChanged<List<List<Offset>>>? onChanged;
  const SignaturePad({
    super.key,
    this.height = 200,
    this.onChanged,
  });

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
    widget.onChanged?.call(_strokes);
  }

  bool get isEmpty => _strokes.isEmpty;

  /// 笔迹转归一化 JSON 字符串
  String toJsonString(Size canvasSize) {
    final list = _strokes.map((stroke) {
      return stroke
          .map((p) => {
                'x': (p.dx / canvasSize.width).toStringAsFixed(4),
                'y': (p.dy / canvasSize.height).toStringAsFixed(4),
              })
          .toList();
    }).toList();
    return jsonEncode(list);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanStart: (d) {
            setState(() {
              _currentStroke = [d.localPosition];
              _strokes.add(_currentStroke!);
            });
            widget.onChanged?.call(_strokes);
          },
          onPanUpdate: (d) {
            setState(() {
              _currentStroke?.add(d.localPosition);
            });
            widget.onChanged?.call(_strokes);
          },
          onPanEnd: (_) {
            setState(() {
              _currentStroke = null;
            });
            widget.onChanged?.call(_strokes);
          },
          child: CustomPaint(
            painter: _SignaturePainter(strokes: _strokes),
            size: size,
          ),
        );
      }),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.textPrimary
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) {
        // 单独点
        if (stroke.isNotEmpty) {
          canvas.drawCircle(stroke.first, 1.2, paint..style = PaintingStyle.fill);
          paint.style = PaintingStyle.stroke;
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) =>
      old.strokes.length != strokes.length;
}
