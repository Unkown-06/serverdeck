import 'package:flutter/material.dart';

import '../utils/format.dart';
import '../widgets/cards.dart';

/// The "Server" tab: CPU, RAM, swap, disk, network and uptime.
/// To add or remove a line, edit the list inside build().
class ServerTab extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final String? error;
  final Future<void> Function() onRefresh;

  const ServerTab({
    super.key,
    required this.stats,
    required this.error,
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
    final temp = s['cpu_temp'] == null ? 'not available' : '${s['cpu_temp']} °C';
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ErrorText(error),
          StatBar(
            label: 'CPU',
            percent: s['cpu_percent'] as num,
            detail: 'temp $temp',
          ),
          StatBar(
            label: 'RAM',
            percent: s['ram_percent'] as num,
            detail: '${fmtBytes(s['ram_used'] as num)} / ${fmtBytes(s['ram_total'] as num)}',
          ),
          StatBar(
            label: 'Swap',
            percent: s['swap_percent'] as num,
            detail: '${fmtBytes(s['swap_used'] as num)} / ${fmtBytes(s['swap_total'] as num)}',
          ),
          StatBar(
            label: 'Disk',
            percent: s['disk_percent'] as num,
            detail: '${fmtBytes(s['disk_used'] as num)} / ${fmtBytes(s['disk_total'] as num)}',
          ),
          InfoCard('Disk read ${fmtBytes(s['disk_read_bps'] as num)}/s    '
              'write ${fmtBytes(s['disk_write_bps'] as num)}/s'),
          InfoCard('Network down ${fmtBytes(s['net_down_bps'] as num)}/s    '
              'up ${fmtBytes(s['net_up_bps'] as num)}/s'),
          InfoCard('Data since boot: down ${fmtBytes(s['net_total_down'] as num)}, '
              'up ${fmtBytes(s['net_total_up'] as num)}'),
          InfoCard('Uptime: ${fmtUptime(s['uptime_seconds'] as num)}'),
        ],
      ),
    );
  }
}
