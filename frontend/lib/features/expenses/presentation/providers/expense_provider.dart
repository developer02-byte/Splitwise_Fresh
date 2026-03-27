import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/sqlite_queue.dart';
// Note: Requires connectivity_plus provider in a real build
// import '../../../core/network/connectivity_provider.dart';

part 'expense_provider.g.dart';

@riverpod
class ExpenseNotifier extends _$ExpenseNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<void> submitExpense({
    required String title,
    required int totalCents,
    required List<Map<String, dynamic>> splits,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final idempotencyKey = const Uuid().v4();
      final payload = {
        'title': title,
        'totalAmount': totalCents,
        'groupId': 1, // simulated group
        'paidBy': 1,  // simulated user
        'originalCurrency': 'USD',
        'splits': splits,
        'idempotencyKey': idempotencyKey,
      };

      // 1. Simulate Connectivity Check
      bool isOnline = true; // In reality: ref.read(connectivityProvider)

      if (!isOnline) {
        // Enqueue to SQLite explicitly
        await SQLiteQueueHelper.enqueueAction('POST_/api/v1/expenses', payload, idempotencyKey);
        // Refresh local Riverpod lists via Cache so UI reflects success (Optimistic offline)
        return;
      }

      // 2. Transmit immediately if online
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
      await dio.post('/api/v1/expenses', data: payload);
      
      // TODO: refresh Dashboard Balances Provider globally
    });
  }
}
