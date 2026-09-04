import 'package:flutter/material.dart';

/// Camera overlay showing targeting crosshair and calibration card detection ROI
class CalibrationOverlay extends StatelessWidget {
  const CalibrationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CalibrationPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _CalibrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final crossLen = 40.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Crosshair
    canvas.drawLine(Offset(center.dx - crossLen, center.dy), Offset(center.dx + crossLen, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - crossLen), Offset(center.dx, center.dy + crossLen), paint);

    // Circle
    canvas.drawCircle(center, 20, paint);

    // Calibration card ROI (rectangle)
    final roiW = size.width * 0.6, roiH = size.height * 0.4;
    final roi = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: roiW, height: roiH),
      const Radius.circular(8),
    );
    final roiPaint = Paint()
      ..color = const Color(0x4000796B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(roi, roiPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
