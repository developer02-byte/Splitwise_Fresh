import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/friends_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  void _showAddFriendSheet() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text('Add Friend', style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name', 
                hintText: 'e.g. John Doe',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address', 
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: () {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                ref.read(friendsNotifierProvider.notifier).addFriend(nameCtrl.text, emailCtrl.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: AppColors.success, content: Text('✓ ${nameCtrl.text} added!')),
                );
              },
              child: const Text('Add Friend', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // Let ScaffoldWithNavBar background show
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Friends', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
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
              child: Icon(Icons.person_add_rounded, color: Theme.of(context).colorScheme.primary),
            ),
            onPressed: _showAddFriendSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: friendsState.when(
        loading: () => _buildSkeleton(context),
        error: (err, _) => Center(child: Text(err.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error))),
        data: (friends) {
          if (friends.isEmpty) return _buildEmptyState(context);
          
          return RefreshIndicator(
            onRefresh: () => ref.read(friendsNotifierProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: kSpacingL, vertical: 100), // padding top for appbar
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                
                final isSettled = friend.netBalanceCents == 0;
                final youOweThem = friend.netBalanceCents > 0;
                final absAmount = (friend.netBalanceCents.abs() / 100).toStringAsFixed(2);
                
                final statusText = isSettled 
                    ? 'Settled up' 
                    : (youOweThem ? 'You owe \$$absAmount' : 'Owes you \$$absAmount');
                
                final statusColor = isSettled 
                    ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight) 
                    : (youOweThem ? AppColors.error : AppColors.success);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                    boxShadow: [
                      if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Open 1-on-1 Ledger for ${friend.name}'))
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                friend.name.substring(0, 1).toUpperCase(), 
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary, 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20
                                )
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                friend.name, 
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
                              ),
                            ),
                            Text(
                              statusText, 
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: statusColor, 
                                fontWeight: isSettled ? FontWeight.normal : FontWeight.w700,
                              )
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1E293B) : Colors.grey[200]!;
    final highlight = isDark ? const Color(0xFF334155) : Colors.white;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: kSpacingL, vertical: 100),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
            const SizedBox(width: 16),
            Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(height: 16, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))),
            const Spacer(),
            Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(height: 14, width: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 12))
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
                child: Icon(Icons.person_add_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: kSpacingL),
              Text(
                'Add Friends',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: kSpacingS),
              Text(
                'Keep track of shared expenses with your friends. Add them here to start splitting bills securely.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: kSpacingXL),
              ElevatedButton(
                onPressed: _showAddFriendSheet,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('Add Your First Friend', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
