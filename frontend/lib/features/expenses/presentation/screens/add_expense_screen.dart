import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/dimensions.dart';
import '../../domain/usecases/split_calculator.dart';
import '../providers/expense_provider.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController(); // E.g., "15.99"
  
  // Simulated participating users
  final List<int> _participants = [1, 2, 3]; 

  void _submitExpense() {
    if (_titleController.text.isEmpty || _amountController.text.isEmpty) return;

    // Convert string "15.99" to cents math
    final doubleAmt = double.tryParse(_amountController.text) ?? 0.0;
    final totalCents = (doubleAmt * 100).round();

    // Calculate Equal Splits dynamically in Dart based on input!
    final splitsResult = SplitCalculator.calculateEqual(totalCents, _participants.length);

    splitsResult.fold(
      (error) {
        // Show validation error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      },
      (splitAmounts) {
        // Build API format mapping users to their specific cent allocations
        final splitsList = [
          for (int i = 0; i < _participants.length; i++)
            {
              "userId": _participants[i],
              "owedAmount": splitAmounts[i]
            }
        ];

        // Trigger the provider to hit the Backend or Offline SQLite
        ref.read(expenseNotifierProvider.notifier).submitExpense(
          title: _titleController.text,
          totalCents: totalCents,
          splits: splitsList,
        );

        // Close Modal
        context.pop();
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseState = ref.watch(expenseNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add an expense')),
      body: Padding(
        padding: const EdgeInsets.all(kSpacingL),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                   padding: const EdgeInsets.all(kSpacingS),
                   decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(kRadiusM)),
                   child: const Icon(Icons.receipt_long, size: 36),
                ),
                const SizedBox(width: kSpacingM),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: Theme.of(context).textTheme.headlineMedium,
                    decoration: const InputDecoration(hintText: 'Enter a description', border: InputBorder.none),
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Text('\$', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(width: kSpacingS),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                    decoration: const InputDecoration(hintText: '0.00', border: InputBorder.none),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (expenseState.hasError) 
               Padding(
                 padding: const EdgeInsets.only(bottom: 8.0),
                 child: Text(expenseState.error.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
               ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: expenseState.isLoading ? null : _submitExpense,
                child: expenseState.isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                  : const Text('Save Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
