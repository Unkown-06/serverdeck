import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/format.dart';
import 'glass_card.dart';

/// One Docker container: name, status, usage and its buttons.
class ContainerCard extends StatelessWidget {
  final Map<String, dynamic> container;
  final bool working; // an action is running on this container
  final bool canControl; // operators and administrators only
  final void Function(String name) onDetails;
  final void Function(int port) onOpen;
  final void Function(String name, String action) onAction;

  const ContainerCard({
    super.key,
    required this.container,
    required this.working,
    required this.canControl,
    required this.onDetails,
    required this.onOpen,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = container;
    final name = c['name'] as String;
    final state = c['state'] as String;
    final running = state == 'running';
    final usage = c['usage'];
    final port = c['web_port'];

    Widget action(IconData icon, String label, VoidCallback onTap, {Color? color}) {
      return TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color)),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (working)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  StatusPill(
                    running ? 'Running' : cap(state),
                    running ? AppColors.good : AppColors.bad,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${c['image']} · ${c['status']}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            if (running && usage != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _chip(Icons.memory_rounded, 'CPU ${usage['cpu']}'),
                  const SizedBox(width: 8),
                  Flexible(child: _chip(Icons.sd_storage_rounded, '${usage['mem']}')),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              children: [
                action(Icons.info_outline_rounded, 'Details', () => onDetails(name)),
                if (running && port != null)
                  action(Icons.open_in_new_rounded, 'Open', () => onOpen(port as int)),
                if (canControl && !working) ...[
                  if (running) ...[
                    action(Icons.restart_alt_rounded, 'Restart', () => onAction(name, 'restart')),
                    action(Icons.stop_rounded, 'Stop', () => onAction(name, 'stop'),
                        color: AppColors.bad),
                  ] else
                    action(Icons.play_arrow_rounded, 'Start', () => onAction(name, 'start'),
                        color: AppColors.good),
                  action(Icons.system_update_alt_rounded, 'Update', () => onAction(name, 'update')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
