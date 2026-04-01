import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class UserProfile {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String defaultCurrency;
  final String provider;
  final String timezone;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.defaultCurrency = 'USD',
    this.provider = 'email',
    this.timezone = 'UTC',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      defaultCurrency: json['defaultCurrency'] as String? ?? 'USD',
      provider: json['provider'] as String? ?? 'email',
      timezone: json['timezone'] as String? ?? 'UTC',
    );
  }

  UserProfile copyWith({
    String? name,
    String? defaultCurrency,
    String? timezone,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email,
      avatarUrl: avatarUrl,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      timezone: timezone ?? this.timezone,
      provider: provider,
    );
  }
}

class ProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/user/me');

    if (response.statusCode == 200 && response.data['success'] == true) {
      return UserProfile.fromJson(response.data['data'] as Map<String, dynamic>);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load profile');
    }
  }

  Future<void> updateProfile({String? newName, String? newCurrency, String? newTimezone}) async {
    final current = state.value;
    if (current == null) return;
    
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final response = await dio.put('/api/user/me', data: {
        if (newName != null) 'name': newName,
        if (newCurrency != null) 'defaultCurrency': newCurrency,
        if (newTimezone != null) 'timezone': newTimezone,
      });

      if (response.data['success'] == true) {
        return UserProfile.fromJson(response.data['data'] as Map<String, dynamic>);
      } else {
        throw Exception(response.data['error'] ?? 'Failed to update user profile');
      }
    });
  }

  Future<void> deleteAccount() async {
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.delete('/api/user/me');
      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Failed to delete account');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('An unknown error occurred');
    }
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final dio = ref.read(dioProvider);
    final response = await dio.put('/api/user/me/password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to update password');
    }
  }
}

final profileNotifierProvider = 
    AsyncNotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);
