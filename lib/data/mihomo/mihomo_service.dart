import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:xboard_client/data/mihomo/clash_api_client.dart';
import 'package:xboard_client/data/mihomo/mihomo_config_builder.dart';
import 'package:xboard_client/data/mihomo/mihomo_platform_channel.dart';
import 'package:xboard_client/data/mihomo/mihomo_process_manager.dart';

enum MihomoStatus { stopped, starting, running, stopping, error }

class MihomoProxy {
  final String name;
  final String type;
  final int delay;

  const MihomoProxy({required this.name, required this.type, this.delay = -1});
}

class MihomoProxyGroup {
  final String name;
  final String type;
  final String? now;
  final List<String> all;

  const MihomoProxyGroup({
    required this.name,
    required this.type,
    this.now,
    this.all = const [],
  });
}

class MihomoState {
  final MihomoStatus status;
  final String? errorMessage;
  final int uploadSpeed;
  final int downloadSpeed;
  final int uploadTotal;
  final int downloadTotal;
  final String? selectedNode;
  final List<MihomoProxy> proxies;
  final List<MihomoProxyGroup> proxyGroups;
  final List<String> logs;

  const MihomoState({
    this.status = MihomoStatus.stopped,
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

  bool get isRunning => status == MihomoStatus.running;
  bool get isStopped => status == MihomoStatus.stopped;

  MihomoState copyWith({
    MihomoStatus? status,
    String? errorMessage,
    int? uploadSpeed,
    int? downloadSpeed,
    int? uploadTotal,
    int? downloadTotal,
    String? selectedNode,
    List<MihomoProxy>? proxies,
    List<MihomoProxyGroup>? proxyGroups,
    List<String>? logs,
  }) {
    return MihomoState(
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

/// Orchestrates the mihomo kernel lifecycle and surfaces state for the UI.
///   Desktop (Windows / macOS): runs the bundled mihomo binary as a subprocess.
///   Android: drives the native VpnService via a MethodChannel.
///   Web / Linux / iOS: not supported in this build.
class MihomoService {
  final ClashApiClient _clashApi = ClashApiClient();

  MihomoProcessManager? _processManager;
  MihomoPlatformChannel? _platformChannel;

  final _stateController = StreamController<MihomoState>.broadcast();
  StreamSubscription<Map<String, int>>? _trafficSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<String>? _logSub;
  Timer? _proxyPollTimer;

  MihomoState _state = const MihomoState();

  Stream<MihomoState> get stateStream => _stateController.stream;
  MihomoState get currentState => _state;

  final bool _isDesktop;
  final bool _isAndroid;
  final bool _supported;

  MihomoService()
      : _isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS),
        _isAndroid = !kIsWeb && Platform.isAndroid,
        _supported = !kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isAndroid) {
    if (!_supported) return;

    if (_isDesktop) {
      _processManager = MihomoProcessManager();
      _statusSub = _processManager!.statusStream.listen(_onNativeStatus);
      _logSub = _processManager!.logStream.listen(_onLog);
    } else if (_isAndroid) {
      _platformChannel = MihomoPlatformChannel();
      _statusSub = _platformChannel!.statusStream.listen(_onNativeStatus);
    }
  }

  void _emit(MihomoState newState) {
    _state = newState;
    if (!_stateController.isClosed) _stateController.add(_state);
  }

  void _onLog(String line) {
    final logs = [..._state.logs, line];
    if (logs.length > 500) logs.removeRange(0, logs.length - 500);
    _emit(_state.copyWith(logs: logs));
  }

  void _onNativeStatus(String status) {
    switch (status) {
      case 'started':
        _emit(_state.copyWith(status: MihomoStatus.running));
        _startMonitoring();
        break;
      case 'stopped':
        _emit(_state.copyWith(status: MihomoStatus.stopped));
        _stopMonitoring();
        break;
      case 'error':
        _emit(_state.copyWith(
          status: MihomoStatus.error,
          errorMessage: 'mihomo error',
        ));
        _stopMonitoring();
        break;
    }
  }

  /// Start mihomo with the raw Clash.Meta YAML config from the subscription.
  Future<bool> start(String rawConfig) async {
    if (!_supported) {
      _emit(_state.copyWith(
        status: MihomoStatus.error,
        errorMessage: '当前平台暂不支持 VPN 连接',
      ));
      return false;
    }

    _emit(_state.copyWith(status: MihomoStatus.starting, errorMessage: null));

    try {
      bool started;
      if (_isDesktop) {
        final yaml = MihomoConfigBuilder.prepareDesktop(rawConfig);
        started = await _processManager!.start(yaml);
      } else {
        final granted = await _platformChannel!.requestVpnPermission();
        if (!granted) {
          _emit(_state.copyWith(
            status: MihomoStatus.error,
            errorMessage: 'VPN 权限被拒绝',
          ));
          return false;
        }
        // On Android the native side injects the TUN file descriptor into
        // the config after it has established the VpnService, so we pass
        // the raw YAML through unchanged.
        started = await _platformChannel!.start(rawConfig);
      }

      if (!started) {
        _emit(_state.copyWith(
          status: MihomoStatus.error,
          errorMessage: '启动 mihomo 失败',
        ));
        return false;
      }

      // Wait for the Clash API to come online. Only then declare running —
      // if mihomo crashes on startup the process exit handler will flip state
      // to stopped before we get here.
      _onLog('[INFO] 等待 Clash API 就绪...');
      final apiReady = await _waitForClashApi(maxRetries: 20);
      if (!apiReady) {
        // Process likely crashed. Collect last log lines if available.
        final lastLogs = _state.logs.isNotEmpty
            ? _state.logs.last
            : 'Clash API 未响应';
        if (_isDesktop) await _processManager!.stop();
        _emit(_state.copyWith(
          status: MihomoStatus.error,
          errorMessage: 'mihomo 启动失败: $lastLogs',
        ));
        return false;
      }

      final version = await _clashApi.getVersion();
      _onLog('[INFO] Clash API 就绪，mihomo 版本: $version');

      _emit(_state.copyWith(status: MihomoStatus.running));
      _startMonitoring();
      await refreshProxies();

      // Log discovered proxies for debugging
      final proxyNames = _state.proxies.map((p) => p.name).toList();
      final groupNames = _state.proxyGroups.map((g) => '${g.name}(${g.type},now:${g.now})').toList();
      _onLog('[INFO] 发现 ${proxyNames.length} 个代理节点: $proxyNames');
      _onLog('[INFO] 发现 ${groupNames.length} 个代理组: $groupNames');

      return true;
    } catch (e) {
      _emit(_state.copyWith(
        status: MihomoStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<bool> stop() async {
    if (!_supported) return false;

    _emit(_state.copyWith(status: MihomoStatus.stopping));
    _stopMonitoring();

    try {
      await _clashApi.closeAllConnections();
      bool stopped;
      if (_isDesktop) {
        stopped = await _processManager!.stop();
      } else {
        stopped = await _platformChannel!.stop();
      }
      _emit(const MihomoState(status: MihomoStatus.stopped));
      return stopped;
    } catch (_) {
      _emit(const MihomoState(status: MihomoStatus.stopped));
      return false;
    }
  }

  Future<bool> toggle(String rawConfig) async {
    if (_state.isRunning) return stop();
    return start(rawConfig);
  }

  /// Find the primary Selector proxy group (the one that is NOT 'GLOBAL',
  /// '自动选择', '故障转移', etc.). Falls back to the first Selector group.
  String? get primaryGroup {
    final selectors = _state.proxyGroups
        .where((g) => g.type == 'Selector' && g.name != 'GLOBAL')
        .toList();
    if (selectors.isEmpty) return null;
    return selectors.first.name;
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> selectProxy(String group, String proxyName) async {
    final result = await _clashApi.selectProxyWithError(group, proxyName);
    if (result.ok) {
      _emit(_state.copyWith(selectedNode: proxyName));
      await refreshProxies();
      return null;
    }
    final groups = _state.proxyGroups.map((g) => g.name).toList();
    final errMsg = 'group=$group, proxy=$proxyName, '
        'error=${result.error}, 可用代理组=$groups';
    _onLog('[ERROR] 切换节点失败: $errMsg');
    return errMsg;
  }

  Future<int> testProxyDelay(String proxyName) =>
      _clashApi.getProxyDelay(proxyName);

  Future<void> refreshProxies() async {
    final data = await _clashApi.getProxies();
    final proxiesMap = data['proxies'] as Map<String, dynamic>? ?? {};

    final proxies = <MihomoProxy>[];
    final groups = <MihomoProxyGroup>[];

    // First pass: collect group names so we can distinguish groups from proxies.
    final groupNames = <String>{};
    proxiesMap.forEach((name, value) {
      if (value is! Map<String, dynamic>) return;
      final type = value['type'] as String? ?? '';
      if (type == 'Selector' || type == 'URLTest' || type == 'Fallback') {
        groupNames.add(name);
      }
    });

    proxiesMap.forEach((name, value) {
      if (value is! Map<String, dynamic>) return;
      final type = value['type'] as String? ?? '';

      if (type == 'Selector' || type == 'URLTest' || type == 'Fallback') {
        final all = (value['all'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final now = value['now'] as String?;
        groups.add(MihomoProxyGroup(
          name: name,
          type: type,
          now: now,
          all: all,
        ));
      } else if (type != 'Direct' && type != 'Reject' && type != 'Block') {
        proxies.add(MihomoProxy(
          name: name,
          type: type,
          delay: (value['history'] as List?)?.isNotEmpty == true
              ? ((value['history'] as List).last['delay'] as num?)?.toInt() ??
                  -1
              : -1,
        ));
      }
    });

    // Resolve selectedNode: if already set by selectProxy(), keep it.
    // Only compute from the Clash API on initial load (when null).
    String? selectedNode = _state.selectedNode;
    if (selectedNode == null) {
      // Follow the group chain to find the leaf proxy node.
      // e.g. GLOBAL(now:"XBoard") → XBoard(now:"us|美国-直连") → leaf.
      for (final g in groups) {
        if (g.now != null && !groupNames.contains(g.now)) {
          selectedNode = g.now;
          break;
        }
      }
    }

    _emit(_state.copyWith(
      proxies: proxies,
      proxyGroups: groups,
      selectedNode: selectedNode,
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
