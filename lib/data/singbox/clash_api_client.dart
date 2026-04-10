import 'dart:async';
import 'package:dio/dio.dart';
import 'package:xboard_client/core/constants/app_constants.dart';

/// HTTP client to communicate with sing-box's Clash-compatible API
class ClashApiClient {
  late final Dio _dio;
  Timer? _trafficTimer;

  ClashApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl:
          'http://${AppConstants.clashApiHost}:${AppConstants.clashApiPort}',
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ));
  }

  /// Check if sing-box Clash API is responsive
  Future<bool> isRunning() async {
    try {
      final resp = await _dio.get('/version');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get current traffic snapshot (upload/download bytes)
  Future<Map<String, int>> getTraffic() async {
    try {
      final resp = await _dio.get('/traffic');
      // Clash API returns a stream, but single GET gives one JSON line
      if (resp.data is Map) {
        return {
          'up': (resp.data['up'] as num?)?.toInt() ?? 0,
          'down': (resp.data['down'] as num?)?.toInt() ?? 0,
        };
      }
      return {'up': 0, 'down': 0};
    } catch (_) {
      return {'up': 0, 'down': 0};
    }
  }

  /// Get all proxies/groups
  Future<Map<String, dynamic>> getProxies() async {
    try {
      final resp = await _dio.get('/proxies');
      return resp.data as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Select a proxy in a group
  Future<bool> selectProxy(String group, String proxyName) async {
    try {
      final resp = await _dio.put('/proxies/$group', data: {
        'name': proxyName,
      });
      return resp.statusCode == 204 || resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get proxy delay (latency test)
  Future<int> getProxyDelay(String proxyName,
      {String testUrl = 'https://www.gstatic.com/generate_204',
      int timeout = 3000}) async {
    try {
      final resp = await _dio.get('/proxies/$proxyName/delay', queryParameters: {
        'url': testUrl,
        'timeout': timeout,
      });
      return (resp.data['delay'] as num?)?.toInt() ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// Get active connections
  Future<Map<String, dynamic>> getConnections() async {
    try {
      final resp = await _dio.get('/connections');
      return resp.data as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Close all connections
  Future<void> closeAllConnections() async {
    try {
      await _dio.delete('/connections');
    } catch (_) {}
  }

  /// Get sing-box version info
  Future<String> getVersion() async {
    try {
      final resp = await _dio.get('/version');
      return resp.data['version'] as String? ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Start periodic traffic polling
  /// Returns a stream of {up, down} bytes per second
  Stream<Map<String, int>> watchTraffic({
    Duration interval = const Duration(seconds: 1),
  }) {
    final controller = StreamController<Map<String, int>>();

    _trafficTimer?.cancel();
    _trafficTimer = Timer.periodic(interval, (_) async {
      if (controller.isClosed) {
        _trafficTimer?.cancel();
        return;
      }
      final traffic = await getTraffic();
      if (!controller.isClosed) {
        controller.add(traffic);
      }
    });

    controller.onCancel = () {
      _trafficTimer?.cancel();
    };

    return controller.stream;
  }

  void dispose() {
    _trafficTimer?.cancel();
    _dio.close();
  }
}
