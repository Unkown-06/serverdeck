import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

/// Shows the progress of "Update server" (the Ubuntu package update).
/// You can leave this screen; the update keeps running on the server.
class UpdatePage extends StatefulWidget {
  final Api api;
  const UpdatePage({super.key, required this.api});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  Map<String, dynamic>? _status;
  String? _error;
  Timer? _timer;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final r = Map<String, dynamic>.from((await widget.api.get('/system/update/status')) as Map);
      if (!mounted) return;
      setState(() {
        _status = r;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
      if (r['running'] != true) _timer?.cancel();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final running = s?['running'] == true;
    final ok = s?['ok'];
    final lines = ((s?['lines'] as List?) ?? const []).join('\n');

    Widget pill;
    if (s == null) {
      pill = const StatusPill('Loading', AppColors.muted);
    } else if (running) {
      pill = const StatusPill('Updating...', AppColors.warn, icon: Icons.sync_rounded);
    } else if (ok == true) {
      pill = const StatusPill('Finished', AppColors.good, icon: Icons.check_circle_rounded);
    } else if (ok == false) {
      pill = const StatusPill('Failed', AppColors.bad, icon: Icons.error_rounded);
    } else {
      pill = const StatusPill('No update has run yet', AppColors.muted);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Server update'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [pill]),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.bad)),
            ],
            if (running) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 4),
              const SizedBox(height: 6),
              const Text(
                'You can leave this screen. The update keeps running on the server.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
            if (!running && s?['reboot_required'] == true) ...[
              const SizedBox(height: 12),
              const GlassCard(
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, color: AppColors.warn),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Some updates need a restart. Restart the server from the System tab.'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: SelectableText(
                    lines.isEmpty ? 'Waiting for output...' : lines,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.35),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
