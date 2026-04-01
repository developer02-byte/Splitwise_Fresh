import 'dart:developer';


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../../core/network/dio_provider.dart';

class AuthNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async {
    return _fetchCurrentUser(); 
  }

  Future<Map<String, dynamic>?> _fetchCurrentUser() async {
    try {
      final dio = ref.read(dioProvider);
      log('Fetching current user...', name: 'AuthNotifier');
      final response = await dio.get('/api/user/me').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('Timeout fetching user data. Failing safely.', name: 'AuthNotifier');
          throw Exception('Auth API timeout');
        },
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      log('Auth Error (unauthenticated or network): $e', name: 'AuthNotifier');
    }
    return null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (email.isEmpty || password.isEmpty) throw Exception('Fields required');
      final dio = ref.read(dioProvider);
      try {
        final response = await dio.post('/api/auth/login', data: {
          'email': email,
          'password': password,
        });
        
        if (response.data['success'] == true) {
          final data = response.data['data'] as Map<String, dynamic>;
          if (data.containsKey('token')) {
            const storage = FlutterSecureStorage();
            await storage.write(key: 'auth_token', value: data['token'] as String);
          }
          // Fetch full user profile (includes onboardingCompleted)
          return await _fetchCurrentUser();
        } else {
          throw Exception(response.data['error'] ?? 'Login failed');
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          throw Exception('Too many attempts');
        }
        final message = e.response?.data?['error'] ?? 'Login failed. Please check your credentials.';
        throw Exception(message);
      }
    });
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (name.isEmpty || email.isEmpty || password.isEmpty) throw Exception('Fields required');
      final dio = ref.read(dioProvider);
      try {
        final response = await dio.post('/api/auth/signup', data: {
          'name': name,
          'email': email,
          'password': password,
        });

        if (response.data['success'] == true) {
          final data = response.data['data'] as Map<String, dynamic>;
          if (data.containsKey('token')) {
            const storage = FlutterSecureStorage();
            await storage.write(key: 'auth_token', value: data['token'] as String);
          }
          // Fetch full user profile (includes onboardingCompleted)
          return await _fetchCurrentUser();
        } else {
          throw Exception(response.data['error'] ?? 'Registration failed');
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          throw Exception('Too many attempts');
        }
        final message = e.response?.data?['error'] ?? 'Registration failed.';
        throw Exception(message);
      }
    });
  }

  Future<void> loginWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        final account = await googleSignIn.signIn();
        if (account == null) throw Exception('Google sign-in cancelled');

        final auth = await account.authentication;
        if (auth.idToken == null) throw Exception('Google auth failed (no token)');

        final dio = ref.read(dioProvider);
        final response = await dio.post('/api/auth/google', data: {
          'id_token': auth.idToken,
        });

        if (response.data['success'] == true) {
          final data = response.data['data'] as Map<String, dynamic>;
          if (data.containsKey('token')) {
            const storage = FlutterSecureStorage();
            await storage.write(key: 'auth_token', value: data['token'] as String);
          }
          return await _fetchCurrentUser();
        } else {
          throw Exception(response.data['error'] ?? 'Google login failed');
        }
      } catch (e) {
        throw Exception('Google sign-in failed: \$e');
      }
    });
  }

  Future<void> loginWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        final name = [credential.givenName, credential.familyName]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');

        final dio = ref.read(dioProvider);
        final response = await dio.post('/api/auth/apple', data: {
          'identity_token': credential.identityToken!,
          if (name.isNotEmpty) 'name': name,
        });

        if (response.data['success'] == true) {
          final data = response.data['data'] as Map<String, dynamic>;
          if (data.containsKey('token')) {
            const storage = FlutterSecureStorage();
            await storage.write(key: 'auth_token', value: data['token'] as String);
          }
          return await _fetchCurrentUser();
        } else {
          throw Exception(response.data['error'] ?? 'Apple login failed');
        }
      } on SignInWithAppleAuthorizationException catch (e) {
        if (e.code == AuthorizationErrorCode.canceled) throw Exception('Apple sign-in cancelled');
        throw Exception('Apple sign-in failed: \$e');
      } catch (e) {
        throw Exception('Apple sign-in error: \$e');
      }
    });
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      try {
        await dio.post('/api/auth/logout');
      } catch (_) {}
      
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'auth_token');
      
      return null;
    });
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, Map<String, dynamic>?>(AuthNotifier.new);
