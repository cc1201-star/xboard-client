import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:xboard_client/data/singbox/clash_api_client.dart';
import 'package:xboard_client/data/singbox/singbox_config_builder.dart';
import 'package:xboard_client/data/singbox/singbox_platform_channel.dart';
import 'package:xboard_client/data/singbox/singbox_process_manager.dart';

enum SingboxStatus { stopped, starting, running, stopping, error }

class SingboxState {
  final SingboxStatus status;
  final String? errorMessage;
  final int uploadSpeed;
  final int downloadSpeed;
  final int uploadTotal;
  final int downloadTotal;
  final String? selectedNode;
  final List<SingboxProxy> proxies;
  final List<SingboxProxyGroup> proxyGroups;
  final List<String> logs;

  const SingboxState({
    this.status = SingboxStatus.stopped,
    this.errorMessage,
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.uploadTotal = 0,
    this.downloadTotal = 0,
    this.selectedNode,
    this.proxies = const [],
    this.proxyGroups = const [],
    this.logs = const [],
  });

  bool get isRunning => status == SingboxStatus.running;
  bool get isStopped => status == SingboxStatus.stopped;

  SingboxState copyWith({
    SingboxStatus? status,
    String? errorMessage,
    int? uploadSpeed,
    int? downloadSpeed,
    int? uploadTotal,
    int? downloadTotal,
    String? selectedNode,
    List<SingboxProxy>? proxies,
    List<SingboxProxyGroup>? proxyGroups,
    List<String>? logs,
  }) {
    return SingboxState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadTotal: uploadTotal ?? this.uploadTotal,
      downloadTotal: downloadTotal ?? this.downloadTotal,
      selectedNode: selectedNode ?? this.selectedNode,
      proxies: proxies ?? this.proxies,
      proxyGroups: proxyGroups ?? this.proxyGroups,
      logs: logs ?? this.logs,
    );
  }
}

class SingboxProxy {
  final String name;
  final String type;
  final int delay;

  const SingboxProxy({
    required this.name,
    required this.type,
    this.delay = -1,
  });
}

class SingboxProxyGroup {
  final String name;
  final String type;
  final String? now;
  final List<String> all;

  const SingboxProxyGroup({
    required this.name,
    required this.type,
    this.now,
    this.all = const [],
  });
}

/// Core service managing sing-box lifecycle and state.
/// Automatically selects the right backend:
/// - Desktop (Windows/macOS/Linux): runs sing-box as a subprocess
/// - Mobile (Android/iOS): uses Platform Channel to native VpnService/NetworkExtension
/// - Web: not supported
class SingboxService {
  final ClashApiClient _clashApi = ClashApiClient();

  // Desktop: process manager
  SingboxProcessManager? _processManager;

  // Mobile: platform channel
  SingboxPlatformChannel? _platformChannel;

  final _stateController = StreamController<SingboxState>.broadcast();
  StreamSubscription<Map<String, int>>? _trafficSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<String>? _logSub;
  Timer? _proxyPollTimer;

  SingboxState _state = const SingboxState();

  Stream<SingboxState> get stateStream => _stateController.stream;
  SingboxState get currentState => _state;

  final bool _isDesktop;
  final bool _isWeb;

  SingboxService()
      : _isDesktop = !kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux),
        _isWeb = kIsWeb {
    if (_isWeb) return;

    if (_isDesktop) {
      _processManager = SingboxProcessManager();
      _statusSub = _processManager!.statusStream.listen(_onNativeStatus);
      _logSub = _processManager!.logStream.listen(_onLog);
    } else {
      _platformChannel = SingboxPlatformChannel();
      _statusSub = _platformChannel!.statusStream.listen(_onNativeStatus);
    }
  }

  void _emit(SingboxState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void _onLog(String line) {
    final logs = [..._state.logs, line];
    // Keep last 500 lines
    if (logs.length > 500) logs.removeRange(0, logs.length - 500);
    _emit(_state.copyWith(logs: logs));
  }

  void _onNativeStatus(String status) {
    switch (status) {
      case 'started':
        _emit(_state.copyWith(status: SingboxStatus.running));
        _startMonitoring();
        break;
      case 'stopped':
        _emit(_state.copyWith(status: SingboxStatus.stopped));
        _stopMonitoring();
        break;
      case 'error':
        _emit(_state.copyWith(
          status: SingboxStatus.error,
          errorMessage: 'sing-box error',
        ));
        _stopMonitoring();
        break;
    }
  }

  /// Check if sing-box binary is available (desktop only)
  Future<bool> isBinaryAvailable() async {
    if (!_isDesktop || _processManager == null) return false;
    final path = await _processManager!.findBinary();
    return path != null;
  }

  /// Get the directory where sing-box should be placed
  Future<String> getBinaryDirectory() async {
    return SingboxProcessManager.getBinaryDir();
  }

  /// Get download URL for sing-box binary
  String getDownloadUrl() {
    return SingboxProcessManager.getDownloadUrl('1.13.0');
  }

  /// Start sing-box with the raw config from subscription
  Future<bool> start(String rawConfig) async {
    if (_isWeb) {
      _emit(_state.copyWith(
        status: SingboxStatus.error,
        errorMessage: 'VPN is not supported on web platform',
      ));
      return false;
    }

    _emit(_state.copyWith(status: SingboxStatus.starting, errorMessage: null));

    try {
      // Inject Clash API into config
      final configWithApi = SingboxConfigBuilder.injectClashApi(rawConfig);

      bool started;

      if (_isDesktop) {
        // Desktop: check binary exists
        final binaryAvailable = await isBinaryAvailable();
        if (!binaryAvailable) {
          final dir = await getBinaryDirectory();
          _emit(_state.copyWith(
            status: SingboxStatus.error,
            errorMessage:
                'sing-box not found.\nPlease download sing-box and place it in:\n$dir',
          ));
          return false;
        }
        started = await _processManager!.start(configWithApi);
      } else {
        // Mobile: request permission first
        final hasPermission =
            await _platformChannel!.requestVpnPermission();
        if (!hasPermission) {
          _emit(_state.copyWith(
            status: SingboxStatus.error,
            errorMessage: 'VPN permission denied',
          ));
          return false;
        }
        await _platformChannel!.writeConfig(configWithApi);
        started = await _platformChannel!.start(configWithApi);
      }

      if (!started) {
        _emit(_state.copyWith(
          status: SingboxStatus.error,
          errorMessage: 'Failed to start sing-box',
        ));
        return false;
      }

      // Wait for Clash API to become available
      final apiReady = await _waitForClashApi();
      if (!apiReady) {
        // sing-box process started but API not ready yet - might still be initializing
        // Keep status as running since process is alive
        debugPrint('Warning: Clash API not ready after timeout');
      }

      _emit(_state.copyWith(status: SingboxStatus.running));
      _startMonitoring();
      await refreshProxies();

      return true;
    } catch (e) {
      _emit(_state.copyWith(
        status: SingboxStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  /// Stop sing-box
  Future<bool> stop() async {
    if (_isWeb) return false;

    _emit(_state.copyWith(status: SingboxStatus.stopping));
    _stopMonitoring();

    try {
      await _clashApi.closeAllConnections();

      bool stopped;
      if (_isDesktop) {
        stopped = await _processManager!.stop();
      } else {
        stopped = await _platformChannel!.stop();
      }

      _emit(const SingboxState(status: SingboxStatus.stopped));
      return stopped;
    } catch (e) {
      _emit(const SingboxState(status: SingboxStatus.stopped));
      return false;
    }
  }

  /// Toggle connection
  Future<bool> toggle(String rawConfig) async {
    if (_state.isRunning) {
      return stop();
    } else {
      return start(rawConfig);
    }
  }

  /// Select a proxy node
  Future<bool> selectProxy(String group, String proxyName) async {
    final success = await _clashApi.selectProxy(group, proxyName);
    if (success) {
      _emit(_state.copyWith(selectedNode: proxyName));
      await refreshProxies();
    }
    return success;
  }

  /// Test proxy latency
  Future<int> testProxyDelay(String proxyName) async {
    return _clashApi.getProxyDelay(proxyName);
  }

  /// Refresh proxy list from Clash API
  Future<void> refreshProxies() async {
    final data = await _clashApi.getProxies();
    final proxiesMap = data['proxies'] as Map<String, dynamic>? ?? {};

    final proxies = <SingboxProxy>[];
    final groups = <SingboxProxyGroup>[];
    String? selectedNode;

    proxiesMap.forEach((name, value) {
      if (value is! Map<String, dynamic>) return;
      final type = value['type'] as String? ?? '';

      if (type == 'Selector' || type == 'URLTest' || type == 'Fallback') {
        final all = (value['all'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final now = value['now'] as String?;
        groups.add(SingboxProxyGroup(
          name: name,
          type: type,
          now: now,
          all: all,
        ));
        if (selectedNode == null && now != null) {
          selectedNode = now;
        }
      } else if (type != 'Direct' && type != 'Reject' && type != 'Block') {
        proxies.add(SingboxProxy(
          name: name,
          type: type,
          delay: (value['history'] as List?)?.isNotEmpty == true
              ? ((value['history'] as List).last['delay'] as num?)
                      ?.toInt() ??
                  -1
              : -1,
        ));
      }
    });

    _emit(_state.copyWith(
      proxies: proxies,
      proxyGroups: groups,
      selectedNode: selectedNode ?? _state.selectedNode,
    ));
  }

  Future<bool> _waitForClashApi({int maxRetries = 10}) async {
    for (var i = 0; i < maxRetries; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await _clashApi.isRunning()) return true;
    }
    return false;
  }

  void _startMonitoring() {
    _trafficSub?.cancel();
    _trafficSub = _clashApi.watchTraffic().listen((traffic) {
      _emit(_state.copyWith(
        uploadSpeed: traffic['up'] ?? 0,
        downloadSpeed: traffic['down'] ?? 0,
        uploadTotal: _state.uploadTotal + (traffic['up'] ?? 0),
        downloadTotal: _state.downloadTotal + (traffic['down'] ?? 0),
      ));
    });

    _proxyPollTimer?.cancel();
    _proxyPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      refreshProxies();
    });
  }

  void _stopMonitoring() {
    _trafficSub?.cancel();
    _trafficSub = null;
    _proxyPollTimer?.cancel();
    _proxyPollTimer = null;
  }

  void dispose() {
    _stopMonitoring();
    _statusSub?.cancel();
    _logSub?.cancel();
    _stateController.close();
    _clashApi.dispose();
    _processManager?.dispose();
  }
}
