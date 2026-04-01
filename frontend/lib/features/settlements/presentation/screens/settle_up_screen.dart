import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/settlement_provider.dart';
import '../../friends/presentation/providers/friends_provider.dart';

class SettleUpScreen extends ConsumerStatefulWidget {
  final int? prefilledPayeeId;
  final double? prefilledAmount;

  const SettleUpScreen({
    super.key, 
    this.prefilledPayeeId, 
    this.prefilledAmount
  });

  @override
  ConsumerState<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends ConsumerState<SettleUpScreen> {
  final _amountController = TextEditingController();
  int? _selectedPayeeId;
  double _debtAmount = 0.0;
  String _selectedCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    if (widget.prefilledPayeeId != null) {
      _selectedPayeeId = widget.prefilledPayeeId;
      _debtAmount = widget.prefilledAmount ?? 0.0;
      if (_debtAmount > 0) {
        _amountController.text = _debtAmount.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onPayeeSelected(FriendMock? payee) {
    if (payee == null) return;
    setState(() {
      _selectedPayeeId = payee.id;
      // netBalanceCents < 0 means user owes money.
      _debtAmount = payee.netBalanceCents < 0 ? (-payee.netBalanceCents / 100.0) : 0.0;
      _amountController.text = _debtAmount.toStringAsFixed(2);
    });
  }

  void _submit() {
    if (_selectedPayeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select who to pay.')));
      return;
    }

    final val = double.tryParse(_amountController.text) ?? 0.0;
    if (val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount must be positive.')));
      return;
    }

    if (val > _debtAmount) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Overpayment! You only owe \$${_debtAmount.toStringAsFixed(2)}')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Settlement'),
        content: Text('Are you sure you want to record a payment of \$${val.toStringAsFixed(2)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _processSettlement((val * 100).round());
            }, 
            child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success))
          ),
        ],
      )
    );
  }
  
  void _processSettlement(int cents) {
    ref.read(settlementNotifierProvider.notifier)
      .submitSettlement(payeeId: _selectedPayeeId!, amountCents: cents, currency: _selectedCurrency)
      .then((_) {
         if (mounted && !ref.read(settlementNotifierProvider).hasError) {
           // Also refresh friends list to update balances
           ref.read(friendsNotifierProvider.notifier).refresh();
           context.pop(true);
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settlement recorded!'), backgroundColor: AppColors.success));
         }
      });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settlementNotifierProvider);
    final friendsState = ref.watch(friendsNotifierProvider);
    
    final val = double.tryParse(_amountController.text) ?? 0.0;
    final isOverpayment = val > _debtAmount && _selectedPayeeId != null;

    final allFriends = friendsState.value ?? [];
    // Only show friends we owe money to (netBalance < 0)
    final friendsWeOwe = allFriends.where((f) => f.netBalanceCents < 0).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settle Up'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(settlementNotifierProvider.notifier).settleAll().then((_) {
                 if (mounted && !ref.read(settlementNotifierProvider).hasError) {
                   ref.read(friendsNotifierProvider.notifier).refresh();
                   context.pop(true);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All debts settled!'), backgroundColor: AppColors.success));
                 }
              });
            },
            child: const Text('Settle All', style: TextStyle(color: Colors.white)),
          )
        ]
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(kSpacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    Text('WHO ARE YOU PAYING?', style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2, color: Colors.grey)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          hint: const Text('Select Friend'),
                          value: _selectedPayeeId,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down),
                          items: friendsWeOwe.map((friend) {
                            final oweAmt = (-friend.netBalanceCents) / 100.0;
                            return DropdownMenuItem<int>(
                              value: friend.id,
                              child: Text('${friend.name} (Owe \$${oweAmt.toStringAsFixed(2)})'),
                            );
                          }).toList(),
                          onChanged: (id) {
                            final payee = friendsWeOwe.firstWhere((f) => f.id == id);
                            _onPayeeSelected(payee);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isOverpayment ? AppColors.error : Colors.transparent, width: 2)
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCurrency,
                                  items: ['USD', 'EUR', 'GBP', 'INR', 'JPY'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: Theme.of(context).textTheme.headlineSmall))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedCurrency = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IntrinsicWidth(
                                child: TextField(
                                  controller: _amountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                  style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(border: InputBorder.none, hintText: '0.00'),
                                  onChanged: (_) => setState(() {}),
                                ),
                              )
                            ],
                          ),
                          if (isOverpayment) ...[
                             const SizedBox(height: 8),
                             Text('Overpayment! Max limit is \$${_debtAmount.toStringAsFixed(2)}', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600))
                          ]
                        ]
                      )
                    ),
                  ],
                ),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(kSpacingL),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.hasError) 
                     Padding(
                       padding: const EdgeInsets.only(bottom: 8.0),
                       child: Text(state.error.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                     ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_selectedPayeeId == null || isOverpayment || state.isLoading) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                      child: state.isLoading 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Record Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
