import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_provider.dart';
import 'dart:convert';

class UserBalances {
  final int userAreOwed;
  final int userOwe;
  final int totalBalance;
  final String currency;

  UserBalances({
    required this.userAreOwed,
    required this.userOwe,
    required this.totalBalance,
    required this.currency,
  });

  factory UserBalances.fromJson(Map<String, dynamic> json) {
    return UserBalances(
      userAreOwed: json['userAreOwed'] as int? ?? 0,
      userOwe: json['userOwe'] as int? ?? 0,
      totalBalance: json['totalBalance'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'USD',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userAreOwed': userAreOwed,
      'userOwe': userOwe,
      'totalBalance': totalBalance,
      'currency': currency,
    };
  }
}

class BalanceNotifier extends AsyncNotifier<UserBalances> {
  @override
  Future<UserBalances> build() async {
    final dio = ref.read(dioProvider);
    
    try {
      final response = await dio.get('/api/user/balances');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final balances = UserBalances.fromJson(response.data['data'] as Map<String, dynamic>);
        
        // Cache to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_balances', jsonEncode(balances.toJson()));
        
        return balances;
      } else {
        throw Exception(response.data['error'] ?? 'Failed to load balances');
      }
    } catch (e) {
      // Attempt offline fallback
      final prefs = await SharedPreferences.getInstance();
      final cachedBytes = prefs.getString('cached_balances');
      if (cachedBytes != null) {
        return UserBalances.fromJson(jsonDecode(cachedBytes) as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final balanceNotifierProvider =
    AsyncNotifierProvider<BalanceNotifier, UserBalances>(BalanceNotifier.new);
