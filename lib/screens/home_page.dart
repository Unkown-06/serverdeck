import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api.dart';
import '../utils/format.dart';
import 'docker_tab.dart';
import 'server_tab.dart';

/// The main screen after login. It owns the data and the refresh timer,
/// and hands the data to the two tabs. The tabs only draw things.
class HomePage extends StatefulWidget {
  final Api api;
  final void Function(String? message) onLogout;
  const HomePage({super.key, required this.api, required this.onLogout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Map<String, dynamic>? stats;
  List<dynamic>? containers;
  String? statsError;
  String? containersError;
  Timer? _timer;
  bool _busy = false;
  final Set<String> _working = {};

  // How often the data refreshes. Change the number of seconds here.
  static const _refreshEvery = Duration(seconds: 5);

  Api get api => widget.api;
  bool get canAct => api.role == 'administrator' || api.role == 'operator';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Pause refreshing while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_refreshEvery, (_) => _refresh());
  }

  /// Returns true if the session expired (and logs out).
  bool _sessionExpired(Object e) {
    if (e is ApiException && e.unauthorized) {
      _timer?.cancel();
      if (mounted) widget.onLogout('Session ended. Please log in again.');
      return true;
    }
    return false;
  }

  Future<void> _refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      try {
        final s = await api.get('/stats');
        if (mounted) {
          setState(() {
            stats = Map<String, dynamic>.from(s as Map);
            statsError = null;
          });
        }
      } catch (e) {
        if (_sessionExpired(e)) return;
        if (mounted) setState(() => statsError = errorText(e));
      }
      try {
        final c = await api.get('/containers');
        if (mounted) {
          setState(() {
            containers = List<dynamic>.from(c as List);
            containersError = null;
          });
        }
      } catch (e) {
        if (_sessionExpired(e)) return;
        if (mounted) setState(() => containersError = errorText(e));
      }
    } finally {
      _busy = false;
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ------------------------------------------------------------ actions
  /// start / stop / restart / update a container
  Future<void> _act(String name, String action) async {
    if (action == 'stop' || action == 'update') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${cap(action)} $name?'),
          content: Text(action == 'update'
              ? 'This downloads the newest image and restarts the container. It can take a few minutes.'
              : 'The container will be stopped.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(cap(action)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() => _working.add(name));
    try {
      await api.post('/containers/${Uri.encodeComponent(name)}/$action');
      _snack('$name: $action done');
    } catch (e) {
      if (_sessionExpired(e)) return;
      _snack(errorText(e));
    } finally {
      if (mounted) setState(() => _working.remove(name));
    }
    _refresh();
  }

  /// The pop-up with image, mounts and so on.
  Future<void> _details(String name) async {
    try {
      final d = await api.get('/containers/${Uri.encodeComponent(name)}');
      final mounts = (d['mounts'] as List).join('\n');
      final text = 'Image: ${d['image']}\n'
          'Created: ${d['created']}\n'
          'Started: ${d['started']}\n'
          'Restart policy: ${d['restart_policy']}\n\n'
          'Mounts:\n${mounts.isEmpty ? 'none' : mounts}';
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(name),
          content: SingleChildScrollView(child: SelectableText(text)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (_sessionExpired(e)) return;
      _snack(errorText(e));
    }
  }

  /// Opens the container's web page in the phone's browser.
  Future<void> _open(int port) async {
    final host = api.openHost;
    if (host.isEmpty) {
      _snack('No address to open');
      return;
    }
    try {
      final ok = await launchUrl(
        Uri.parse('http://$host:$port'),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) _snack('Could not open http://$host:$port');
    } catch (_) {
      _snack('Could not open http://$host:$port');
    }
  }

  // ------------------------------------------------------------ screen
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('ServerDeck · ${api.role}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: () => widget.onLogout(null),
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Server'), Tab(text: 'Docker')],
          ),
        ),
        body: TabBarView(
          children: [
            ServerTab(stats: stats, error: statsError, onRefresh: _refresh),
            DockerTab(
              containers: containers,
              error: containersError,
              working: _working,
              canAct: canAct,
              onRefresh: _refresh,
              onDetails: _details,
              onOpen: _open,
              onAction: _act,
            ),
          ],
        ),
      ),
    );
  }
}
