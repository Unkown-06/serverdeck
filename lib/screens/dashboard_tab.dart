import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/format.dart';
import '../widgets/gauge.dart';
import '../widgets/glass_card.dart';
import '../widgets/sparkline.dart';

/// The first tab: gauges and graphs for CPU, memory, disk and network.
class DashboardTab extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? info;
  final String? error;
  final List<double> cpuHistory;
  final List<double> downHistory;
  final Future<void> Function() onRefresh;

  const DashboardTab({
    super.key,
    required this.stats,
    required this.info,
    required this.error,
    required this.cpuHistory,
    required this.downHistory,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (s == null) {
      return Center(
        child: error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error!, textAlign: TextAlign.center),
              )
            : const CircularProgressIndicator(),
      );
    }
    final cpu = (s['cpu_percent'] as num).toDouble();
    final ram = (s['ram_percent'] as num).toDouble();
    final disk = (s['disk_percent'] as num).toDouble();
    final swap = (s['swap_percent'] as num).toDouble();
    final temp = s['cpu_temp'] as num?;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _hero(s),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RingGauge(
                  value: cpu,
                  centerText: '${cpu.round()}%',
                  label: 'CPU',
                  caption: temp == null ? null : '${temp.toStringAsFixed(0)}°C',
                ),
                RingGauge(
                  value: ram,
                  centerText: '${ram.round()}%',
                  label: 'Memory',
                  caption: fmtBytes(s['ram_used'] as num),
                ),
                RingGauge(
                  value: disk,
                  centerText: '${disk.round()}%',
                  label: 'Disk',
                  caption: fmtBytes(s['disk_used'] as num),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _mini(
                  Icons.thermostat_rounded,
                  'Temperature',
                  temp == null ? 'n/a' : '${temp.toStringAsFixed(0)}°C',
                  temp == null ? AppColors.muted : _tempColor(temp),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _mini(
                  Icons.swap_horiz_rounded,
                  'Swap',
                  '${swap.round()}%',
                  statusColor(swap),
                  caption: '${fmtBytes(s['swap_used'] as num)} of ${fmtBytes(s['swap_total'] as num)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(Icons.show_chart_rounded, 'CPU load', '${cpu.round()}%'),
                const SizedBox(height: 10),
                Sparkline(values: cpuHistory, maxY: 100, color: AppColors.accent),
                const Text('last 5 minutes', style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(Icons.swap_vert_rounded, 'Network', ''),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _speed(Icons.arrow_downward_rounded, 'Download',
                          fmtSpeed(s['net_down_bps'] as num), AppColors.accent),
                    ),
                    Expanded(
                      child: _speed(Icons.arrow_upward_rounded, 'Upload',
                          fmtSpeed(s['net_up_bps'] as num), AppColors.accent2),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Sparkline(values: downHistory, color: AppColors.accent),
                const SizedBox(height: 6),
                Text(
                  'Since boot: ↓ ${fmtBytes(s['net_total_down'] as num)}   ↑ ${fmtBytes(s['net_total_up'] as num)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(Icons.storage_rounded, 'Disk activity', ''),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _speed(Icons.north_east_rounded, 'Read',
                          fmtSpeed(s['disk_read_bps'] as num), AppColors.good),
                    ),
                    Expanded(
                      child: _speed(Icons.south_west_rounded, 'Write',
                          fmtSpeed(s['disk_write_bps'] as num), AppColors.warn),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _tempColor(num t) {
    if (t >= 80) return AppColors.bad;
    if (t >= 65) return AppColors.warn;
    return AppColors.good;
  }

  Widget _hero(Map<String, dynamic> s) {
    final hostname = (info?['hostname'] as String?) ?? 'Your server';
    final os = info?['os'] as String?;
    final needsReboot = info?['reboot_required'] == true;
    return GlassCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF14405A), Color(0xFF1C2A5C)],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: accentGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.dns_rounded, color: AppColors.onAccent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hostname,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                if (os != null)
                  Text(os, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const StatusPill('Online', AppColors.good, icon: Icons.check_circle_rounded),
                    StatusPill(
                      'Up ${fmtUptime(s['uptime_seconds'] as num)}',
                      AppColors.accent,
                      icon: Icons.schedule_rounded,
                    ),
                    if (needsReboot)
                      const StatusPill('Restart needed', AppColors.warn,
                          icon: Icons.restart_alt_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(IconData icon, String text, String trailing) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
        if (trailing.isNotEmpty)
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _speed(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _mini(IconData icon, String label, String value, Color color, {String? caption}) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          if (caption != null)
            Text(caption, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ],
      ),
    );
  }
}
