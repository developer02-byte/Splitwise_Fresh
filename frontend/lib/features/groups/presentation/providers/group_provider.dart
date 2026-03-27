import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class GroupMock {
  final int id;
  final String name;
  final String type;
  final String? inviteToken;
  final int netBalanceCents;
  
  GroupMock({
    required this.id, 
    required this.name, 
    required this.type,
    this.inviteToken,
    this.netBalanceCents = 0,
  });

  factory GroupMock.fromJson(Map<String, dynamic> json) {
    return GroupMock(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'other',
      inviteToken: json['inviteToken'] as String?,
      netBalanceCents: json['netBalanceCents'] as int? ?? 0,
    );
  }
}

class GroupsNotifier extends AsyncNotifier<List<GroupMock>> {
  @override
  Future<List<GroupMock>> build() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/groups');

    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = response.data['data'] as List<dynamic>;
      return list.map((e) => GroupMock.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load groups');
    }
  }

  Future<void> createGroup(String name, String type) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/groups', data: {
        'name': name,
        'type': type,
      });

      if (response.data['success'] == true) {
        final newGroup = GroupMock.fromJson(response.data['data'] as Map<String, dynamic>);
        final current = state.value ?? [];
        return [newGroup, ...current];
      } else {
        throw Exception(response.data['error'] ?? 'Failed to create group');
      }
    });
  }
}

final groupsNotifierProvider =
    AsyncNotifierProvider<GroupsNotifier, List<GroupMock>>(GroupsNotifier.new);
