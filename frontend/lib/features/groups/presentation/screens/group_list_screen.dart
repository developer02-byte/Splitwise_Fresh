import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/group_provider.dart';
import '../widgets/invite_share_sheet.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsState = ref.watch(groupsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // Let ScaffoldWithNavBar background show if any
      appBar: AppBar(
        title: Text('Your Groups', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create Group Modal...')));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: groupsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text(err.toString())),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(kSpacingL),
                child: Container(
                  padding: const EdgeInsets.all(kSpacingXL),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 12))
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.group_add_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: kSpacingL),
                      Text(
                        'Getting Started',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: kSpacingS),
                      Text(
                        'Create a group to split expenses with friends, roommates, or travel buddies.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: kSpacingXL),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: const Text('Create New Group', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: kSpacingL, vertical: kSpacingM),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                  boxShadow: [
                    if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(kSpacingM),
                      child: Row(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.group_rounded, color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (group.netBalanceCents != 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    group.netBalanceCents > 0
                                        ? 'Settle up: You are owed \$${(group.netBalanceCents / 100).toStringAsFixed(2)}'
                                        : 'Settle up: You owe \$${(group.netBalanceCents.abs() / 100).toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: group.netBalanceCents > 0 ? AppColors.success : AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Settled up',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.share_rounded, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            onPressed: () {
                              InviteShareSheet.show(
                                context, 
                                groupName: group.name, 
                                token: group.inviteToken ?? 'no-token-available'
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
