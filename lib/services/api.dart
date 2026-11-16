import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Everything that talks to the ServerDeck server lives in this file.
/// To add a new server feature, call api.get('/something') or
/// api.post('/something', {...}) from a screen.

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, {this.statusCode = 0});
  bool get unauthorized => statusCode == 401;
  @override
  String toString() => message;
}

/// Turns any error into a short message the user can read.
String errorText(Object e) {
  if (e is ApiException) return e.message;
  if (e is TimeoutException) return 'The server took too long to answer';
  return 'Cannot reach the server. Check the address and your internet.';
}

class Api {
  String base = '';
  String token = '';
  String role = '';
  String username = '';
  List<String> permissions = const [];

  /// Address used by the "Open" buttons on Docker apps. Empty = use the server address.
  String openHost = '';

  bool can(String permission) => permissions.contains(permission);

  String get openTarget =>
      openHost.isNotEmpty ? openHost : (Uri.tryParse(base)?.host ?? '');

  Map<String, String> get authHeaders => {'Authorization': 'Bearer $token'};

  Map<String, String> get _jsonHeaders => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// "myserver.com" -> "https://myserver.com", "192.168.1.5:8700" -> "http://192.168.1.5:8700"
  static String cleanUrl(String url) {
    var u = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (u.isNotEmpty && !u.contains('://')) {
      final local = RegExp(r'^(\d{1,3}\.){3}\d{1,3}(:\d+)?(/|$)').hasMatch(u) ||
          u.startsWith('localhost');
      u = '${local ? 'http' : 'https'}://$u';
    }
    return u;
  }

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
    throw ApiException(detail, statusCode: r.statusCode);
  }

  void _applyUser(Map data) {
    role = data['role'] as String;
    username = data['username'] as String;
    permissions = List<String>.from(data['permissions'] as List);
  }

  /// Log in with a username and password. Returns when the token is stored in [token].
  Future<void> login(String url, String user, String pass, {bool remember = true}) async {
    final cleaned = cleanUrl(url);
    final r = await http
        .post(
          Uri.parse('$cleaned/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': user, 'password': pass, 'remember': remember}),
        )
        .timeout(const Duration(seconds: 15));
    final data = _decode(r) as Map;
    base = cleaned;
    token = data['token'] as String;
    _applyUser(data);
  }

  /// Use a saved token ("remember me"). Throws ApiException(401) if it expired.
  Future<void> restore(String url, String savedToken) async {
    final cleaned = cleanUrl(url);
    final r = await http
        .get(Uri.parse('$cleaned/me'), headers: {'Authorization': 'Bearer $savedToken'})
        .timeout(const Duration(seconds: 15));
    final data = _decode(r) as Map;
    base = cleaned;
    token = savedToken;
    _applyUser(data);
  }

  Future<dynamic> get(String path) async {
    final r = await http
        .get(Uri.parse('$base$path'), headers: _jsonHeaders)
        .timeout(const Duration(seconds: 40));
    return _decode(r);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final r = await http
        .post(Uri.parse('$base$path'), headers: _jsonHeaders, body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 700));
    return _decode(r);
  }

  /// Tell the server to forget this login. Never throws.
  Future<void> logout() async {
    try {
      await http
          .post(Uri.parse('$base/logout'), headers: _jsonHeaders)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    token = '';
    permissions = const [];
  }

  /// "https://x.com" + "/terminal" -> wss://x.com/terminal
  Uri wsUri(String path) =>
      Uri.parse(base.replaceFirst(RegExp(r'^http'), 'ws') + path);

  Uri url(String path) => Uri.parse('$base$path');
}
