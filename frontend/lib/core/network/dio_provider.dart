import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  // Always point to the backend server on port 3000.
  // On web, we must use an explicit URL (not empty string) to avoid
  // requests being sent to the Flutter dev server on port 8080.
  const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000',
  );
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
