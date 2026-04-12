import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:xboard_client/core/constants/app_constants.dart';

/// HTTP client for mihomo's Clash-compatible RESTful API (external-controller).
class ClashApiClient {
  late final Dio _dio;
  Timer? _trafficTimer;

  ClashApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl:
          'http://${AppConstants.clashApiHost}:${AppConstants.clashApiPort}',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
  }

  Future<bool> isRunning() async {
    try {
      final resp = await _dio.get('/version');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, int>> getTraffic() async {
    // Fallback: use /connections to compute approximate speed.
    try {
      final resp = await _dio.get('/connections');
      final data = resp.data as Map<String, dynamic>? ?? {};
      return {
        'up': (data['uploadTotal'] as num?)?.toInt() ?? 0,
        'down': (data['downloadTotal'] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return {'up': 0, 'down': 0};
    }
  }

  Future<Map<String, dynamic>> getProxies() async {
    try {
      final resp = await _dio.get('/proxies');
      return resp.data as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<bool> selectProxy(String group, String proxyName) async {
    try {
      final resp = await _dio.put(
        '/proxies/$group',
        data: {'name': proxyName},
      );
      debugPrint('[ClashAPI] selectProxy($group, $proxyName) -> ${resp.statusCode}');
      return resp.statusCode == 204 || resp.statusCode == 200;
    } catch (e) {
      debugPrint('[ClashAPI] selectProxy($group, $proxyName) FAILED: $e');
      return false;
    }
  }

  /// Return the last error message from selectProxy for UI display.
  String? _lastSelectError;
  String? get lastSelectError => _lastSelectError;

  Future<({bool ok, String? error})> selectProxyWithError(String group, String proxyName) async {
    try {
      final resp = await _dio.put(
        '/proxies/$group',
        data: {'name': proxyName},
      );
      _lastSelectError = null;
      return (ok: resp.statusCode == 204 || resp.statusCode == 200, error: null);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] as String? ?? e.message)
          : (e.message ?? e.toString());
      _lastSelectError = msg;
      debugPrint('[ClashAPI] selectProxy($group, $proxyName) FAILED: $msg');
      return (ok: false, error: msg);
    } catch (e) {
      _lastSelectError = e.toString();
      debugPrint('[ClashAPI] selectProxy($group, $proxyName) FAILED: $e');
      return (ok: false, error: e.toString());
    }
  }

  Future<int> getProxyDelay(
    String proxyName, {
    String testUrl = 'https://cp.cloudflare.com/generate_204',
    int timeout = 5000,
  }) async {
    try {
      final resp = await _dio.get(
        '/proxies/$proxyName/delay',
        queryParameters: {'url': testUrl, 'timeout': timeout},
        // The Clash API waits up to `timeout` ms for the proxy to respond,
        // so Dio's own receive timeout must be longer to avoid a premature
        // client-side timeout that masks a successful but slow test.
        options: Options(
          receiveTimeout: Duration(milliseconds: timeout + 3000),
        ),
      );
      return (resp.data['delay'] as num?)?.toInt() ?? -1;
    } catch (e) {
      debugPrint('[ClashAPI] getProxyDelay($proxyName) FAILED: $e');
      return -1;
    }
  }

  Future<Map<String, dynamic>> getConnections() async {
    try {
      final resp = await _dio.get('/connections');
      return resp.data as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<void> closeAllConnections() async {
    try {
      await _dio.delete('/connections');
    } catch (_) {}
  }

  Future<String> getVersion() async {
    try {
      final resp = await _dio.get('/version');
      return resp.data['version'] as String? ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Subscribe to mihomo's streaming /traffic endpoint for real-time speed.
  StreamSubscription<List<int>>? _trafficStreamSub;

  Stream<Map<String, int>> watchTraffic({
    Duration interval = const Duration(seconds: 1),
  }) {
    final controller = StreamController<Map<String, int>>();

    // Try the streaming /traffic endpoint first.
    _connectTrafficStream(controller);

    controller.onCancel = () {
      _trafficStreamSub?.cancel();
      _trafficStreamSub = null;
      _trafficTimer?.cancel();
    };
    return controller.stream;
  }

  void _connectTrafficStream(StreamController<Map<String, int>> controller) {
    final streamDio = Dio(BaseOptions(
      baseUrl: 'http://${AppConstants.clashApiHost}:${AppConstants.clashApiPort}',
    ));

    streamDio.get<ResponseBody>(
      '/traffic',
      options: Options(responseType: ResponseType.stream),
    ).then((resp) {
      final stream = resp.data!.stream;
      String buffer = '';
      _trafficStreamSub = stream.listen(
        (chunk) {
          buffer += utf8.decode(chunk);
          // /traffic sends newline-delimited JSON: {"up":123,"down":456}\n
          while (buffer.contains('\n')) {
            final idx = buffer.indexOf('\n');
            final line = buffer.substring(0, idx).trim();
            buffer = buffer.substring(idx + 1);
            if (line.isEmpty) continue;
            try {
              final json = jsonDecode(line) as Map<String, dynamic>;
              if (!controller.isClosed) {
                controller.add({
                  'up': (json['up'] as num?)?.toInt() ?? 0,
                  'down': (json['down'] as num?)?.toInt() ?? 0,
                });
              }
            } catch (_) {}
          }
        },
        onError: (_) {
          // Stream broke — fall back to polling.
          _fallbackToPolling(controller);
        },
        onDone: () {
          if (!controller.isClosed) _fallbackToPolling(controller);
        },
        cancelOnError: true,
      );
    }).catchError((_) {
      // Streaming not available — fall back to polling.
      _fallbackToPolling(controller);
    });
  }

  void _fallbackToPolling(StreamController<Map<String, int>> controller) {
    int lastUp = 0, lastDown = 0;
    _trafficTimer?.cancel();
    _trafficTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (controller.isClosed) { _trafficTimer?.cancel(); return; }
      final totals = await getTraffic();
      final up = totals['up'] ?? 0;
      final down = totals['down'] ?? 0;
      // Convert totals to per-second speed.
      if (lastUp > 0 || lastDown > 0) {
        final speedUp = (up - lastUp).clamp(0, 1 << 30);
        final speedDown = (down - lastDown).clamp(0, 1 << 30);
        if (!controller.isClosed) controller.add({'up': speedUp, 'down': speedDown});
      }
      lastUp = up;
      lastDown = down;
    });
  }

  void dispose() {
    _trafficTimer?.cancel();
    _dio.close();
  }
}
