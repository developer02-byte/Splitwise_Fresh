import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/dimensions.dart';
import '../providers/settlement_provider.dart';

/// Pops up when the user taps "Settle Up".
class SettleUpModal extends ConsumerStatefulWidget {
  final int payeeId;
  final String payeeName;
  final int owedAmountCents;

  const SettleUpModal({
    super.key,
    required this.payeeId,
    required this.payeeName,
    required this.owedAmountCents,
  });

  @override
  ConsumerState<SettleUpModal> createState() => _SettleUpModalState();
}

class _SettleUpModalState extends ConsumerState<SettleUpModal> {
  void _confirmSettlement() async {
    // Fire Optimistic UI Request
    await ref.read(settlementNotifierProvider.notifier).submitSettlement(
      payeeId: widget.payeeId,
      amountCents: widget.owedAmountCents,
    );
    final success = !ref.read(settlementNotifierProvider).hasError;

    if (mounted) {
      // Exit modal regardless of success (Optimistic UI lets users keep moving)
      context.pop();
      
      if (!success) {
        // Enforce the Error_Contract.md Global Error Toast formatting
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: kSpacingS),
                Expanded(
                  child: Text(
                    "Payment failed. Your balance has been restored.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Formatted currency
    final displayAmount = '\$${(widget.owedAmountCents / 100).toStringAsFixed(2)}';

    return Container(
      padding: EdgeInsets.only(
        left: kSpacingL,
        right: kSpacingL,
        top: kSpacingL,
        bottom: MediaQuery.of(context).viewInsets.bottom + kSpacingL,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadiusXL)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: kSpacingL),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Settle up with ${widget.payeeName}',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: kSpacingL),
          Container(
            padding: const EdgeInsets.all(kSpacingL),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(kRadiusM),
            ),
            child: Column(
              children: [
                Text("You are paying", style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: kSpacingXS),
                Text(
                  displayAmount,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kSpacingXL),
          ElevatedButton(
            onPressed: ref.watch(settlementNotifierProvider).isLoading ? null : _confirmSettlement,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: kSpacingM),
            ),
            child: ref.watch(settlementNotifierProvider).isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Confirm Payment', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: kSpacingS),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
