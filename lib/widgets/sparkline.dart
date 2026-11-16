import 'dart:math';

import 'package:flutter/material.dart';

/// A small line chart with a soft fill, for "the last few minutes".
class Sparkline extends StatelessWidget {
  final List<double> values;
  final double? maxY; // null = fit to the data
  final Color color;
  final double height;
  final int capacity; // how many points fill the whole width

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.maxY,
    this.height = 70,
    this.capacity = 60,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(List<double>.from(values), maxY, color, capacity),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final double? maxY;
  final Color color;
  final int capacity;
  _SparkPainter(this.values, this.maxY, this.color, this.capacity);

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), base);
    if (values.length < 2) return;

    final top = maxY ?? max(values.reduce(max), 1.0);
    final step = size.width / (capacity - 1);
    Offset point(int i) {
      final x = size.width - (values.length - 1 - i) * step;
      final y = size.height - (values[i].clamp(0.0, top) / top) * (size.height - 6) - 3;
      return Offset(x, y);
    }

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      final a = point(i - 1);
      final b = point(i);
      final mid = (a.dx + b.dx) / 2;
      line.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }

    final fill = Path.from(line)
      ..lineTo(point(values.length - 1).dx, size.height)
      ..lineTo(point(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}
