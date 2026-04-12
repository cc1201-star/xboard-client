import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/data/mihomo/mihomo_service.dart';

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
  StreamSubscription<MihomoState>? _stateSub;
  Timer? _durationTimer;
  DateTime? _connectedSince;

  VpnNotifier(this._mihomo) : super(const VpnState()) {
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
    } else if (vpnStatus == VpnStatus.disconnected) {
      _connectedSince = null;
      _durationTimer?.cancel();
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
    await _mihomo.stop();
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
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _durationTimer?.cancel();
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
  return VpnNotifier(mihomo);
});
