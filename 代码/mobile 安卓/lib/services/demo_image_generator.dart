import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Generates a synthetic wound photo (PNG) for demo mode on platforms
/// without camera support (macOS desktop).
///
/// The image mimics a leg wound with granulation tissue and necrotic spots,
/// so the review screen has something real to draw an AI polygon over.
class DemoImageGenerator {
  static Future<String> generateWoundImage(String dir) async {
    const w = 900;
    const h = 1200;
    final rng = Random(42);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Skin background.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFFE8B88A),
    );

    // Wound bed.
    const woundCenter = Offset(450, 600);
    canvas.drawCircle(woundCenter, 260, Paint()..color = const Color(0xFFC0392B));
    canvas.drawCircle(
      woundCenter,
      260,
      Paint()
        ..color = const Color(0xFF8E2A18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );

    // Granulation tissue.
    for (var i = 0; i < 48; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final r = rng.nextDouble() * 210;
      final d = 12 + rng.nextDouble() * 22;
      canvas.drawCircle(
        woundCenter + Offset(cos(a), sin(a)) * r,
        d,
        Paint()..color = const Color(0xFFE74C3C).withOpacity(0.85),
      );
    }

    // Necrotic (eschar) spots.
    for (var i = 0; i < 14; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final r = rng.nextDouble() * 140;
      final d = 18 + rng.nextDouble() * 30;
      canvas.drawCircle(
        woundCenter + Offset(cos(a), sin(a)) * r,
        d,
        Paint()..color = const Color(0xFF3B2314),
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(w, h);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      '$dir/demo_wound_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    return file.path;
  }
}
