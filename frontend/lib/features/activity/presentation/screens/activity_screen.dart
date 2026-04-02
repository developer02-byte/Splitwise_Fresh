import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/activity_provider.dart';
import '../../../expenses/presentation/providers/expense_action_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import '../../../../core/network/dio_provider.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  ActivityFilter _activeFilter = ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final activityState = ref.watch(activityNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Activity', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Data',
            onPressed: () => _showExportModal(context, ref),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.filter_list_rounded, color: Theme.of(context).colorScheme.primary),
            ),
            onPressed: () {
              // Stub Date Range filter requirement
              showModalBottomSheet(context: context, builder: (ctx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       Text('Filter by Date Range', style: Theme.of(context).textTheme.titleLarge),
                       const SizedBox(height: 16),
                       ListTile(title: const Text('Last 7 Days'), onTap: () => Navigator.pop(ctx)),
                       ListTile(title: const Text('Last 30 Days'), onTap: () => Navigator.pop(ctx)),
                       ListTile(title: const Text('This Year'), onTap: () => Navigator.pop(ctx)),
                       ListTile(title: const Text('Custom Range...'), onTap: () async {
                         Navigator.pop(ctx);
                         await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
                       }),
                    ]
                  )
                )
              ));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filter Chip Row ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpacingL, vertical: kSpacingS),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: ActivityFilter.values.map((filter) {
                  final labels = {
                    ActivityFilter.all: 'All',
                    ActivityFilter.groups: 'Groups',
                    ActivityFilter.friends: 'Friends',
                    ActivityFilter.lent: 'Lent',
                    ActivityFilter.borrowed: 'Borrowed',
                    ActivityFilter.expenses: 'Expenses',
                    ActivityFilter.settlements: 'Settlements',
                  };
                  final isSelected = _activeFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: kSpacingS),
                    child: FilterChip(
                      label: Text(labels[filter]!, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _activeFilter = filter);
                        ref.read(activityNotifierProvider.notifier).applyFilter(filter);
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(color: isSelected ? Colors.transparent : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1))),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(color: isSelected ? Theme.of(context).colorScheme.primary : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // ── Feed ─────────────────────────────────────────
          Expanded(
            child: activityState.when(
              loading: () => _buildSkeleton(context),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: kSpacingM),
                    Text('Failed to load activity', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: kSpacingM),
                    ElevatedButton.icon(
                      onPressed: () => ref.read(activityNotifierProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              data: (state) {
                if (state.items.isEmpty) return _buildEmptyState(context);
                return RefreshIndicator(
                  onRefresh: () => ref.read(activityNotifierProvider.notifier).refresh(),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (scrollInfo) {
                      if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200 &&
                          !activityState.isLoading && !activityState.isRefreshing) {
                        ref.read(activityNotifierProvider.notifier).fetchMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: kSpacingL, vertical: kSpacingM),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: state.items.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.items.length) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ));
                        }
                        final item = state.items[index];
                        return _ActivityFeedItem(item: item);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1E293B) : Colors.grey[200]!;
    final highlight = isDark ? const Color(0xFF334155) : Colors.white;

    return ListView.builder(
      padding: const EdgeInsets.all(kSpacingL),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(height: 16, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 8),
                  Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(height: 12, width: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)))),
                ],
              ),
            ),
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
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
            boxShadow: [
              if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 12))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: kSpacingL),
              Text(
                'No Activity Yet',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: kSpacingS),
              Text(
                'Your recent transactions and settlements will appear here. Add an expense to get started.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Data Export Modal
  void _showExportModal(BuildContext context, WidgetRef ref) {
    String format = 'csv';
    String range = 'all';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Export Data', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              Text('Format', style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                   ButtonSegment(value: 'csv', label: Text('CSV')),
                   ButtonSegment(value: 'json', label: Text('JSON')),
                ],
                selected: {format},
                onSelectionChanged: (set) => setState(() => format = set.first),
              ),
              const SizedBox(height: 24),

              Text('Time Range', style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: range,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                  DropdownMenuItem(value: 'month', child: Text('This Month')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => range = val);
                },
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  _performExport(context, ref, format, range);
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performExport(BuildContext context, WidgetRef ref, String format, String range) async {
    final dio = ref.read(dioProvider);
    try {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generating $format...'), duration: const Duration(seconds: 1)));

      String url = '/api/export/user?format=$format';
      if (range == 'month') {
        final now = DateTime.now();
        final firstDay = DateTime(now.year, now.month, 1);
        url += '&from=${firstDay.toIso8601String()}&to=${now.toIso8601String()}';
      }

      final res = await dio.get(url);
      if (res.statusCode == 200) {
        final dataStr = format == 'csv' ? res.data as String : res.data.toString();
        final bytes = Uint8List.fromList(dataStr.codeUnits);
        
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export downloaded successfully! Opening share sheet...'), backgroundColor: AppColors.success));
           await Share.shareXFiles([
             XFile.fromData(bytes, name: 'SplitEase_Export.$format', mimeType: format == 'csv' ? 'text/csv' : 'application/json')
           ], text: 'My SplitEase Export');
        }
      } else {
        throw Exception('Failed from server');
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export failed: \$e'), backgroundColor: AppColors.error));
    }
  }
}

// ── Individual Feed Item Widget ───────────────────────────────
class _ActivityFeedItem extends ConsumerWidget {
  final ActivityItem item;
  const _ActivityFeedItem({required this.item});

  void _showActionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.primary),
              ),
              title: const Text('Edit Expense', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/expenses/${item.id}/edit');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_rounded, color: AppColors.error),
              ),
              title: const Text('Delete Expense', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('Are you sure you want to delete this expense? This action cannot be undone and balances will be reversed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _executeDelete(context, ref);
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _executeDelete(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleting...'), duration: Duration(milliseconds: 600)),
    );
    
    final success = await ref.read(expenseActionNotifierProvider.notifier).deleteExpense(
      item.id,
      onSuccess: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: AppColors.success, content: Text('✓ Expense deleted!')),
          );
        }
        ref.invalidate(activityNotifierProvider);
      },
    );

    if (!success && context.mounted) {
      final error = ref.read(expenseActionNotifierProvider).value?.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(error ?? 'Failed to delete')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSettlement = item.type == ActivityType.settlement;
    final isCredit = isSettlement ? !item.youPaid : item.youPaid;

    final iconColor = isSettlement ? AppColors.success : (isCredit ? AppColors.success : AppColors.error);
    final iconData = isSettlement
        ? (item.youPaid ? Icons.send_rounded : Icons.call_received_rounded)
        : Icons.receipt_long_rounded;

    final amountDisplay = '\$${(item.amountCents / 100).toStringAsFixed(2)}';
    final yourShareDisplay = item.yourShareCents > 0 ? '\$${(item.yourShareCents / 100).toStringAsFixed(2)}' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onLongPress: isSettlement ? null : () => _showActionSheet(context, ref),
          onTap: () {
            if (!isSettlement) context.push('/expenses/${item.id}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [iconColor.withValues(alpha: 0.2), iconColor.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: iconColor.withValues(alpha: 0.1)),
                  ),
                  child: Icon(iconData, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                             _timeAgo(item.createdAt),
                             style: Theme.of(context).textTheme.bodySmall?.copyWith(
                               color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                               fontWeight: FontWeight.w500,
                             ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.circle, size: 3, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            item.type == ActivityType.settlement ? 'Settlement' : 'Expense',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white54 : Colors.black45,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      if (yourShareDisplay != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (item.youPaid ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.youPaid ? 'You lent $yourShareDisplay' : 'You borrowed $yourShareDisplay',
                            style: TextStyle(
                              color: item.youPaid ? AppColors.success : AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      amountDisplay,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.5,
                        color: isCredit ? AppColors.success : AppColors.error,
                      ),
                    ),
                    Text(
                      item.currency,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

