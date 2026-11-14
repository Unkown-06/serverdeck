import 'package:flutter/material.dart';

/// One Docker container: name, status, usage and its buttons.
class ContainerCard extends StatelessWidget {
  final Map<String, dynamic> container;
  final bool working; // an action is running on this container
  final bool canAct; // operators and administrators only
  final void Function(String name) onDetails;
  final void Function(int port) onOpen;
  final void Function(String name, String action) onAction;

  const ContainerCard({
    super.key,
    required this.container,
    required this.working,
    required this.canAct,
    required this.onDetails,
    required this.onOpen,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = container;
    final name = c['name'] as String;
    final running = c['state'] == 'running';
    final usage = c['usage'];
    final port = c['web_port'];
    const small = TextStyle(fontSize: 12);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 14,
                  color: running ? Colors.green : Colors.red.shade300,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (working)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text('${c['image']} · ${c['status']}', style: small),
            if (running && usage != null)
              Text('CPU ${usage['cpu']}    RAM ${usage['mem']}', style: small),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () => onDetails(name),
                  child: const Text('Details'),
                ),
                if (running && port != null)
                  TextButton(
                    onPressed: () => onOpen(port as int),
                    child: const Text('Open'),
                  ),
                if (canAct && !working) ...[
                  if (running) ...[
                    TextButton(
                      onPressed: () => onAction(name, 'stop'),
                      child: const Text('Stop'),
                    ),
                    TextButton(
                      onPressed: () => onAction(name, 'restart'),
                      child: const Text('Restart'),
                    ),
                  ] else
                    TextButton(
                      onPressed: () => onAction(name, 'start'),
                      child: const Text('Start'),
                    ),
                  TextButton(
                    onPressed: () => onAction(name, 'update'),
                    child: const Text('Update'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
