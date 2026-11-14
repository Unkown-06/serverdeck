import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const ServerDeckApp());

// ---------------------------------------------------------------- helpers
String fmtBytes(num? n) {
  double v = (n ?? 0).toDouble();
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(1)} ${units[i]}';
}

String fmtUptime(num seconds) {
  final s = seconds.toInt();
  final d = s ~/ 86400;
  final h = (s % 86400) ~/ 3600;
  final m = (s % 3600) ~/ 60;
  return '${d}d ${h}h ${m}m';
}

String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String errorText(Object e) {
  if (e is ApiException) return e.message;
  if (e is TimeoutException) return 'The server took too long to answer';
  return 'Cannot reach the server. Check the address and your internet.';
}

// ---------------------------------------------------------------- API
class ApiException implements Exception {
  final String message;
  final bool unauthorized;
  ApiException(this.message, {this.unauthorized = false});
  @override
  String toString() => message;
}

class Api {
  String base = '';
  String token = '';
  String role = '';
  String username = '';
  String openHost = ''; // host used by the "Open" buttons

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  dynamic _decode(http.Response r) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      body = null;
    }
    if (r.statusCode == 200) return body;
    final detail = (body is Map && body['detail'] != null)
        ? body['detail'].toString()
        : 'Error ${r.statusCode}';
    throw ApiException(detail, unauthorized: r.statusCode == 401);
  }

  Future<void> login(String url, String user, String pass) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$cleaned/login');
    final r = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': user, 'password': pass}),
        )
        .timeout(const Duration(seconds: 15));
    final data = _decode(r);
    base = cleaned;
    token = data['token'] as String;
    role = data['role'] as String;
    username = data['username'] as String;
  }

  Future<dynamic> get(String path) async {
    final r = await http
        .get(Uri.parse('$base$path'), headers: _headers)
        .timeout(const Duration(seconds: 40));
    return _decode(r);
  }

  Future<dynamic> post(String path) async {
    final r = await http
        .post(Uri.parse('$base$path'), headers: _headers)
        .timeout(const Duration(seconds: 700));
    return _decode(r);
  }
}

// ---------------------------------------------------------------- app root
class ServerDeckApp extends StatelessWidget {
  const ServerDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServerDeck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const Root(),
    );
  }
}

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  final Api api = Api();
  bool loggedIn = false;
  String? notice;

  void _logout(String? message) {
    api.token = '';
    setState(() {
      loggedIn = false;
      notice = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loggedIn) {
      return HomePage(api: api, onLogout: _logout);
    }
    return LoginPage(
      api: api,
      notice: notice,
      onLoggedIn: () => setState(() {
        loggedIn = true;
        notice = null;
      }),
    );
  }
}

// ---------------------------------------------------------------- login
class LoginPage extends StatefulWidget {
  final Api api;
  final String? notice;
  final VoidCallback onLoggedIn;
  const LoginPage({
    super.key,
    required this.api,
    required this.onLoggedIn,
    this.notice,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _home = TextEditingController();
  bool _hidePass = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _home.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      _url.text = p.getString('server_url') ?? '';
      _user.text = p.getString('username') ?? '';
      _home.text = p.getString('home_host') ?? '';
    } catch (_) {}
  }

  Future<void> _login() async {
    if (_url.text.trim().isEmpty || _user.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Fill in address, username and password');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.login(_url.text, _user.text.trim(), _pass.text);
      final host = _home.text.trim().isNotEmpty
          ? _home.text.trim()
          : (Uri.tryParse(widget.api.base)?.host ?? '');
      widget.api.openHost = host;
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('server_url', _url.text.trim());
        await p.setString('username', _user.text.trim());
        await p.setString('home_host', _home.text.trim());
      } catch (_) {}
      if (!mounted) return;
      widget.onLoggedIn();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is FormatException
            ? 'That server address does not look right'
            : errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _error ?? widget.notice;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.dns_rounded, size: 56),
                  const SizedBox(height: 8),
                  Text(
                    'ServerDeck',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text('Manage your Ubuntu server', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Server address',
                      hintText: 'https://deck.yourdomain.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _user,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: _hidePass,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_hidePass ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hidePass = !_hidePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _home,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Home address for Open buttons (optional)',
                      hintText: '192.168.1.20',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Log in'),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade300),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- home
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
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
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

  // ------------------------------------------------------------ widgets
  Widget _bar(String label, num percent, String detail) {
    final p = percent.toDouble();
    final color = p >= 90
        ? Colors.red.shade300
        : p >= 75
            ? Colors.amber
            : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label: ${p.toStringAsFixed(0)}%   ($detail)'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (p / 100).clamp(0.0, 1.0),
              color: color,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(alignment: Alignment.centerLeft, child: Text(text)),
      ),
    );
  }

  Widget _errorBanner(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(error, style: TextStyle(color: Colors.red.shade300)),
    );
  }

  Widget _serverTab() {
    final s = stats;
    if (s == null) {
      return Center(
        child: statsError != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(statsError!, textAlign: TextAlign.center),
              )
            : const CircularProgressIndicator(),
      );
    }
    final temp = s['cpu_temp'] == null ? 'not available' : '${s['cpu_temp']} °C';
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _errorBanner(statsError),
          _bar('CPU', s['cpu_percent'] as num, 'temp $temp'),
          _bar('RAM', s['ram_percent'] as num,
              '${fmtBytes(s['ram_used'] as num)} / ${fmtBytes(s['ram_total'] as num)}'),
          _bar('Swap', s['swap_percent'] as num,
              '${fmtBytes(s['swap_used'] as num)} / ${fmtBytes(s['swap_total'] as num)}'),
          _bar('Disk', s['disk_percent'] as num,
              '${fmtBytes(s['disk_used'] as num)} / ${fmtBytes(s['disk_total'] as num)}'),
          _info('Disk read ${fmtBytes(s['disk_read_bps'] as num)}/s    '
              'write ${fmtBytes(s['disk_write_bps'] as num)}/s'),
          _info('Network down ${fmtBytes(s['net_down_bps'] as num)}/s    '
              'up ${fmtBytes(s['net_up_bps'] as num)}/s'),
          _info('Data since boot: down ${fmtBytes(s['net_total_down'] as num)}, '
              'up ${fmtBytes(s['net_total_up'] as num)}'),
          _info('Uptime: ${fmtUptime(s['uptime_seconds'] as num)}'),
        ],
      ),
    );
  }

  Widget _containerCard(Map<String, dynamic> c) {
    final name = c['name'] as String;
    final running = c['state'] == 'running';
    final usage = c['usage'];
    final working = _working.contains(name);
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
                Icon(Icons.circle,
                    size: 14, color: running ? Colors.green : Colors.red.shade300),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                TextButton(onPressed: () => _details(name), child: const Text('Details')),
                if (running && port != null)
                  TextButton(
                    onPressed: () => _open(port as int),
                    child: const Text('Open'),
                  ),
                if (canAct && !working) ...[
                  if (running) ...[
                    TextButton(
                      onPressed: () => _act(name, 'stop'),
                      child: const Text('Stop'),
                    ),
                    TextButton(
                      onPressed: () => _act(name, 'restart'),
                      child: const Text('Restart'),
                    ),
                  ] else
                    TextButton(
                      onPressed: () => _act(name, 'start'),
                      child: const Text('Start'),
                    ),
                  TextButton(
                    onPressed: () => _act(name, 'update'),
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

  Widget _dockerTab() {
    final list = containers;
    if (list == null) {
      return Center(
        child: containersError != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(containersError!, textAlign: TextAlign.center),
              )
            : const CircularProgressIndicator(),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _errorBanner(containersError),
          if (list.isEmpty) const Text('No containers found'),
          for (final c in list) _containerCard(Map<String, dynamic>.from(c as Map)),
        ],
      ),
    );
  }

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
        body: TabBarView(children: [_serverTab(), _dockerTab()]),
      ),
    );
  }
}
