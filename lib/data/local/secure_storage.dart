import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage service that uses SharedPreferences on Web
/// and FlutterSecureStorage on native platforms.
class SecureStorageService {
  static const _keyAuthToken = 'auth_token';
  static const _keyBaseUrl = 'base_url';
  static const _keySubscribeUrl = 'subscribe_url';

  // Native secure storage
  final FlutterSecureStorage? _secureStorage =
      kIsWeb ? null : const FlutterSecureStorage();

  Future<void> _webWrite(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> _webRead(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> _webDelete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> _webClear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthToken);
    await prefs.remove(_keyBaseUrl);
    await prefs.remove(_keySubscribeUrl);
  }

  Future<void> saveAuthToken(String token) async {
    if (kIsWeb) {
      await _webWrite(_keyAuthToken, token);
    } else {
      await _secureStorage!.write(key: _keyAuthToken, value: token);
    }
  }

  Future<String?> getAuthToken() async {
    if (kIsWeb) {
      return _webRead(_keyAuthToken);
    }
    return _secureStorage!.read(key: _keyAuthToken);
  }

  Future<void> saveBaseUrl(String url) async {
    if (kIsWeb) {
      await _webWrite(_keyBaseUrl, url);
    } else {
      await _secureStorage!.write(key: _keyBaseUrl, value: url);
    }
  }

  Future<String?> getBaseUrl() async {
    if (kIsWeb) {
      return _webRead(_keyBaseUrl);
    }
    return _secureStorage!.read(key: _keyBaseUrl);
  }

  Future<void> saveSubscribeUrl(String url) async {
    if (kIsWeb) {
      await _webWrite(_keySubscribeUrl, url);
    } else {
      await _secureStorage!.write(key: _keySubscribeUrl, value: url);
    }
  }

  Future<String?> getSubscribeUrl() async {
    if (kIsWeb) {
      return _webRead(_keySubscribeUrl);
    }
    return _secureStorage!.read(key: _keySubscribeUrl);
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      await _webClear();
    } else {
      await _secureStorage!.deleteAll();
    }
  }

  Future<bool> hasAuthToken() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }
}
