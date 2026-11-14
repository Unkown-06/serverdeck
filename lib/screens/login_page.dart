import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';

/// The login screen. The address, username and "home address" are remembered
/// on the phone; the password never is.
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
