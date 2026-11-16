import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the app remembers between launches.
class SavedSession {
  final String url;
  final String username;
  final String? token; // only set when "Remember me" was on
  final String homeHost;
  const SavedSession({
    this.url = '',
    this.username = '',
    this.token,
    this.homeHost = '',
  });
}

/// The login token goes into Android's encrypted storage.
/// Everything else (address, username...) goes into normal preferences.
/// The password is never saved.
class SessionStore {
  final FlutterSecureStorage _secure = FlutterSecureStorage();

  Future<SavedSession> load() async {
    String url = '', username = '', homeHost = '';
    String? token;
    try {
      final p = await SharedPreferences.getInstance();
      url = p.getString('server_url') ?? '';
      username = p.getString('username') ?? '';
      homeHost = p.getString('home_host') ?? '';
    } catch (_) {}
    try {
      token = await _secure.read(key: 'token');
      if (token != null && token.isEmpty) token = null;
    } catch (_) {}
    return SavedSession(url: url, username: username, token: token, homeHost: homeHost);
  }

  Future<void> saveLogin({
    required String url,
    required String username,
    String? token,
  }) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('server_url', url);
      await p.setString('username', username);
    } catch (_) {}
    try {
      if (token == null) {
        await _secure.delete(key: 'token');
      } else {
        await _secure.write(key: 'token', value: token);
      }
    } catch (_) {}
  }

  Future<void> clearToken() async {
    try {
      await _secure.delete(key: 'token');
    } catch (_) {}
  }

  Future<void> setHomeHost(String value) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('home_host', value);
    } catch (_) {}
  }

  /// The newest alert the user has seen. Null if the app never stored one.
  Future<int?> readAlertId() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getInt('alerts_read_id');
    } catch (_) {
      return null;
    }
  }

  Future<void> setReadAlertId(int id) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('alerts_read_id', id);
    } catch (_) {}
  }
}
