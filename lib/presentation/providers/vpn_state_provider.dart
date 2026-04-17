import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/data/mihomo/mihomo_service.dart';
import 'package:xboard_client/presentation/providers/subscription_provider.dart';

enum VpnStatus { disconnected, connecting, connected, disconnecting }

class VpnState {
  final VpnStatus status;
  final String? currentNode;
  final int uploadSpeed;
  final int downloadSpeed;
  final int uploadTotal;
  final int downloadTotal;
  final Duration connectedDuration;
  final String? errorMessage;
  final List<MihomoProxy> proxies;
  final List<MihomoProxyGroup> proxyGroups;
  final List<String> logs;

  const VpnState({
    this.status = VpnStatus.disconnected,
    this.currentNode,
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.uploadTotal = 0,
    this.downloadTotal = 0,
    this.connectedDuration = Duration.zero,
    this.errorMessage,
    this.proxies = const [],
    this.proxyGroups = const [],
    this.logs = const [],
  });

  bool get isConnected => status == VpnStatus.connected;
  bool get isDisconnected => status == VpnStatus.disconnected;

  VpnState copyWith({
    VpnStatus? status,
    String? currentNode,
    int? uploadSpeed,
    int? downloadSpeed,
    int? uploadTotal,
    int? downloadTotal,
    Duration? connectedDuration,
    String? errorMessage,
    List<MihomoProxy>? proxies,
    List<MihomoProxyGroup>? proxyGroups,
    List<String>? logs,
  }) {
    return VpnState(
      status: status ?? this.status,
      currentNode: currentNode ?? this.currentNode,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadTotal: uploadTotal ?? this.uploadTotal,
      downloadTotal: downloadTotal ?? this.downloadTotal,
      connectedDuration: connectedDuration ?? this.connectedDuration,
      errorMessage: errorMessage,
      proxies: proxies ?? this.proxies,
      proxyGroups: proxyGroups ?? this.proxyGroups,
      logs: logs ?? this.logs,
    );
  }
}

class VpnNotifier extends StateNotifier<VpnState> {
  final MihomoService _mihomo;
  final Ref _ref;
  StreamSubscription<MihomoState>? _stateSub;
  Timer? _durationTimer;
  Timer? _trafficMonitorTimer;
  DateTime? _connectedSince;

  // 连接期间每隔多久拉一次账户剩余流量；服务端 sync 也是周期性的，
  // 30s 足够及时拦截而不会给 API 造成压力。
  static const Duration _trafficCheckInterval = Duration(seconds: 30);

  VpnNotifier(this._mihomo, this._ref) : super(const VpnState()) {
    _stateSub = _mihomo.stateStream.listen(_onMihomoState);
  }

  void _onMihomoState(MihomoState s) {
    final vpnStatus = switch (s.status) {
      MihomoStatus.stopped => VpnStatus.disconnected,
      MihomoStatus.starting => VpnStatus.connecting,
      MihomoStatus.running => VpnStatus.connected,
      MihomoStatus.stopping => VpnStatus.disconnecting,
      MihomoStatus.error => VpnStatus.disconnected,
    };

    if (vpnStatus == VpnStatus.connected && _connectedSince == null) {
      _connectedSince = DateTime.now();
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_connectedSince != null) {
          state = state.copyWith(
            connectedDuration: DateTime.now().difference(_connectedSince!),
          );
        }
      });
      _startTrafficMonitor();
    } else if (vpnStatus == VpnStatus.disconnected) {
      _connectedSince = null;
      _durationTimer?.cancel();
      _stopTrafficMonitor();
    }

    state = state.copyWith(
      status: vpnStatus,
      uploadSpeed: s.uploadSpeed,
      downloadSpeed: s.downloadSpeed,
      uploadTotal: s.uploadTotal,
      downloadTotal: s.downloadTotal,
      currentNode: s.selectedNode,
      errorMessage: s.errorMessage,
      proxies: s.proxies,
      proxyGroups: s.proxyGroups,
      logs: s.logs,
    );
  }

  /// Connect using the raw Clash.Meta YAML config from the subscription.
  Future<bool> connect(String mihomoConfig) async {
    if (kIsWeb) {
      state = state.copyWith(
        errorMessage: 'VPN 功能不支持 Web 平台，请下载桌面或安卓客户端',
      );
      return false;
    }
    return await _mihomo.start(mihomoConfig);
  }

  Future<void> disconnect() async {
    _stopTrafficMonitor();
    await _mihomo.stop();
  }

  void _startTrafficMonitor() {
    _trafficMonitorTimer?.cancel();
    _trafficMonitorTimer = Timer.periodic(_trafficCheckInterval, (_) async {
      try {
        final subNotifier = _ref.read(subscriptionProvider.notifier);
        await subNotifier.fetchSubscription();
        final info = _ref.read(subscriptionProvider).info;
        if (info == null) return;
        if (info.isExpired) {
          await disconnect();
          state = state.copyWith(errorMessage: '套餐已到期，已自动断开');
        } else if (info.remaining <= 0) {
          await disconnect();
          state = state.copyWith(errorMessage: '账户流量已耗尽，已自动断开');
        }
      } catch (_) {
        // 网络抖动等失败不强制断开，等下个周期重试
      }
    });
  }

  void _stopTrafficMonitor() {
    _trafficMonitorTimer?.cancel();
    _trafficMonitorTimer = null;
  }

  /// The primary Selector proxy group name discovered from mihomo runtime.
  String? get primaryGroup => _mihomo.primaryGroup;

  /// Find the Selector group that contains a specific proxy node.
  String? findGroupFor(String proxyName) => _mihomo.findGroupFor(proxyName);

  /// Returns null on success, or an error message on failure.
  Future<String?> selectNode(String group, String proxyName) async {
    return _mihomo.selectProxy(group, proxyName);
  }

  Future<int> testDelay(String proxyName) async {
    return _mihomo.testProxyDelay(proxyName);
  }

  Future<void> refreshProxies() async {
    await _mihomo.refreshProxies();
    // Immediately sync mihomo's internal state to Riverpod,
    // don't wait for async stream propagation.
    _onMihomoState(_mihomo.currentState);
  }

  /// Read proxy list directly from mihomo (bypasses stream delay).
  List<MihomoProxy> get mihomoProxies => _mihomo.currentState.proxies;

  @override
  void dispose() {
    _stateSub?.cancel();
    _durationTimer?.cancel();
    _trafficMonitorTimer?.cancel();
    _mihomo.dispose();
    super.dispose();
  }
}

final mihomoServiceProvider = Provider<MihomoService>((ref) {
  final service = MihomoService();
  ref.onDispose(() => service.dispose());
  return service;
});

final vpnStateProvider = StateNotifierProvider<VpnNotifier, VpnState>((ref) {
  final mihomo = ref.watch(mihomoServiceProvider);
  return VpnNotifier(mihomo, ref);
});
