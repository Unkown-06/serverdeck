import 'package:flutter/material.dart';

import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'services/api.dart';

/// The app itself: colors and theme live here.
class ServerDeckApp extends StatelessWidget {
  const ServerDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServerDeck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal, // change this color to restyle the app
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const Root(),
    );
  }
}

/// Decides which screen to show: login or home.
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
