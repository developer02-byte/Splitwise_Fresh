import 'package:dio/dio.dart';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

/// Dio interceptor for handling 401 Unauthorized errors and automatically
/// attaching JWT tokens.
class AuthInterceptor extends Interceptor {
  final Dio dio;

  AuthInterceptor(this.dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      log('Error reading token: $e', name: 'AuthInterceptor');
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      log('HTTP 401: Attempting silent refresh...', name: 'AuthInterceptor');
      
      try {
        // Since tokens are stored in HttpOnly cookies, we just hit the refresh
        // endpoint. The browser/cookie_jar handles sending the refresh_token cookie.
        final refreshResponse = await dio.post('/api/auth/refresh');
        
        if (refreshResponse.statusCode == 200) {
          // Token rotated successfully (new cookie received). 
          // Re-attempt original request.
          final opts = err.requestOptions;
          final cloneReq = await dio.request(
            opts.path,
            options: Options(
              method: opts.method,
              headers: opts.headers,
            ),
            data: opts.data,
            queryParameters: opts.queryParameters,
          );
          return handler.resolve(cloneReq);
        }
      } catch (e) {
        log('Refresh Failed. Forcing logout.', name: 'AuthInterceptor');
        // TODO: Dispatch logout event to GoRouter / Riverpod
      }
    }
    
    return handler.next(err);
  }
}
