import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class FriendMock {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final int netBalanceCents;

  FriendMock({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.netBalanceCents,
  });

  factory FriendMock.fromJson(Map<String, dynamic> json) {
    return FriendMock(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      netBalanceCents: json['netBalanceCents'] as int? ?? 0,
    );
  }

  FriendMock copyWith({
    int? id,
    String? name,
    String? email,
    String? avatarUrl,
    int? netBalanceCents,
  }) {
    return FriendMock(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      netBalanceCents: netBalanceCents ?? this.netBalanceCents,
    );
  }
}

class FriendsNotifier extends AsyncNotifier<List<FriendMock>> {
  @override
  Future<List<FriendMock>> build() async {
    return _fetchFriends();
  }

  Future<List<FriendMock>> _fetchFriends() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/user/friends/balances');

    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = response.data['data'] as List<dynamic>;
      return list.map((e) => FriendMock.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load friends');
    }
  }

  Future<void> addFriend(String name, String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/user/friends', data: {
        'name': name,
        'email': email,
      });

      if (response.data['success'] == true) {
        final currentList = state.value ?? [];
        final newFriend = FriendMock.fromJson(response.data['data'] as Map<String, dynamic>);
        return [newFriend, ...currentList];
      } else {
        throw Exception(response.data['error'] ?? 'Failed to add friend');
      }
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchFriends());
  }
}

final friendsNotifierProvider = 
    AsyncNotifierProvider<FriendsNotifier, List<FriendMock>>(FriendsNotifier.new);
