import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/container_card.dart';
import '../widgets/glass_card.dart';

/// The Docker tab: the list of containers.
class DockerTab extends StatelessWidget {
  final List<dynamic>? containers;
  final String? error;
  final Set<String> working;
  final bool canControl;
  final Future<void> Function() onRefresh;
  final void Function(String name) onDetails;
  final void Function(int port) onOpen;
  final void Function(String name, String action) onAction;

  const DockerTab({
    super.key,
    required this.containers,
    required this.error,
    required this.working,
    required this.canControl,
    required this.onRefresh,
    required this.onDetails,
    required this.onOpen,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final list = containers;
    if (list == null) {
      return Center(
        child: error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error!, textAlign: TextAlign.center),
              )
            : const CircularProgressIndicator(),
      );
    }
    final running = list.where((c) => (c as Map)['state'] == 'running').length;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          ErrorNote(error),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Row(
              children: [
                StatusPill('$running running', AppColors.good, icon: Icons.play_circle_rounded),
                const SizedBox(width: 8),
                StatusPill(
                  '${list.length - running} stopped',
                  list.length - running > 0 ? AppColors.bad : AppColors.muted,
                  icon: Icons.stop_circle_rounded,
                ),
              ],
            ),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No containers found')),
            ),
          for (final c in list)
            ContainerCard(
              container: Map<String, dynamic>.from(c as Map),
              working: working.contains((c as Map)['name']),
              canControl: canControl,
              onDetails: onDetails,
              onOpen: onOpen,
              onAction: onAction,
            ),
        ],
      ),
    );
  }
}
