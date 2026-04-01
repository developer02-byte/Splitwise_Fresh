import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_provider.dart';
import 'dart:convert';

enum ActivityType { expense, settlement }

enum ActivityFilter { all, groups, friends, lent, borrowed, expenses, settlements }

class ActivityItem {
  final int id;
  final ActivityType type;
  final String title;
  final int amountCents;
  final String currency;
  final String paidBy;
  final String? avatarUrl;
  final int yourShareCents;
  final bool youPaid;
  final DateTime createdAt;

  ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.amountCents,
    required this.currency,
    required this.paidBy,
    this.avatarUrl,
    required this.yourShareCents,
    required this.youPaid,
    required this.createdAt,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id'] as int,
      type: json['type'] == 'settlement' ? ActivityType.settlement : ActivityType.expense,
      title: json['title'] as String,
      amountCents: json['amountCents'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      paidBy: json['paidBy'] as String? ?? 'Unknown',
      avatarUrl: json['avatarUrl'] as String?,
      yourShareCents: json['yourShareCents'] as int? ?? 0,
      youPaid: json['youPaid'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type == ActivityType.settlement ? 'settlement' : 'expense',
      'title': title,
      'amountCents': amountCents,
      'currency': currency,
      'paidBy': paidBy,
      'avatarUrl': avatarUrl,
      'yourShareCents': yourShareCents,
      'youPaid': youPaid,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ActivityState {
  final List<ActivityItem> items;
  final ActivityFilter filter;
  final int? nextCursor;
  final bool hasMore;

  ActivityState({
    required this.items,
    required this.filter,
    this.nextCursor,
    this.hasMore = true,
  });

  ActivityState copyWith({
    List<ActivityItem>? items,
    ActivityFilter? filter,
    int? nextCursor,
    bool? hasMore,
  }) {
    return ActivityState(
      items: items ?? this.items,
      filter: filter ?? this.filter,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class ActivityNotifier extends AsyncNotifier<ActivityState> {
  @override
  Future<ActivityState> build() async {
    return _fetchItems();
  }

  Future<ActivityState> _fetchItems({ActivityFilter filter = ActivityFilter.all, int? cursor}) async {
    final dio = ref.read(dioProvider);
    
    final params = <String, dynamic>{
      if (cursor != null) 'cursor': cursor,
    };

    if (filter == ActivityFilter.lent) {
      params['role'] = 'lent';
    } else if (filter == ActivityFilter.borrowed) params['role'] = 'borrowed';
    else if (filter == ActivityFilter.expenses) params['type'] = 'expense';
    else if (filter == ActivityFilter.settlements) params['type'] = 'settlement';
    else params['filter'] = filter.name;

    try {
      final response = await dio.get('/api/user/activities', queryParameters: params);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        final list = data['items'] as List<dynamic>;
        final items = list.map((e) => ActivityItem.fromJson(e as Map<String, dynamic>)).toList();
        
        if (cursor == null) {
          final prefs = await SharedPreferences.getInstance();
          final cacheMapped = items.map((e) => e.toJson()).toList();
          await prefs.setString('cached_activities_${filter.name}', jsonEncode(cacheMapped));
        }
        
        return ActivityState(
          items: items, 
          filter: filter, 
          hasMore: data['hasMore'] as bool? ?? false,
          nextCursor: data['nextCursor'] as int?
        );
      } else {
        throw Exception(response.data['error'] ?? 'Failed to load activity');
      }
    } catch (e) {
      if (cursor == null) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_activities_${filter.name}');
        if (cached != null) {
          final list = jsonDecode(cached) as List<dynamic>;
          final items = list.map((e) => ActivityItem.fromJson(e as Map<String, dynamic>)).toList();
          return ActivityState(items: items, filter: filter, hasMore: false);
        }
      }
      rethrow;
    }
  }

  Future<void> fetchMore() async {
    final currentState = state.value;
    if (currentState == null || !currentState.hasMore) return;
    
    try {
      final dio = ref.read(dioProvider);
      final params = <String, dynamic>{
        'cursor': currentState.nextCursor,
      };
      
      final filter = currentState.filter;
      if (filter == ActivityFilter.lent) {
        params['role'] = 'lent';
      } else if (filter == ActivityFilter.borrowed) params['role'] = 'borrowed';
      else if (filter == ActivityFilter.expenses) params['type'] = 'expense';
      else if (filter == ActivityFilter.settlements) params['type'] = 'settlement';
      else params['filter'] = filter.name;

      final response = await dio.get('/api/user/activities', queryParameters: params);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        final list = data['items'] as List<dynamic>;
        final newItems = list.map((e) => ActivityItem.fromJson(e as Map<String, dynamic>)).toList();
        
        state = AsyncData(currentState.copyWith(
          items: [...currentState.items, ...newItems],
          hasMore: data['hasMore'] as bool? ?? false,
          nextCursor: data['nextCursor'] as int?,
        ));
      }
    } catch (_) {}
  }

  Future<void> applyFilter(ActivityFilter filter) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchItems(filter: filter));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchItems(
      filter: state.value?.filter ?? ActivityFilter.all,
    ));
  }
}

final activityNotifierProvider =
    AsyncNotifierProvider<ActivityNotifier, ActivityState>(ActivityNotifier.new);
