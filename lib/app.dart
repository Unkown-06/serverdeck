import 'package:flutter/material.dart';

import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'services/api.dart';
import 'services/session_store.dart';
import 'theme.dart';

/// The app itself. Colors and theme live in theme.dart.
class ServerDeckApp extends StatelessWidget {
  const ServerDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServerDeck',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Root(),
    );
  }
}

enum _Phase { loading, retry, login, home }

/// Decides which screen to show: starting up, login, or the home screen.
/// If "Remember me" was on, it logs in again by itself.
class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  final Api api = Api();
  final SessionStore store = SessionStore();
  SavedSession saved = const SavedSession();
  _Phase phase = _Phase.loading;
  String? notice;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      phase = _Phase.loading;
      notice = null;
    });
    saved = await store.load();
    api.openHost = saved.homeHost;
    final token = saved.token;
    if (token == null || saved.url.isEmpty) {
      if (mounted) setState(() => phase = _Phase.login);
      return;
    }
    try {
      await api.restore(saved.url, token);
      if (mounted) setState(() => phase = _Phase.home);
    } on ApiException catch (e) {
      if (e.unauthorized) await store.clearToken();
      if (!mounted) return;
      setState(() {
        phase = _Phase.login;
        notice = e.unauthorized ? 'Your saved login ended. Please log in again.' : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        phase = _Phase.retry;
        notice = errorText(e);
      });
    }
  }

  Future<void> _logout(String? message) async {
    await api.logout();
    await store.clearToken();
    saved = await store.load();
    api.openHost = saved.homeHost;
    if (!mounted) return;
    setState(() {
      phase = _Phase.login;
      notice = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case _Phase.home:
        return HomePage(api: api, store: store, onLogout: _logout);
      case _Phase.login:
        return LoginPage(
          api: api,
          store: store,
          initialUrl: saved.url,
          initialUser: saved.username,
          notice: notice,
          onLoggedIn: () => setState(() {
            phase = _Phase.home;
            notice = null;
          }),
        );
      case _Phase.retry:
        return _RetryScreen(
          message: notice ?? 'Cannot reach the server.',
          onRetry: _start,
          onLogin: () async {
            await store.clearToken();
            saved = await store.load();
            if (mounted) setState(() => phase = _Phase.login);
          },
        );
      case _Phase.loading:
        return const _Splash();
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: accentGradient,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.dns_rounded, size: 44, color: AppColors.onAccent),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 12),
            const Text('Signing in...', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _RetryScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogin;
  const _RetryScreen({required this.message, required this.onRetry, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
              TextButton(onPressed: onLogin, child: const Text('Log in again')),
            ],
          ),
        ),
      ),
    );
  }
}
