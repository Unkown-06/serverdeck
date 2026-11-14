import 'package:flutter/material.dart';

import '../widgets/cards.dart';
import '../widgets/container_card.dart';

/// The "Docker" tab: the list of containers.
class DockerTab extends StatelessWidget {
  final List<dynamic>? containers;
  final String? error;
  final Set<String> working;
  final bool canAct;
  final Future<void> Function() onRefresh;
  final void Function(String name) onDetails;
  final void Function(int port) onOpen;
  final void Function(String name, String action) onAction;

  const DockerTab({
    super.key,
    required this.containers,
    required this.error,
    required this.working,
    required this.canAct,
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
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ErrorText(error),
          if (list.isEmpty) const Text('No containers found'),
          for (final c in list)
            ContainerCard(
              container: Map<String, dynamic>.from(c as Map),
              working: working.contains((c as Map)['name']),
              canAct: canAct,
              onDetails: onDetails,
              onOpen: onOpen,
              onAction: onAction,
            ),
        ],
      ),
    );
  }
}
