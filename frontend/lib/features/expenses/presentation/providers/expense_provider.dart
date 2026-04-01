import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/offline/sqlite_queue.dart';
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
    int? categoryId,
    bool? isRecurring,
    String? recurrenceType,
    int? recurrenceDay,
    String? receiptUrl,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final idempotencyKey = const Uuid().v4();
      final payload = {
        'title': title,
        'totalAmount': totalCents,
        'groupId': groupId,
        'paidBy': paidBy,
        'categoryId': categoryId,
        'originalCurrency': 'USD',
        'isRecurring': isRecurring,
        'recurrenceType': recurrenceType,
        'recurrenceDay': recurrenceDay,
        'receiptUrl': receiptUrl,
        'splits': splits,
        'idempotencyKey': idempotencyKey,
      };

      final dio = ref.read(dioProvider);
      try {
        final response = await dio.post('/api/expenses', data: payload);
        if (response.data['success'] != true) {
          throw Exception(response.data['error'] ?? 'Failed to add expense');
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionTimeout || 
            e.type == DioExceptionType.receiveTimeout || 
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.unknown) {
           await SQLiteQueueHelper.enqueueAction('POST_EXPENSE', payload, idempotencyKey);
           return; // Treated as success for UI flow
        }
        rethrow;
      }
      
      ref.invalidate(balanceNotifierProvider);
      ref.invalidate(activityNotifierProvider);
    });
  }

  Future<void> updateExpense({
    required int id,
    required String title,
    required int totalAmount,
    required int paidBy,
    required List<Map<String, dynamic>> splits,
    int? categoryId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final response = await dio.patch('/api/expenses/$id', data: {
        'title': title,
        'totalAmount': totalAmount,
        'paidBy': paidBy,
        'categoryId': categoryId,
        'splits': splits,
      });

      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Failed to update');
      }

      ref.invalidate(balanceNotifierProvider);
      ref.invalidate(activityNotifierProvider);
    });
  }

  Future<void> deleteExpense(int id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final response = await dio.delete('/api/expenses/$id');

      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Failed to delete');
      }

      ref.invalidate(balanceNotifierProvider);
      ref.invalidate(activityNotifierProvider);
    });
  }
}
