import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  // On web, use empty baseUrl so all /api/* requests are relative to the
  // current origin (works regardless of which port the app is served on).
  // On mobile/desktop, fall back to explicit API_URL or localhost:3000.
  final apiUrl = kIsWeb
      ? ''
      : const String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');
  final dio = Dio(
    BaseOptions(
      baseUrl: apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      // Automatically send HttpOnly cookies on the web and other platforms
      extra: {'withCredentials': true},
    ),
  );

  dio.interceptors.add(AuthInterceptor(dio));

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
  }

  return dio;
});
