import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/group_provider.dart';
import 'package:go_router/go_router.dart';
import 'group_insights_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';

final groupLedgerProvider = FutureProvider.family<List<dynamic>, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/api/v1/groups/$id/ledger');
  if (res.statusCode == 200 && res.data['success'] == true) {
    return res.data['data'] as List<dynamic>;
  }
  return [];
});

class GroupDetailScreen extends ConsumerWidget {
  final int groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsState = ref.watch(groupsNotifierProvider);
    final group = groupsState.valueOrNull?.firstWhere((g) => g.id == groupId, orElse: () => GroupModel(id: 0, name: '...', type: 'other'));
    final ledgerAsync = ref.watch(groupLedgerProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? 'Loading...'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'View Insights',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => GroupInsightsScreen(groupId: groupId, groupName: group?.name ?? 'Group'))
            ),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: () => _exportToCsv(context, ref, groupId),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/groups/$groupId/settings'),
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _GroupHeroSummary(group: group)),
          SliverToBoxAdapter(
             child: Padding(
               padding: const EdgeInsets.all(kSpacingL),
               child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Group Ledger', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Simplify Debts'),
                      onPressed: () => _simplifyDebts(context, ref, groupId),
                    ),
                  ],
               ),
             ),
          ),
          ledgerAsync.when(
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, st) => SliverToBoxAdapter(child: Center(child: Text(e.toString()))),
            data: (ledger) {
              if (ledger.isEmpty) {
                 return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(kSpacingXL), child: Center(child: Text('No expenses yet.'))));
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = ledger[index];
                    final title = item['title'] as String? ?? 'Expense';
                    final payer = item['payer']?['name'] as String? ?? 'Someone';
                    final amount = item['totalAmount'] as int? ?? 0;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$payer paid \$${(amount/100).toStringAsFixed(2)}'),
                    );
                  },
                  childCount: ledger.length,
                ),
              );
            }
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-expense'),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  void _exportToCsv(BuildContext context, WidgetRef ref, int groupId) async {
    final dio = ref.read(dioProvider);
    try {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating CSV...'), duration: Duration(seconds: 1)));
      final res = await dio.get('/api/groups/$groupId/export');
      if (res.statusCode == 200) {
        final dataStr = res.data as String;
        final bytes = Uint8List.fromList(dataStr.codeUnits);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('✓ Export downloaded successfully! Opening share sheet...'),
          ));
          await Share.shareXFiles([XFile.fromData(bytes, name: 'Group_\${groupId}_Export.csv', mimeType: 'text/csv')], text: 'Group \$groupId Export');
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to export CSV')));
    }
  }

  void _simplifyDebts(BuildContext context, WidgetRef ref, int groupId) async {
    final dio = ref.read(dioProvider);
    try {
      final res = await dio.get('/api/v1/groups/$groupId/simplify');
      if (res.data['success'] == true && context.mounted) {
        final list = res.data['data'] as List<dynamic>;
        showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
            title: const Text('Simplified Debts (Group-level)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: list.isEmpty 
                  ? [const Text('No optimized transfers needed.')]
                  : list.map((d) {
                    final from = d['fromUserId'];
                    final to = d['toUserId'];
                    final amt = d['amountCents'] / 100;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('User $from owes User $to \$${amt.toStringAsFixed(2)}'),
                    );
                  }).toList()
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]
          )
        );
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to simplify debts')));
    }
  }
}

class _GroupHeroSummary extends StatelessWidget {
  final GroupModel? group;
  const _GroupHeroSummary({this.group});

  @override
  Widget build(BuildContext context) {
    if (group == null) return const SizedBox();
    final net = group!.netBalanceCents;
    final isNegative = net < 0;
    
    return Container(
      padding: const EdgeInsets.all(kSpacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05)))
      ),
      child: Column(
        children: [
           Container(
             width: 80, height: 80,
             decoration: BoxDecoration(
               color: AppColors.primary500.withOpacity(0.1),
               shape: BoxShape.circle,
             ),
             child: const Icon(Icons.group_outlined, size: 40, color: AppColors.primary500),
           ),
           const SizedBox(height: 16),
           Text(group!.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
           const SizedBox(height: 8),
           Text(
             net == 0 ? 'Settled up' : (isNegative ? 'You owe \$${(net.abs()/100).toStringAsFixed(2)} overall' : 'You are owed \$${(net/100).toStringAsFixed(2)} overall'),
             style: Theme.of(context).textTheme.titleMedium?.copyWith(
               color: net == 0 ? Colors.grey : (isNegative ? AppColors.error : AppColors.success),
               fontWeight: FontWeight.w700,
             ),
           ),
           const SizedBox(height: 16),
           OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => GroupInsightsScreen(groupId: group!.id, groupName: group!.name))
              ),
              icon: const Icon(Icons.auto_graph),
              label: const Text('Group Insights'),
           ),
        ],
      )
    );
  }
}
