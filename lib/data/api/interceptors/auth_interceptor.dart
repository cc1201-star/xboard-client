import 'package:dio/dio.dart';
import 'package:xboard_client/data/local/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;

  AuthInterceptor(this._storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getAuthToken();
    if (token != null) {
      options.headers['Authorization'] = token;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      _storage.clearAll();
    }
    handler.next(err);
  }
}
