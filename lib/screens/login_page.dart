import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/session_store.dart';
import '../theme.dart';

/// The login screen. "Remember me" keeps you logged in on this phone.
class LoginPage extends StatefulWidget {
  final Api api;
  final SessionStore store;
  final String initialUrl;
  final String initialUser;
  final String? notice;
  final VoidCallback onLoggedIn;

  const LoginPage({
    super.key,
    required this.api,
    required this.store,
    required this.onLoggedIn,
    this.initialUrl = '',
    this.initialUser = '',
    this.notice,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _url = TextEditingController(text: widget.initialUrl);
  late final TextEditingController _user = TextEditingController(text: widget.initialUser);
  final TextEditingController _pass = TextEditingController();
  bool _hidePass = true;
  bool _remember = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final url = _url.text.trim();
    final user = _user.text.trim();
    if (url.isEmpty || user.isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Fill in address, username and password');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.login(url, user, _pass.text, remember: _remember);
      await widget.store.saveLogin(
        url: widget.api.base,
        username: user,
        token: _remember ? widget.api.token : null,
      );
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A101C), Color(0xFF10263A), Color(0xFF0A101C)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: accentGradient,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: const Icon(Icons.dns_rounded, size: 44, color: AppColors.onAccent),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'ServerDeck',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage your Ubuntu server',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: fieldDecoration(
                        'Server address',
                        hint: 'https://deck.yourdomain.com',
                        icon: Icons.link_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _user,
                      autocorrect: false,
                      decoration: fieldDecoration('Username', icon: Icons.person_rounded),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      obscureText: _hidePass,
                      onSubmitted: (_) => _login(),
                      decoration: fieldDecoration(
                        'Password',
                        icon: Icons.lock_rounded,
                        suffix: IconButton(
                          icon: Icon(_hidePass
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded),
                          onPressed: () => setState(() => _hidePass = !_hidePass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: const Text('Remember me'),
                      subtitle: const Text(
                        'Stay logged in on this phone',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Log in', style: TextStyle(fontSize: 16)),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.bad),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
