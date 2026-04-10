import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/data/singbox/singbox_service.dart';

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
  final List<SingboxProxy> proxies;
  final List<SingboxProxyGroup> proxyGroups;
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
    List<SingboxProxy>? proxies,
    List<SingboxProxyGroup>? proxyGroups,
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
  final SingboxService _singbox;
  StreamSubscription<SingboxState>? _stateSub;
  Timer? _durationTimer;
  DateTime? _connectedSince;

  VpnNotifier(this._singbox) : super(const VpnState()) {
    _stateSub = _singbox.stateStream.listen(_onSingboxState);
  }

  void _onSingboxState(SingboxState s) {
    final vpnStatus = switch (s.status) {
      SingboxStatus.stopped => VpnStatus.disconnected,
      SingboxStatus.starting => VpnStatus.connecting,
      SingboxStatus.running => VpnStatus.connected,
      SingboxStatus.stopping => VpnStatus.disconnecting,
      SingboxStatus.error => VpnStatus.disconnected,
    };

    // Start/stop duration timer
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

  /// Connect using the raw sing-box config from subscription
  Future<void> connect(String singboxConfig) async {
    if (kIsWeb) {
      state = state.copyWith(
        errorMessage: 'VPN 功能不支持 Web 平台',
      );
      return;
    }
    await _singbox.start(singboxConfig);
  }

  /// Disconnect
  Future<void> disconnect() async {
    await _singbox.stop();
  }

  /// Select a proxy node
  Future<void> selectNode(String group, String proxyName) async {
    await _singbox.selectProxy(group, proxyName);
  }

  /// Test proxy latency
  Future<int> testDelay(String proxyName) async {
    return _singbox.testProxyDelay(proxyName);
  }

  /// Refresh proxy list
  Future<void> refreshProxies() async {
    await _singbox.refreshProxies();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _durationTimer?.cancel();
    _singbox.dispose();
    super.dispose();
  }
}

// Provide the SingboxService as a singleton
final singboxServiceProvider = Provider<SingboxService>((ref) {
  final service = SingboxService();
  ref.onDispose(() => service.dispose());
  return service;
});

final vpnStateProvider = StateNotifierProvider<VpnNotifier, VpnState>((ref) {
  final singbox = ref.watch(singboxServiceProvider);
  return VpnNotifier(singbox);
});
