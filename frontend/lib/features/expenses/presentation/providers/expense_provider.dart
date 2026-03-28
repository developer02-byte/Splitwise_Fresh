import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/sqlite_queue.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../dashboard/presentation/providers/balance_provider.dart';
import '../../../activity/presentation/providers/activity_provider.dart';

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
    required int groupId,
    required int paidBy,
    required List<Map<String, dynamic>> splits,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final idempotencyKey = const Uuid().v4();
      final payload = {
        'title': title,
        'totalAmount': totalCents,
        'groupId': groupId,
        'paidBy': paidBy,
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
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/expenses', data: payload);
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(response.data['error'] ?? 'Failed to add expense');
      }
      
      // Mute errors if we can't invalidate but usually this is fine
      ref.invalidate(balanceNotifierProvider);
      ref.invalidate(activityNotifierProvider);
    });
  }
}
