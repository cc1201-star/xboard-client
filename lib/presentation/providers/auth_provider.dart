import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/data/api/models/auth_response.dart';
import 'package:xboard_client/data/api/xboard_api_client.dart';
import 'package:xboard_client/data/api/interceptors/auth_interceptor.dart';
import 'package:xboard_client/data/local/secure_storage.dart';
import 'package:xboard_client/presentation/providers/vpn_state_provider.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor(ref.read(secureStorageProvider));
});

final apiClientProvider = Provider<XboardApiClient?>((ref) {
  final state = ref.watch(authStateProvider);
  if (state.baseUrl == null) return null;
  return XboardApiClient(
    baseUrl: state.baseUrl!,
    authInterceptor: ref.read(authInterceptorProvider),
  );
});

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isInitialized;
  final String? error;
  final String? baseUrl;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
    this.baseUrl,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isInitialized,
    String? error,
    String? baseUrl,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }
}

/// 从 API 响应中提取错误信息，优先读 errors 字段（Laravel 验证错误）
String _extractError(Map? responseData, String fallback) {
  if (responseData == null) return fallback;
  // Laravel 验证错误格式: { "message": "...", "errors": { "field": ["错误信息"] } }
  final errors = responseData['errors'];
  if (errors is Map && errors.isNotEmpty) {
    final firstField = errors.values.first;
    if (firstField is List && firstField.isNotEmpty) {
      return firstField[0] as String;
    }
  }
  return responseData['message'] as String? ?? fallback;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SecureStorageService _storage;
  final Ref _ref;

  AuthNotifier(this._storage, this._ref) : super(const AuthState());

  Future<void> checkAuth() async {
    final hasToken = await _storage.hasAuthToken();
    final baseUrl = await _storage.getBaseUrl();
    if (hasToken && baseUrl != null) {
      // 有 token，先直接进主页，不等网络验证
      state = state.copyWith(isAuthenticated: true, baseUrl: baseUrl, isInitialized: true);
      // 后台验证 token 是否还有效
      try {
        final client = XboardApiClient(
          baseUrl: baseUrl,
          authInterceptor: _ref.read(authInterceptorProvider),
        );
        final resp = await client.getUserInfo();
        if (resp.data == null || resp.data['data'] == null) {
          await _storage.clearAll();
          state = const AuthState(isInitialized: true);
        }
      } catch (_) {
        await _storage.clearAll();
        state = const AuthState(isInitialized: true);
      }
    } else {
      state = state.copyWith(isAuthenticated: false, baseUrl: baseUrl, isInitialized: true);
    }
  }

  Future<void> login(String serverUrl, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null, baseUrl: serverUrl);

    try {
      final client = XboardApiClient(
        baseUrl: serverUrl,
        authInterceptor: _ref.read(authInterceptorProvider),
      );

      final response = await client.login(email, password);
      final resData = response.data;

      // Check for API-level failure
      if (resData is Map && resData['data'] == null) {
        final msg = resData['message'] as String? ?? '登录失败';
        state = state.copyWith(isLoading: false, error: msg);
        return;
      }

      final data = resData['data'] as Map<String, dynamic>;
      final auth = AuthResponse.fromJson(data);

      await _storage.saveAuthToken(auth.authData);
      await _storage.saveBaseUrl(serverUrl);

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        isInitialized: true,
        baseUrl: serverUrl,
      );
    } on DioException catch (e) {
      final errorMsg = _extractError(e.response?.data as Map?, '登录失败');
      state = state.copyWith(isLoading: false, error: errorMsg);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '登录失败');
    }
  }

  Future<void> register(String serverUrl, String username, String password) async {
    state = state.copyWith(isLoading: true, error: null, baseUrl: serverUrl);

    try {
      final client = XboardApiClient(
        baseUrl: serverUrl,
        authInterceptor: _ref.read(authInterceptorProvider),
      );

      final response = await client.register(email: username, password: password);
      final resData = response.data;

      // Check for API-level failure
      if (resData is Map && resData['data'] == null) {
        final msg = resData['message'] as String? ?? '注册失败';
        state = state.copyWith(isLoading: false, error: msg);
        return;
      }

      final data = resData['data'] as Map<String, dynamic>?;
      final authData = data?['auth_data'] as String?;
      final token = data?['token'] as String?;
      final effectiveToken = authData ?? token;

      if (effectiveToken != null && effectiveToken.isNotEmpty) {
        await _storage.saveAuthToken(effectiveToken);
        await _storage.saveBaseUrl(serverUrl);
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          baseUrl: serverUrl,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on DioException catch (e) {
      final errorMsg = _extractError(e.response?.data as Map?, '注册失败');
      state = state.copyWith(isLoading: false, error: errorMsg);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '注册失败');
    }
  }

  Future<void> importSubscribeUrl(String subscribeUrl) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final uri = Uri.parse(subscribeUrl);
      final baseUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';

      await _storage.saveSubscribeUrl(subscribeUrl);
      await _storage.saveBaseUrl(baseUrl);

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        baseUrl: baseUrl,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Invalid subscribe URL');
    }
  }

  Future<void> logout() async {
    // 先停止 VPN 连接和相关定时器
    try {
      final vpnNotifier = _ref.read(vpnStateProvider.notifier);
      await vpnNotifier.disconnect();
    } catch (_) {}
    // 清除存储
    await _storage.clearAll();
    state = const AuthState(isInitialized: true);
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.read(secureStorageProvider);
  return AuthNotifier(storage, ref);
});
