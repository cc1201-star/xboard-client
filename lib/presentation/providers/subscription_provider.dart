import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/data/api/models/subscribe_info.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';

class SubscriptionState {
  final SubscribeInfo? info;
  final bool isLoading;
  final String? error;
  final String? singboxConfig;

  const SubscriptionState({
    this.info,
    this.isLoading = false,
    this.error,
    this.singboxConfig,
  });

  SubscriptionState copyWith({
    SubscribeInfo? info,
    bool? isLoading,
    String? error,
    String? singboxConfig,
  }) {
    return SubscriptionState(
      info: info ?? this.info,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      singboxConfig: singboxConfig ?? this.singboxConfig,
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

  Future<void> fetchSingboxConfig() async {
    final client = _ref.read(apiClientProvider);
    final subscribeUrl = state.info?.subscribeUrl;
    if (client == null || subscribeUrl == null) return;

    try {
      final response = await client.fetchSingboxConfig(subscribeUrl);
      final config = response.data is String ? response.data : response.data.toString();
      state = state.copyWith(singboxConfig: config);
    } catch (e) {
      state = state.copyWith(error: 'Failed to fetch config');
    }
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
