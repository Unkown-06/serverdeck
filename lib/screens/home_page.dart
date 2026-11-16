import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api.dart';
import '../services/session_store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/dialogs.dart';
import 'alerts_page.dart';
import 'dashboard_tab.dart';
import 'docker_tab.dart';
import 'files_tab.dart';
import 'system_tab.dart';
import 'terminal_page.dart';

class _TabDef {
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? permission; // null = everyone
  const _TabDef(this.id, this.label, this.icon, this.selectedIcon, [this.permission]);
}

/// The bottom tabs. A tab with a permission only shows for roles that have it.
const _allTabs = <_TabDef>[
  _TabDef('dashboard', 'Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
  _TabDef('docker', 'Docker', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
  _TabDef('files', 'Files', Icons.folder_outlined, Icons.folder_rounded, 'files'),
  _TabDef('system', 'System', Icons.tune_outlined, Icons.tune_rounded),
];

/// The main screen after login. It owns the data and the refresh timer,
/// and hands the data to the tabs. The tabs mostly just draw things.
class HomePage extends StatefulWidget {
  final Api api;
  final SessionStore store;
  final void Function(String? message) onLogout;
  const HomePage({super.key, required this.api, required this.store, required this.onLogout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String _tab = 'dashboard';
  final Set<String> _visited = {'dashboard'};

  Map<String, dynamic>? stats;
  Map<String, dynamic>? info;
  List<dynamic>? containers;
  String? statsError;
  String? containersError;
  final List<double> cpuHistory = [];
  final List<double> downHistory = [];

  final ValueNotifier<List<Map<String, dynamic>>> alerts = ValueNotifier([]);
  int _lastAlertId = 0;
  int _readId = 0;
  bool _alertsLoaded = false;

  final Set<String> _working = {};
  final GlobalKey<FilesTabState> _filesKey = GlobalKey<FilesTabState>();

  Timer? _timer;
  bool _busy = false;
  int _ticks = 0;

  // How often the data refreshes. Change the number of seconds here.
  static const _refreshEvery = Duration(seconds: 5);
  static const _historyLength = 60;

  Api get api => widget.api;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh(force: true);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    alerts.dispose();
    super.dispose();
  }

  // Pause refreshing while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(force: true);
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_refreshEvery, (_) => _refresh());
  }

  /// Returns true if the login expired (and goes back to the login screen).
  bool _expired(Object e) {
    if (e is ApiException && e.unauthorized) {
      _timer?.cancel();
      if (mounted) widget.onLogout('Your login ended. Please log in again.');
      return true;
    }
    return false;
  }

  void _addHistory(List<double> list, num value) {
    list.add(value.toDouble());
    if (list.length > _historyLength) list.removeAt(0);
  }

  Future<void> _refresh({bool force = false}) async {
    if (_busy) return;
    _busy = true;
    _ticks++;
    try {
      try {
        final s = Map<String, dynamic>.from((await api.get('/stats')) as Map);
        _addHistory(cpuHistory, s['cpu_percent'] as num);
        _addHistory(downHistory, s['net_down_bps'] as num);
        if (mounted) {
          setState(() {
            stats = s;
            statsError = null;
          });
        }
      } catch (e) {
        if (_expired(e)) return;
        if (mounted) setState(() => statsError = errorText(e));
      }

      if (force || containers == null || _tab == 'docker' || _ticks % 2 == 0) {
        try {
          final c = List<dynamic>.from((await api.get('/containers')) as List);
          if (mounted) {
            setState(() {
              containers = c;
              containersError = null;
            });
          }
        } catch (e) {
          if (_expired(e)) return;
          if (mounted) setState(() => containersError = errorText(e));
        }
      }

      if (info == null || _ticks % 12 == 0) {
        try {
          final i = Map<String, dynamic>.from((await api.get('/system/info')) as Map);
          if (mounted) setState(() => info = i);
        } catch (e) {
          if (_expired(e)) return;
        }
      }

      await _pollAlerts();
    } finally {
      _busy = false;
    }
  }

  // ------------------------------------------------------------ alerts
  Future<void> _pollAlerts() async {
    try {
      final r = Map<String, dynamic>.from((await api.get('/alerts?after=$_lastAlertId')) as Map);
      final fresh = (r['alerts'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final last = (r['last_id'] as num).toInt();

      if (_alertsLoaded && last < _lastAlertId) {
        // The server's alert list was reset: start again.
        _lastAlertId = 0;
        _alertsLoaded = false;
        alerts.value = [];
        return;
      }
      if (!_alertsLoaded) {
        _alertsLoaded = true;
        final stored = await widget.store.readAlertId();
        _readId = stored ?? last;
        if (stored == null) widget.store.setReadAlertId(last);
        alerts.value = fresh;
        _lastAlertId = last;
        if (mounted) setState(() {});
        return;
      }
      if (fresh.isEmpty) return;
      final all = [...alerts.value, ...fresh];
      alerts.value = all.length > 200 ? all.sublist(all.length - 200) : all;
      _lastAlertId = last;
      _banner(fresh.last);
    } catch (_) {}
  }

  void _banner(Map<String, dynamic> alert) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(alert['title'] as String),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'View', onPressed: _openAlerts),
        ),
      );
  }

  void _markRead() {
    _readId = _lastAlertId;
    widget.store.setReadAlertId(_readId);
    if (mounted) setState(() {});
  }

  void _openAlerts() {
    _markRead();
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
          builder: (_) => AlertsPage(alerts: alerts, onRefresh: _pollAlerts),
        ))
        .then((_) => _markRead());
  }

  // ------------------------------------------------------------ actions
  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// start / stop / restart / update a container
  Future<void> _containerAction(String name, String action) async {
    if (action == 'stop' || action == 'update') {
      final ok = await confirmDialog(
        context,
        title: '${cap(action)} $name?',
        message: action == 'update'
            ? 'This downloads the newest image and restarts the container. It can take a few minutes.'
            : 'The container will be stopped.',
        confirmLabel: cap(action),
      );
      if (!ok) return;
    }
    if (!mounted) return;
    setState(() => _working.add(name));
    try {
      await api.post('/containers/${Uri.encodeComponent(name)}/$action');
      _snack('$name: $action done');
    } catch (e) {
      if (_expired(e)) return;
      _snack(errorText(e));
    } finally {
      if (mounted) setState(() => _working.remove(name));
    }
    _refresh(force: true);
  }

  /// The pop-up with image, mounts and so on.
  Future<void> _containerDetails(String name) async {
    try {
      final d = await api.get('/containers/${Uri.encodeComponent(name)}');
      final mounts = (d['mounts'] as List).join('\n');
      final text = 'Image: ${d['image']}\n'
          'Created: ${d['created']}\n'
          'Started: ${d['started']}\n'
          'Restart policy: ${d['restart_policy']}\n\n'
          'Mounts:\n${mounts.isEmpty ? 'none' : mounts}';
      if (!mounted) return;
      showDialog<void>(
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
      if (_expired(e)) return;
      _snack(errorText(e));
    }
  }

  /// Opens the container's web page in the phone's browser.
  Future<void> _openContainer(int port) async {
    final host = api.openTarget;
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

  void _openTerminal() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TerminalPage(api: api)));
  }

  // ------------------------------------------------------------ screen
  List<_TabDef> get _tabs =>
      _allTabs.where((t) => t.permission == null || api.can(t.permission!)).toList();

  Widget _tabBody(String id) {
    switch (id) {
      case 'docker':
        return DockerTab(
          containers: containers,
          error: containersError,
          working: _working,
          canControl: api.can('containers_control'),
          onRefresh: () => _refresh(force: true),
          onDetails: _containerDetails,
          onOpen: _openContainer,
          onAction: _containerAction,
        );
      case 'files':
        return FilesTab(key: _filesKey, api: api);
      case 'system':
        return SystemTab(
          api: api,
          store: widget.store,
          info: info,
          onLogout: widget.onLogout,
          onOpenTerminal: _openTerminal,
        );
      default:
        return DashboardTab(
          stats: stats,
          info: info,
          error: statsError,
          cpuHistory: cpuHistory,
          downHistory: downHistory,
          onRefresh: () => _refresh(force: true),
        );
    }
  }

  Widget _offlineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bad.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.bad),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${statsError!}  Trying again every 5 seconds.',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    if (!tabs.any((t) => t.id == _tab)) _tab = tabs.first.id;
    final index = tabs.indexWhere((t) => t.id == _tab);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_tab == 'files' && _filesKey.currentState?.goUp() == true) return;
        if (_tab != 'dashboard') {
          setState(() => _tab = 'dashboard');
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: accentGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dns_rounded, size: 18, color: AppColors.onAccent),
              ),
              const SizedBox(width: 10),
              const Text('ServerDeck', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          actions: [
            if (api.can('terminal'))
              IconButton(
                tooltip: 'Terminal',
                icon: const Icon(Icons.terminal_rounded),
                onPressed: _openTerminal,
              ),
            ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: alerts,
              builder: (context, list, _) {
                final unread = list.where((a) => (a['id'] as num) > _readId).length;
                return IconButton(
                  tooltip: 'Alerts',
                  onPressed: _openAlerts,
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_rounded),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            if (statsError != null) _offlineBanner(),
            Expanded(
              child: IndexedStack(
                index: index,
                children: [
                  for (final t in tabs)
                    _visited.contains(t.id) ? _tabBody(t.id) : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          backgroundColor: AppColors.card,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.accent.withValues(alpha: 0.2),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            setState(() {
              _tab = tabs[i].id;
              _visited.add(_tab);
            });
          },
          destinations: [
            for (final t in tabs)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon, color: AppColors.accent),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}
