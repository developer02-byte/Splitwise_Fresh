import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../dashboard/presentation/providers/balance_provider.dart';
import '../../../../core/network/dio_provider.dart';

class SettleAllScreen extends ConsumerStatefulWidget {
  const SettleAllScreen({super.key});

  @override
  ConsumerState<SettleAllScreen> createState() => _SettleAllScreenState();
}

class _SettleAllScreenState extends ConsumerState<SettleAllScreen> {
  bool _isLoading = false;

  Future<void> _settleAll() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/api/settlements/settle-all');
      if (res.data['success'] == true) {
        ref.invalidate(balanceNotifierProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All debts settled successfully!')));
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to settle: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceState = ref.watch(balanceNotifierProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Settle All Debts')),
      body: balanceState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
        data: (balance) {
          if (balance.userOwe <= 0) {
            return const Center(child: Text('You don\'t owe anything! Great job.'));
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_rounded, size: 80, color: AppColors.success),
                const SizedBox(height: 24),
                Text(
                  'Are you sure you want to settle all your debts?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'This will record a full payment for all your outstanding balances (Total: \$${(balance.userOwe / 100).toStringAsFixed(2)}) across all your friends.',
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _settleAll,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('YES, SETTLE EVERYTHING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('NOT NOW', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
