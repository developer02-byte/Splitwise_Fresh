import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kDebugMode ? 'http://localhost:3000' : const String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000'),
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
