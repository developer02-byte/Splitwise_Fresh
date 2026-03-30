import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class GroupAnalytics {
  final List<CategoryBreakdown> categoryBreakdown;
  final List<LeaderboardItem> leaderboard;

  GroupAnalytics({required this.categoryBreakdown, required this.leaderboard});

  factory GroupAnalytics.fromJson(Map<String, dynamic> json) {
    return GroupAnalytics(
      categoryBreakdown: (json['categoryBreakdown'] as List<dynamic>)
          .map((e) => CategoryBreakdown.fromJson(e))
          .toList(),
      leaderboard: (json['leaderboard'] as List<dynamic>)
          .map((e) => LeaderboardItem.fromJson(e))
          .toList(),
    );
  }
}

class CategoryBreakdown {
  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final int totalAmount;
  final int count;

  CategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.totalAmount,
    required this.count,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      categoryId: json['categoryId'],
      categoryName: json['categoryName'],
      categoryIcon: json['categoryIcon'],
      totalAmount: json['totalAmount'],
      count: json['count'],
    );
  }
}

class LeaderboardItem {
  final int userId;
  final String userName;
  final String? avatarUrl;
  final int totalPaid;

  LeaderboardItem({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.totalPaid,
  });

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) {
    return LeaderboardItem(
      userId: json['userId'],
      userName: json['userName'],
      avatarUrl: json['avatarUrl'],
      totalPaid: json['totalPaid'],
    );
  }
}

final groupAnalyticsProvider =
    FutureProvider.family<GroupAnalytics, int>((ref, groupId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/api/groups/$groupId/analytics');

  if (response.data['success'] == true) {
    return GroupAnalytics.fromJson(response.data['data']);
  } else {
    throw Exception('Failed to load group analytics');
  }
});
