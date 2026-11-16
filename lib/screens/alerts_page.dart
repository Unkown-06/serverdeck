import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/format.dart';
import '../widgets/glass_card.dart';

/// The list of alerts (high CPU, container stopped, disk full...).
/// [alerts] updates by itself while this screen is open.
class AlertsPage extends StatelessWidget {
  final ValueNotifier<List<Map<String, dynamic>>> alerts;
  final Future<void> Function() onRefresh;

  const AlertsPage({super.key, required this.alerts, required this.onRefresh});

  IconData _icon(String level) {
    switch (level) {
      case 'critical':
        return Icons.error_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _color(String level) {
    switch (level) {
      case 'critical':
        return AppColors.bad;
      case 'warning':
        return AppColors.warn;
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Alerts'),
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: alerts,
        builder: (context, list, _) {
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.notifications_none_rounded, size: 56, color: AppColors.muted),
                  SizedBox(height: 12),
                  Center(
                    child: Text('No alerts. Everything looks fine.',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                ],
              ),
            );
          }
          final items = list.reversed.toList();
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final a = items[i];
                final level = a['level'] as String;
                final color = _color(level);
                final message = (a['message'] as String?) ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_icon(level), color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a['title'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              if (message.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(message, style: const TextStyle(fontSize: 13)),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                '${timeAgo(a['time'] as num)} · ${fmtDate(a['time'] as num)}',
                                style: const TextStyle(color: AppColors.muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
