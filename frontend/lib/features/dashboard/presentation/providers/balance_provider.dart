import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

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
}

class BalanceNotifier extends AsyncNotifier<UserBalances> {
  @override
  Future<UserBalances> build() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/user/balances');
    
    if (response.statusCode == 200 && response.data['success'] == true) {
      return UserBalances.fromJson(response.data['data'] as Map<String, dynamic>);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load balances');
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final balanceNotifierProvider =
    AsyncNotifierProvider<BalanceNotifier, UserBalances>(BalanceNotifier.new);
