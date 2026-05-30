import 'dart:math' as math;
import 'package:flutter/material.dart';

class WoodGrainBackground extends StatelessWidget {
  const WoodGrainBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.expand(
      child: CustomPaint(
        painter: _WoodGrainPainter(isDark: isDark),
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  final bool isDark;
  const _WoodGrainPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = isDark
        ? const Color(0xFF2C1F10).withAlpha(180)
        : const Color(0xFFE8CC99).withAlpha(200);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = baseColor);

    final rng = math.Random(42);
    final grainColors = isDark
        ? [
            const Color(0xFF3D2912),
            const Color(0xFF4A3318),
            const Color(0xFF251508),
            const Color(0xFF5C4020),
          ]
        : [
            const Color(0xFFD4A850),
            const Color(0xFFC89838),
            const Color(0xFFEED090),
            const Color(0xFFDCB460),
          ];

    for (int i = 0; i < 40; i++) {
      final y = rng.nextDouble() * size.height;
      final amplitude = 4.0 + rng.nextDouble() * 12.0;
      final frequency = 0.008 + rng.nextDouble() * 0.015;
      final phase = rng.nextDouble() * math.pi * 2;
      final color = grainColors[rng.nextInt(grainColors.length)]
          .withAlpha(isDark ? 80 + rng.nextInt(60) : 60 + rng.nextInt(50));
      final strokeW = 0.5 + rng.nextDouble() * 1.5;

      final path = Path();
      path.moveTo(0, y + math.sin(phase) * amplitude);
      for (double x = 1; x <= size.width; x += 2) {
        final ny = y +
            math.sin(x * frequency + phase) * amplitude +
            math.sin(x * frequency * 2.3 + phase * 1.7) * amplitude * 0.3;
        path.lineTo(x, ny);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
    }

    for (int i = 0; i < 5; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final rx = 20.0 + rng.nextDouble() * 40.0;
      final ry = 8.0 + rng.nextDouble() * 16.0;
      final knotColor = isDark
          ? const Color(0xFF1A0D04).withAlpha(80)
          : const Color(0xFFA07030).withAlpha(60);

      for (int j = 0; j < 6; j++) {
        final scale = 1.0 + j * 0.5;
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, cy),
              width: rx * scale,
              height: ry * scale),
          Paint()
            ..color = knotColor.withAlpha((80 - j * 12).clamp(0, 255))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WoodGrainPainter old) => old.isDark != isDark;
}
