import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class ExpenseActionState {
  final bool isLoading;
  final String? error;
  
  const ExpenseActionState({this.isLoading = false, this.error});
  
  ExpenseActionState copyWith({bool? isLoading, String? error}) {
    return ExpenseActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class ExpenseActionNotifier extends AsyncNotifier<ExpenseActionState> {
  @override
  Future<ExpenseActionState> build() async {
    return const ExpenseActionState();
  }

  Future<bool> deleteExpense(int expenseId, {required VoidCallback onSuccess}) async {
    state = const AsyncLoading();
    
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.delete('/api/expenses/$expenseId');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        state = const AsyncData(ExpenseActionState());
        onSuccess();
        return true;
      } else {
        throw Exception(response.data['error'] ?? 'Failed to delete expense');
      }
    } catch (e) {
      state = AsyncData(ExpenseActionState(error: e.toString()));
      return false;
    }
  }

  Future<bool> editExpense(
      int expenseId, String newTitle, int newAmountCents, {required VoidCallback onSuccess}) async {
    state = const AsyncLoading();
    
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.put('/api/expenses/$expenseId', data: {
        'title': newTitle,
        'totalAmount': newAmountCents,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        state = const AsyncData(ExpenseActionState());
        onSuccess();
        return true;
      } else {
        throw Exception(response.data['error'] ?? 'Failed to edit expense');
      }
    } catch (e) {
      state = AsyncData(ExpenseActionState(error: e.toString()));
      return false;
    }
  }
}

final expenseActionNotifierProvider = 
    AsyncNotifierProvider<ExpenseActionNotifier, ExpenseActionState>(ExpenseActionNotifier.new);

typedef VoidCallback = void Function();
