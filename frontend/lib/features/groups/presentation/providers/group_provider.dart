import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class GroupModel {
  final int id;
  final String name;
  final String type;
  final String? inviteToken;
  final int netBalanceCents;
  final bool simplifiedSettlement;
  final int settlementThreshold;
  final String groupCurrency;
  final List<dynamic>? members; 
  
  GroupModel({
    required this.id, 
    required this.name, 
    required this.type,
    this.inviteToken,
    this.netBalanceCents = 0,
    this.simplifiedSettlement = true,
    this.settlementThreshold = 0,
    this.groupCurrency = 'USD',
    this.members,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'other',
      inviteToken: json['inviteToken'] as String?,
      netBalanceCents: json['userBalance'] as int? ?? json['netBalanceCents'] as int? ?? 0,
      simplifiedSettlement: json['simplifiedSettlement'] as bool? ?? true,
      settlementThreshold: json['settlementThreshold'] as int? ?? 0,
      groupCurrency: json['groupCurrency'] as String? ?? 'USD',
      members: json['members'] as List<dynamic>?,
    );
  }

  GroupModel copyWith({
    String? name,
    String? type,
    bool? simplifiedSettlement,
    int? settlementThreshold,
    String? groupCurrency,
    List<dynamic>? members,
  }) {
    return GroupModel(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      inviteToken: inviteToken,
      netBalanceCents: netBalanceCents,
      simplifiedSettlement: simplifiedSettlement ?? this.simplifiedSettlement,
      settlementThreshold: settlementThreshold ?? this.settlementThreshold,
      groupCurrency: groupCurrency ?? this.groupCurrency,
      members: members ?? this.members,
    );
  }
}

class GroupsNotifier extends AsyncNotifier<List<GroupModel>> {
  @override
  Future<List<GroupModel>> build() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/groups');

    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = response.data['data'] as List<dynamic>;
      return list.map((e) => GroupModel.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load groups');
    }
  }

  Future<void> createGroup(String name, String type, List<int> membersConfig) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post('/api/groups', data: {
      'name': name,
      'type': type,
      'membersConfig': membersConfig,
    });

    if (response.data['success'] == true) {
      final newGroup = GroupModel.fromJson(response.data['data'] as Map<String, dynamic>);
      final current = state.value ?? [];
      state = AsyncData([newGroup, ...current]);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to create group');
    }
  }

  Future<void> updateGroupSettings(int id, Map<String, dynamic> updates) async {
    final dio = ref.read(dioProvider);
    final response = await dio.patch('/api/groups/$id/settings', data: updates);

    if (response.data['success'] == true) {
      final updated = GroupModel.fromJson(response.data['data'] as Map<String, dynamic>);
      final current = state.value ?? [];
      state = AsyncData(current.map((g) => g.id == id ? updated : g).toList());
    }
  }

  Future<void> addMember(int groupId, String email) async {
    final dio = ref.read(dioProvider);
    await dio.post('/api/groups/$groupId/members', data: {'email': email});
    ref.invalidateSelf();
    ref.invalidate(groupMembersProvider(groupId));
  }

  Future<void> removeMember(int groupId, int userId) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/api/groups/$groupId/members/$userId');
    ref.invalidateSelf();
    ref.invalidate(groupMembersProvider(groupId));
  }

  Future<void> updateMemberRole(int groupId, int userId, String role) async {
    final dio = ref.read(dioProvider);
    await dio.patch('/api/groups/$groupId/members/$userId/role', data: {'role': role});
    ref.invalidateSelf();
    ref.invalidate(groupMembersProvider(groupId));
  }

  Future<void> deleteGroup(int id) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/api/groups/$id');
    final current = state.value ?? [];
    state = AsyncData(current.where((g) => g.id != id).toList());
  }
}

final groupsNotifierProvider =
    AsyncNotifierProvider<GroupsNotifier, List<GroupModel>>(GroupsNotifier.new);

final groupMembersProvider = FutureProvider.family<List<dynamic>, int>((ref, groupId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/groups/$groupId/members');
  if (response.data['success'] == true) {
    return response.data['data'] as List<dynamic>;
  }
  throw Exception('Failed to load members');
});
