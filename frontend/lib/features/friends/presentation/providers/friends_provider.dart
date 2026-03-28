import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class FriendModel {
  final int id;
  final int? friendshipId;
  final String name;
  final String email;
  final String? avatarUrl;
  final int netBalanceCents;

  FriendModel({
    required this.id,
    this.friendshipId,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.netBalanceCents,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json['id'] as int,
      friendshipId: json['friendshipId'] as int?,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      netBalanceCents: json['netBalanceCents'] as int? ?? 0,
    );
  }
}

class FriendsNotifier extends AsyncNotifier<List<FriendModel>> {
  @override
  Future<List<FriendModel>> build() async {
    return _fetchFriends();
  }

  Future<List<FriendModel>> _fetchFriends() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/friends');
    if (response.data['success'] == true) {
      final list = response.data['data'] as List<dynamic>;
      return list.map((e) => FriendModel.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load friends');
    }
  }

  Future<void> sendFriendRequest({int? userId, String? email}) async {
    final dio = ref.read(dioProvider);
    await dio.post('/api/friends', data: {
      if (userId != null) 'friendId': userId,
      if (email != null) 'email': email,
    });
    ref.invalidate(pendingRequestsProvider);
  }

  Future<void> handleFriendRequest(int friendshipId, String status) async {
    final dio = ref.read(dioProvider);
    await dio.patch('/api/friends/$friendshipId', data: {'status': status});
    ref.invalidateSelf();
    ref.invalidate(pendingRequestsProvider);
  }

  Future<void> removeFriend(int friendshipId) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/api/friends/$friendshipId');
    ref.invalidateSelf();
  }
}

final friendsNotifierProvider = 
    AsyncNotifierProvider<FriendsNotifier, List<FriendModel>>(FriendsNotifier.new);

// Pending requests provider
final pendingRequestsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/friends/pending');
  if (response.data['success'] == true) {
    return response.data['data'] as List<dynamic>;
  }
  return [];
});

// Search results provider
final userSearchProvider = FutureProvider.family<List<dynamic>, String>((ref, query) async {
  if (query.length < 2) return [];
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/friends/search', queryParameters: {'q': query});
  if (response.data['success'] == true) {
    return response.data['data'] as List<dynamic>;
  }
  return [];
});
