import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fetches a remote JSON config file (hosted on OSS/CDN) to get the latest
/// server URL. Falls back to local cache, then to the compile-time default.
///
/// The JSON format is simply:
/// ```json
/// {
///   "server_url": "https://your-panel.com"
/// }
/// ```
///
/// You can also include optional fields like `notice`, `min_version`, etc.
class RemoteConfigService {
  static const _cacheKeyServerUrl = 'remote_server_url';
  static const _cacheKeyRaw = 'remote_config_raw';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  /// Fetch the remote config. Returns the server URL.
  /// Priority: remote → cached → [defaultUrl].
  Future<String> getServerUrl({
    required String remoteConfigUrl,
    required String defaultUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // If no remote config URL is set, use cached or default directly.
    if (remoteConfigUrl.isEmpty) {
      return prefs.getString(_cacheKeyServerUrl) ?? defaultUrl;
    }

    try {
      final resp = await _dio.get(remoteConfigUrl);
      if (resp.statusCode == 200 && resp.data is Map) {
        final data = resp.data as Map<String, dynamic>;
        final url = (data['server_url'] as String?)?.trim() ?? '';
        if (url.isNotEmpty) {
          await prefs.setString(_cacheKeyServerUrl, url);
          await prefs.setString(_cacheKeyRaw, url);
          return url;
        }
      }
    } catch (_) {
      // Network error — fall through to cache.
    }

    return prefs.getString(_cacheKeyServerUrl) ?? defaultUrl;
  }
}
