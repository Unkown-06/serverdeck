import 'package:flutter/material.dart';

/// Small building blocks used by the tabs.

/// A card with a label and a progress bar (CPU, RAM, Disk...).
/// The bar turns amber at 75% and red at 90%.
class StatBar extends StatelessWidget {
  final String label;
  final num percent;
  final String detail;

  const StatBar({
    super.key,
    required this.label,
    required this.percent,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final p = percent.toDouble();
    final color = p >= 90
        ? Colors.red.shade300
        : p >= 75
            ? Colors.amber
            : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label: ${p.toStringAsFixed(0)}%   ($detail)'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (p / 100).clamp(0.0, 1.0),
              color: color,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card with one line of text (uptime, network speed...).
class InfoCard extends StatelessWidget {
  final String text;
  const InfoCard(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(alignment: Alignment.centerLeft, child: Text(text)),
      ),
    );
  }
}

/// Red error text shown above a list. Shows nothing when there is no error.
class ErrorText extends StatelessWidget {
  final String? error;
  const ErrorText(this.error, {super.key});

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(error!, style: TextStyle(color: Colors.red.shade300)),
    );
  }
}
