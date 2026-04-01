import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class GroupAnalyticsModel {
  final List<dynamic> spendingByCategory;
  final List<dynamic> leaderboard;

  GroupAnalyticsModel({required this.spendingByCategory, required this.leaderboard});

  factory GroupAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return GroupAnalyticsModel(
      spendingByCategory: json['spendingByCategory'] ?? [],
      leaderboard: json['leaderboard'] ?? [],
    );
  }
}

final groupAnalyticsProvider = FutureProvider.family<GroupAnalyticsModel, int>((ref, groupId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/analytics/groups/$groupId');
  
  if (response.data['success'] == true) {
    return GroupAnalyticsModel.fromJson(response.data['data']);
  }
  throw Exception('Failed to load group analytics');
});
