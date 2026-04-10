import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/data/api/models/user_info.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';

class UserState {
  final UserInfo? user;
  final List<int>? stat;
  final bool isLoading;
  final String? error;

  const UserState({this.user, this.stat, this.isLoading = false, this.error});

  UserState copyWith({UserInfo? user, List<int>? stat, bool? isLoading, String? error}) {
    return UserState(
      user: user ?? this.user,
      stat: stat ?? this.stat,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UserNotifier extends StateNotifier<UserState> {
  final Ref _ref;

  UserNotifier(this._ref) : super(const UserState());

  Future<void> fetchUser() async {
    final client = _ref.read(apiClientProvider);
    if (client == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await client.getUserInfo();
      final data = response.data['data'] as Map<String, dynamic>;
      final user = UserInfo.fromJson(data);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '获取用户信息失败');
    }
  }

  Future<void> fetchStat() async {
    final client = _ref.read(apiClientProvider);
    if (client == null) return;

    try {
      final response = await client.getStat();
      final data = response.data['data'];
      if (data is List) {
        state = state.copyWith(stat: data.cast<int>());
      }
    } catch (_) {}
  }

  Future<void> fetchAll() async {
    await Future.wait([fetchUser(), fetchStat()]);
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref);
});
