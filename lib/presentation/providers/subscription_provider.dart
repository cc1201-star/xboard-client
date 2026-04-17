import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/data/api/models/subscribe_info.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';

class SubscriptionState {
  final SubscribeInfo? info;
  final bool isLoading;
  final String? error;
  final String? mihomoConfig;

  const SubscriptionState({
    this.info,
    this.isLoading = false,
    this.error,
    this.mihomoConfig,
  });

  SubscriptionState copyWith({
    SubscribeInfo? info,
    bool? isLoading,
    String? error,
    String? mihomoConfig,
  }) {
    return SubscriptionState(
      info: info ?? this.info,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      mihomoConfig: mihomoConfig ?? this.mihomoConfig,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final Ref _ref;

  SubscriptionNotifier(this._ref) : super(const SubscriptionState());

  Future<void> fetchSubscription() async {
    final client = _ref.read(apiClientProvider);
    if (client == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await client.getSubscribe();
      final data = response.data['data'] as Map<String, dynamic>;
      final info = SubscribeInfo.fromJson(data);

      state = state.copyWith(info: info, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to fetch subscription');
    }
  }

  Future<void> fetchMihomoConfig() async {
    final client = _ref.read(apiClientProvider);
    final subscribeUrl = state.info?.subscribeUrl;
    if (client == null || subscribeUrl == null) return;

    try {
      final response = await client.fetchMihomoConfig(subscribeUrl);
      final config = response.data is String ? response.data : response.data.toString();
      state = state.copyWith(mihomoConfig: config);
    } catch (e) {
      state = state.copyWith(error: 'Failed to fetch config');
    }
  }

  /// 启动 VPN / 选择节点前的可用性校验。
  /// 返回 null 表示可用，否则返回应展示给用户的中文原因。
  /// remaining 包含套餐 + 全部流量包，所以这里一次性覆盖两类流量耗尽场景。
  Future<String?> ensureUsable() async {
    await fetchSubscription();
    final info = state.info;
    if (info == null) return '获取订阅信息失败';
    if (info.isExpired) return '套餐已到期，请先续费';
    if (info.transferEnable <= 0) return '账户尚未分配流量，请先购买套餐或流量包';
    if (info.remaining <= 0) return '账户流量已耗尽，请购买流量包或等待重置';
    return null;
  }

  Future<void> resetSecurity() async {
    final client = _ref.read(apiClientProvider);
    if (client == null) return;

    state = state.copyWith(isLoading: true);
    try {
      await client.resetSecurity();
      await fetchSubscription();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to reset security');
    }
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(ref);
});
