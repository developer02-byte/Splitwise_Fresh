import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/search_provider.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(globalSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search groups, friends, expenses...', border: InputBorder.none),
          onChanged: (val) => setState(() => _query = val),
        ),
        actions: [
          if (_query.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _query = ''; _searchController.clear(); }))
        ],
      ),
      body: _query.isEmpty 
          ? const Center(child: Text('Type at least 2 characters to search...'))
          : searchAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Center(child: Text('Error searching: $e')),
              data: (results) {
                final groups = results['groups']!;
                final friends = results['friends']!;
                final expenses = results['expenses']!;

                if (groups.isEmpty && friends.isEmpty && expenses.isEmpty) {
                  return const Center(child: Text('No matches found.'));
                }

                return ListView(
                  children: [
                    if (groups.isNotEmpty) ...[
                      const _SectionHeader(title: 'Groups'),
                      ...groups.map((g) => ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.group)),
                        title: Text(g['name']),
                        subtitle: Text(g['type']),
                        onTap: () => context.push('/groups/${g['id']}'),
                      )),
                    ],
                    if (friends.isNotEmpty) ...[
                      const _SectionHeader(title: 'Friends'),
                      ...friends.map((f) => ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(f['name']),
                        subtitle: Text(f['email']),
                        onTap: () => context.push('/friends/${f['id']}'),
                      )),
                    ],
                    if (expenses.isNotEmpty) ...[
                      const _SectionHeader(title: 'Expenses'),
                      ...expenses.map((e) => ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.receipt)),
                        title: Text(e['title']),
                        subtitle: Text('\$${(e['totalAmount'] / 100).toStringAsFixed(2)}'),
                        onTap: () => context.push('/expenses/${e['id']}'),
                      )),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.withValues(alpha: 0.1),
      child: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
    );
  }
}
