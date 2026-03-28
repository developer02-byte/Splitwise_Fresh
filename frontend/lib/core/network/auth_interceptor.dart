import 'package:dio/dio.dart';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

/// Dio interceptor for handling 401 Unauthorized errors and automatically
/// attaching JWT tokens.
///
/// Uses QueuedInterceptor to properly await async operations like
/// SharedPreferences reads before sending requests.
class AuthInterceptor extends QueuedInterceptor {
  final Dio dio;
  bool _isRefreshing = false;

  AuthInterceptor(this.dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      log('Error reading token: $e', name: 'AuthInterceptor');
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only attempt refresh for 401s, and not if we're already refreshing
    // or if this IS the refresh request itself
    if (err.response?.statusCode == 401 &&
        !_isRefreshing &&
        !err.requestOptions.path.contains('/auth/refresh')) {
      _isRefreshing = true;
      log('HTTP 401: Attempting silent refresh...', name: 'AuthInterceptor');

      try {
        final refreshDio = Dio(dio.options);
        final refreshResponse = await refreshDio.post(
          '/api/auth/refresh',
          data: {},
          options: Options(headers: {'Content-Type': 'application/json'}),
        );

        if (refreshResponse.statusCode == 200 && refreshResponse.data['success'] == true) {
          final newToken = refreshResponse.data['data']['token'] as String;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', newToken);

          _isRefreshing = false;
          // Re-attempt original request
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';

          final cloneReq = await dio.fetch(opts);
          return handler.resolve(cloneReq);
        }
      } catch (e) {
        log('Refresh Failed. Forcing logout.', name: 'AuthInterceptor');
      } finally {
        _isRefreshing = false;
      }
    }

    handler.next(err);
  }
}
