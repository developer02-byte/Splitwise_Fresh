import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../dashboard/presentation/providers/balance_provider.dart';
import '../../../activity/presentation/providers/activity_provider.dart';

class SettlementNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    return;
  }

  Future<void> submitSettlement({
    required int payeeId,
    required int amountCents,
    String currency = 'USD',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final idempotencyKey = const Uuid().v4();

      final response = await dio.post('/api/settlements', data: {
        'payeeId': payeeId,
        'amountCents': amountCents,
        'currency': currency,
        'groupId': 1, // Optional mock group
        'idempotencyKey': idempotencyKey,
      });

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(response.data['error'] ?? 'Settlement failed');
      }

      // Optimistic update mechanism
      ref.invalidate(balanceNotifierProvider);
      ref.invalidate(activityNotifierProvider);
    });
  }

  Future<void> settleAll() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/settlements/settle-all');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(response.data['error'] ?? 'Settle all failed');
      }

      ref.invalidate(balanceNotifierProvider);
      ref.invalidate(activityNotifierProvider);
    });
  }
}

final settlementNotifierProvider =
    AsyncNotifierProvider<SettlementNotifier, void>(SettlementNotifier.new);
