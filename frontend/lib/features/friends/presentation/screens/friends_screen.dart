import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/friends_provider.dart';
import '../providers/presence_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [Tab(text: 'My Friends'), Tab(text: 'Pending')],
                labelColor: AppColors.primary500,
                indicatorColor: AppColors.primary500,
              ),
            ],
          ),
        ),
      ),
      body: _searchQuery.isNotEmpty 
          ? _UserSearchResults(query: _searchQuery)
          : TabBarView(
              controller: _tabController,
              children: [
                _FriendsListTab(),
                _PendingRequestsTab(),
              ],
            ),
    );
  }
}

class _FriendsListTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(friendsNotifierProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (friends) {
        if (friends.isEmpty) return const Center(child: Text('No friends yet. Search to add some!'));
        final presence = ref.watch(presenceProvider).valueOrNull ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final f = friends[index];
            final pres = presence.firstWhere((p) => p.userId == f.id, orElse: () => UserPresence(userId: f.id, isOnline: false));

            return ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(child: Text(f.name[0])),
                  if (pres.isOnline)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(f.email),
              trailing: Text(
                f.netBalanceCents == 0 ? 'Settled' : '${f.netBalanceCents > 0 ? '+' : '-'}\$${(f.netBalanceCents.abs()/100).toStringAsFixed(2)}',
                style: TextStyle(color: f.netBalanceCents == 0 ? Colors.grey : (f.netBalanceCents > 0 ? Colors.green : Colors.red), fontWeight: FontWeight.bold),
              ),
              onTap: () => context.push('/friends/${f.id}'),
            );
          },
        );
      },
    );
  }
}

class _PendingRequestsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pendingRequestsProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (pending) {
        if (pending.isEmpty) return const Center(child: Text('No pending requests.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pending.length,
          itemBuilder: (context, index) {
            final p = pending[index];
            final isIncoming = p['type'] == 'incoming';
            final user = p['user'];
            return ListTile(
              leading: CircleAvatar(child: Icon(isIncoming ? Icons.person_add : Icons.hourglass_top, size: 20)),
              title: Text(user['name']),
              subtitle: Text(isIncoming ? 'Invited you' : 'Waiting for response'),
              trailing: isIncoming ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => ref.read(friendsNotifierProvider.notifier).handleFriendRequest(p['id'], 'accepted')),
                  IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => ref.read(friendsNotifierProvider.notifier).handleFriendRequest(p['id'], 'rejected')),
                ],
              ) : null,
            );
          },
        );
      },
    );
  }
}

class _UserSearchResults extends ConsumerWidget {
  final String query;
  const _UserSearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userSearchProvider(query));
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (users) {
        if (users.isEmpty) return const Center(child: Text('No users found.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final u = users[index];
            final status = u['friendshipStatus'];
            return ListTile(
              leading: CircleAvatar(child: Text(u['name'][0])),
              title: Text(u['name']),
              subtitle: Text(u['email']),
              trailing: _buildAction(context, ref, u['id'], status),
            );
          },
        );
      },
    );
  }

  Widget? _buildAction(BuildContext context, WidgetRef ref, int userId, String status) {
    if (status == 'accepted') return const Icon(Icons.check_circle, color: Colors.green);
    if (status == 'pending') return const Text('Pending...', style: TextStyle(color: Colors.orange));
    return ElevatedButton(
      onPressed: () => ref.read(friendsNotifierProvider.notifier).sendFriendRequest(userId: userId),
      style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
      child: const Text('Add'),
    );
  }
}
