import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class UserPresence {
  final int userId;
  final bool isOnline;
  final DateTime? lastSeenAt;

  UserPresence({required this.userId, required this.isOnline, this.lastSeenAt});

  factory UserPresence.fromJson(Map<String, dynamic> json) {
    return UserPresence(
      userId: json['userId'],
      isOnline: json['isOnline'],
      lastSeenAt: json['lastSeenAt'] != null ? DateTime.parse(json['lastSeenAt']) : null,
    );
  }
}

class PresenceNotifier extends AsyncNotifier<List<UserPresence>> {
  @override
  Future<List<UserPresence>> build() async {
    return _fetchPresence();
  }

  Future<List<UserPresence>> _fetchPresence() async {
    final dio = ref.read(dioProvider);
    try {
      final res = await dio.get('/api/user/presence');
      if (res.data['success'] == true) {
        final list = res.data['data'] as List<dynamic>;
        return list.map((e) => UserPresence.fromJson(e)).toList();
      }
    } catch (e) {
      // Silent fail
    }
    return [];
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPresence());
  }
}

final presenceProvider = AsyncNotifierProvider<PresenceNotifier, List<UserPresence>>(PresenceNotifier.new);
