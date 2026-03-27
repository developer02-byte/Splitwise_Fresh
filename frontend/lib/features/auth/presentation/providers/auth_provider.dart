import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_provider.dart';

class AuthNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async {
    return _fetchCurrentUser(); 
  }

  Future<Map<String, dynamic>?> _fetchCurrentUser() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/user/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      // Unauthenticated or network error
    }
    return null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (email.isEmpty || password.isEmpty) throw Exception('Fields required');
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      
      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        if (data.containsKey('token')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['token'] as String);
        }
        return data;
      } else {
        throw Exception(response.data['error'] ?? 'Login failed');
      }
    });
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (name.isEmpty || email.isEmpty || password.isEmpty) throw Exception('Fields required');
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/auth/signup', data: {
        'name': name,
        'email': email,
        'password': password,
      });

      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        if (data.containsKey('token')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['token'] as String);
        }
        return data;
      } else {
        throw Exception(response.data['error'] ?? 'Registration failed');
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
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      
      return null;
    });
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, Map<String, dynamic>?>(AuthNotifier.new);
