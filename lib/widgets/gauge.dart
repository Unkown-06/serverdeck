import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// A round gauge, like a speedometer ring. Used for CPU, RAM and disk.
class RingGauge extends StatelessWidget {
  final double value; // 0 to 100
  final String centerText;
  final String label;
  final String? caption;
  final double size;

  const RingGauge({
    super.key,
    required this.value,
    required this.centerText,
    required this.label,
    this.caption,
    this.size = 92,
  });

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 100.0).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final color = statusColor(v);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _RingPainter(v / 100, color),
                child: Center(
                  child: Text(
                    centerText,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (caption != null)
              Text(caption!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0 to 1
  final Color color;
  _RingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.08);
    final bar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -pi / 2, 2 * pi, false, track);
    if (progress > 0.005) {
      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, bar);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
