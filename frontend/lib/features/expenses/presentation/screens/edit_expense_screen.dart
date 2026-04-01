import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/dimensions.dart';
import '../../domain/usecases/split_calculator.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import 'expense_detail_screen.dart';

enum SplitMode { equal, exact, percentage }

class EditExpenseScreen extends ConsumerStatefulWidget {
  final int id;
  const EditExpenseScreen({super.key, required this.id});

  @override
  ConsumerState<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends ConsumerState<EditExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  
  int _selectedPayer = 1;
  CategoryModel? _selectedCategory;
  SplitMode _splitMode = SplitMode.equal;

  final Map<int, TextEditingController> _exactControllers = {};
  final Map<int, TextEditingController> _percentControllers = {};

  bool _initialized = false;
  List<dynamic> _splits = [];
  List<Map<String, dynamic>> _involvedUsers = [];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (var c in _exactControllers.values) { c.dispose(); }
    for (var c in _percentControllers.values) { c.dispose(); }
    super.dispose();
  }

  void _initFromExpense(Map<String, dynamic> expense) {
    if (_initialized) return;
    _titleController.text = expense['title'] ?? '';
    _amountController.text = ((expense['totalAmount'] ?? 0) / 100).toString();
    _selectedPayer = expense['paidBy'];
    _selectedCategory = expense['category'] != null ? CategoryModel.fromJson(expense['category']) : null;
    
    _splits = expense['splits'] ?? [];
    _involvedUsers = _splits.map((s) => s['user'] as Map<String, dynamic>).toList();

    for (var u in _involvedUsers) {
      final uid = u['id'];
      final split = _splits.firstWhere((s) => s['userId'] == uid);
      _exactControllers[uid] = TextEditingController(text: (split['owedAmount'] / 100).toString());
      _percentControllers[uid] = TextEditingController(text: ((split['owedAmount'] / expense['totalAmount']) * 100).toStringAsFixed(1));
    }
    
    _initialized = true;
  }

  void _submitUpdate() {
    final doubleAmt = double.tryParse(_amountController.text) ?? 0.0;
    final totalCents = (doubleAmt * 100).round();
    final ids = _involvedUsers.map((u) => u['id'] as int).toList();
    
    List<Map<String, dynamic>> splitsList = [];

    if (_splitMode == SplitMode.equal) {
      final res = SplitCalculator.calculateEqual(totalCents, ids.length);
      res.fold(
        (err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err))),
        (splits) {
          splitsList = [
            for (int i = 0; i < ids.length; i++)
              {"userId": ids[i], "owedAmount": splits[i]}
          ];
        }
      );
    } else if (_splitMode == SplitMode.exact) {
      final userCents = <int>[];
      for (int id in ids) {
        final val = double.tryParse(_exactControllers[id]!.text) ?? 0.0;
        userCents.add((val * 100).round());
      }
      final res = SplitCalculator.validateExact(totalCents, userCents);
      res.fold(
        (err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err))),
        (splits) {
          splitsList = [
            for (int i = 0; i < ids.length; i++)
              {"userId": ids[i], "owedAmount": splits[i]}
          ];
        }
      );
    }

    if (splitsList.isEmpty) return;

    ref.read(expenseNotifierProvider.notifier).updateExpense(
      id: widget.id,
      title: _titleController.text,
      totalAmount: totalCents,
      paidBy: _selectedPayer,
      categoryId: _selectedCategory?.id,
      splits: splitsList,
    ).then((_) {
      if (mounted && !ref.read(expenseNotifierProvider).hasError) {
        ref.invalidate(expenseDetailProvider(widget.id));
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense updated!')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenseAsync = ref.watch(expenseDetailProvider(widget.id));
    final expenseState = ref.watch(expenseNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit expense')),
      body: expenseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
        data: (expense) {
          _initFromExpense(expense);
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(kSpacingL),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        style: Theme.of(context).textTheme.headlineMedium,
                        decoration: const InputDecoration(hintText: 'Description', border: InputBorder.none),
                      ),
                      const Divider(),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                        decoration: const InputDecoration(hintText: '0.00', border: InputBorder.none, prefixText: '\$'),
                      ),
                      const SizedBox(height: 24),
                      SegmentedButton<SplitMode>(
                        segments: const [
                          ButtonSegment(value: SplitMode.equal, label: Text('Equal')),
                          ButtonSegment(value: SplitMode.exact, label: Text('Exact')),
                        ],
                        selected: {_splitMode},
                        onSelectionChanged: (set) => setState(() => _splitMode = set.first),
                      ),
                      const SizedBox(height: 16),
                      if (_splitMode == SplitMode.exact)
                        ..._involvedUsers.map((u) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(u['name'])),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _exactControllers[u['id']],
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(prefixText: '\$'),
                                ),
                              )
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(kSpacingL),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: expenseState.isLoading ? null : _submitUpdate,
                    child: expenseState.isLoading ? const CircularProgressIndicator() : const Text('Save Changes'),
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
