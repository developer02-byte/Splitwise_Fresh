import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'dart:developer';

// Assume BalanceNotifier exists from Phase 3
import '../../dashboard/presentation/providers/balance_provider.dart';

part 'settlement_provider.g.dart';

@riverpod
class SettlementNotifier extends _$SettlementNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  /// Implements Optimistic UI pattern for instantaneous user feedback
  Future<bool> settleUp({
    required int payeeId,
    required int amountCents,
  }) async {
    state = const AsyncLoading();

    // 1. Snapshot the current balance state before mutation
    final previousBalanceState = ref.read(balanceNotifierProvider).value;
    
    if (previousBalanceState == null) {
      state = AsyncError(Exception("Balance not loaded"), StackTrace.current);
      return false;
    }

    try {
      // 2. Optimistic Rendering: Instantly modify the global Balance provider 
      // without waiting for the network call. This makes the UI feel infinitely fast.
      ref.read(balanceNotifierProvider.notifier).state = AsyncData(
        UserBalances(
          userAreOwed: previousBalanceState.userAreOwed,
          // Subtract exactly what we just paid instantly
          userOwe: previousBalanceState.userOwe - amountCents, 
          totalBalance: previousBalanceState.totalBalance + amountCents,
          currency: previousBalanceState.currency,
        )
      );

      final idempotencyKey = const Uuid().v4();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
      
      // 3. Transmit the settlement exactly
      final response = await dio.post('/api/v1/settlements', data: {
        'payeeId': payeeId,
        'amountCents': amountCents,
        'currency': 'USD',
        'idempotencyKey': idempotencyKey,
      });

      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception("Server rejected settlement");
      }

      state = const AsyncData(null);
      return true;

    } catch (e, st) {
      log('Settlement Failed - Rolling back Optimistic UI', name: 'SettlementProvider', error: e);
      
      // 4. Rollback: If anything failed (500 Server, Network Drop), 
      // instantly revert the UI math to the snapshot.
      ref.read(balanceNotifierProvider.notifier).state = AsyncData(previousBalanceState);
      
      state = AsyncError(e, st);
      return false;
    }
  }
}
