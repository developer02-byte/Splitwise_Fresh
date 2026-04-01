import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/friends_provider.dart';
import '../../../../core/network/dio_provider.dart';

class FriendDetailScreen extends ConsumerWidget {
  final int friendId;

  const FriendDetailScreen({super.key, required this.friendId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsState = ref.watch(friendsNotifierProvider);
    final allFriends = friendsState.valueOrNull ?? [];
    
    final friend = allFriends.firstWhere(
      (f) => f.id == friendId, 
      orElse: () => FriendModel(id: friendId, name: 'Loading...', email: '', netBalanceCents: 0)
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final netUsd = friend.netBalanceCents / 100.0;
    final owesYou = netUsd > 0;
    final youOwe = netUsd < 0;
    final isSettled = netUsd == 0;

    final heroColor = isSettled 
        ? Colors.grey 
        : (youOwe ? AppColors.error : AppColors.success);

    return Scaffold(
      appBar: AppBar(
        title: Text(friend.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              if (friend.friendshipId == null) return;
              showModalBottomSheet(context: context, builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.delete, color: AppColors.error),
                      title: const Text('Remove Friend', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Only works if all debts are fully settled.'),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!isSettled) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot remove active balance buddy.')));
                          return;
                        }
                        ref.read(friendsNotifierProvider.notifier).removeFriend(friend.friendshipId!).then((_) {
                           context.pop();
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend Removed!')));
                        }).catchError((e) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        });
                      },
                    )
                  ],
                ),
              ));
            },
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              color: heroColor.withValues(alpha: 0.1),
              child: Column(
                children: [
                  CircleAvatar(radius: 40, backgroundColor: heroColor.withValues(alpha: 0.3), child: Text(friend.name.isNotEmpty ? friend.name[0] : '?', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: heroColor))),
                  const SizedBox(height: 16),
                  Text(
                    isSettled ? "You're all settled up" : (youOwe ? 'You owe ${friend.name}' : '${friend.name} owes you'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: heroColor),
                  ),
                  if (!isSettled)
                    Text('\$${netUsd.abs().toStringAsFixed(2)}', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: heroColor)),
                  
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (youOwe)
                         ElevatedButton.icon(
                           onPressed: () => context.push('/settle-up?friendId=${friend.id}&amount=${netUsd.abs()}'),
                           icon: const Icon(Icons.payment), 
                           label: const Text('Settle Up'),
                           style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                         ),
                      if (!isSettled && !youOwe)
                         ElevatedButton.icon(
                           onPressed: () async {
                             final dio = ref.read(dioProvider);
                             try {
                               final res = await dio.post('/api/notifications/remind', data: {'targetUserId': friend.id, 'type': 'balance'});
                               if (res.data['success'] == true) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder sent!')));
                               }
                             } catch (e) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send reminder.')));
                             }
                           }, 
                           icon: const Icon(Icons.notifications_active), 
                           label: const Text('Remind'),
                         ),
                    ],
                  )
                ]
              )
            )
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverToBoxAdapter(
            child: Padding(
               padding: EdgeInsets.symmetric(horizontal: 16),
               child: Text('Shared History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text("Ledger scrolling is deferred to Story 22.")))),
        ],
      )
    );
  }
}
