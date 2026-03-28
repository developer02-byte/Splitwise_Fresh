import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class BudgetModel {
  final int monthlyBudget;
  final int spentThisMonth;
  final String currency;
  final List<Map<String, dynamic>> categoryBreakdown;

  BudgetModel({
    required this.monthlyBudget,
    required this.spentThisMonth,
    required this.currency,
    required this.categoryBreakdown,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      monthlyBudget: json['monthlyBudget'],
      spentThisMonth: json['spentThisMonth'],
      currency: json['currency'],
      categoryBreakdown: List<Map<String, dynamic>>.from(json['categoryBreakdown']),
    );
  }

  double get percentUsed => (spentThisMonth / monthlyBudget).clamp(0.0, 1.0);
}

class BudgetNotifier extends AsyncNotifier<BudgetModel> {
  @override
  Future<BudgetModel> build() async {
    return _fetchBudget();
  }

  Future<BudgetModel> _fetchBudget() async {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/api/user/budget');
    if (res.data['success'] == true) {
      return BudgetModel.fromJson(res.data['data']);
    }
    throw Exception('Failed to load budget');
  }
}

final budgetProvider = AsyncNotifierProvider<BudgetNotifier, BudgetModel>(BudgetNotifier.new);
