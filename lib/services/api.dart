import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Everything that talks to the ServerDeck server lives in this file.
/// To add a new server feature, add a new endpoint here (or just call
/// api.get('/something') / api.post('/something') from a screen).

class ApiException implements Exception {
  final String message;
  final bool unauthorized;
  ApiException(this.message, {this.unauthorized = false});
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
