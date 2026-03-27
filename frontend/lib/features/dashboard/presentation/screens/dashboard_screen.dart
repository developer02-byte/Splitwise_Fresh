import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/balance_provider.dart';
import '../../../activity/presentation/providers/activity_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceState = ref.watch(balanceNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return balanceState.when(
      loading: () => const _PremiumDashboardSkeleton(),
      error: (err, st) => SafeArea(child: Center(child: Text(err.toString()))),
      data: (balance) {
        final isPositive = balance.totalBalance >= 0;
        final totalAmountDisplay = '\$${(balance.totalBalance.abs() / 100).toStringAsFixed(2)}';
        
        return Stack(
          children: [
            // Background ambient shapes
            Positioned(
              top: -100, right: -50,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.08 : 0.05)),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
            
            // Main Content
            SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Balance',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${isPositive ? "" : "- "}$totalAmountDisplay',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.0,
                              fontSize: 56,
                              color: isPositive ? AppColors.success : AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPositive && balance.totalBalance != 0 ? 'You are owed' : (balance.totalBalance == 0 ? 'All settled up' : 'You owe in total'),
                              style: TextStyle(
                                color: isPositive ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 48),
                          
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Add Expense'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                  ),
                                  onPressed: () => _showAddExpenseModal(context, ref),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.payments_rounded),
                                  label: const Text('Settle Up'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.success,
                                    side: const BorderSide(color: AppColors.success),
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                  ),
                                  onPressed: () => _showSettleUpModal(context, ref, balance.userOwe),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 56),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Activity',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              TextButton(
                                onPressed: () => context.go('/activity'),
                                child: const Text('See All'),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  
                  // Clean List items for activity
                  Consumer(
                    builder: (context, ref, child) {
                      final activityState = ref.watch(activityNotifierProvider);
                      return activityState.when(
                        loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                        error: (err, st) => SliverToBoxAdapter(child: Center(child: Text('Failed to load activity'))),
                        data: (activity) {
                          final items = activity.items.take(3).toList();
                          if (items.isEmpty) {
                            return const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: Text('No recent activity')),
                              ),
                            );
                          }

                          return SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = items[index];
                                  final isSettle = item.type == ActivityType.settlement;
                                  final isCredit = isSettle ? !item.youPaid : item.youPaid;
                                  final amountDisplay = '\$${(item.amountCents / 100).toStringAsFixed(2)}';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 1),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: Container(
                                        height: 48, width: 48,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surface,
                                          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isSettle ? (item.youPaid ? Icons.send_rounded : Icons.call_received_rounded) : Icons.receipt_long_rounded, 
                                          color: isSettle ? AppColors.success : Theme.of(context).colorScheme.onSurface
                                        ),
                                      ),
                                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                      subtitle: Text(item.currency, style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 13)),
                                      trailing: Text(
                                        isCredit ? '+$amountDisplay' : '-$amountDisplay',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 16,
                                          color: isCredit ? AppColors.success : Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                childCount: items.length,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom spacing
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddExpenseModal(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Premium Add Expense...')));
  }

  void _showSettleUpModal(BuildContext context, WidgetRef ref, int userOwes) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Premium Settle Up...')));
  }
}

class _PremiumDashboardSkeleton extends StatelessWidget {
  const _PremiumDashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1E293B) : Colors.grey[200]!;
    final highlight = isDark ? const Color(0xFF334155) : Colors.white;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(height: 20, width: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 12),
            Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(height: 60, width: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(child: Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(height: 64, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))))),
                const SizedBox(width: 16),
                Expanded(child: Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(height: 64, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
