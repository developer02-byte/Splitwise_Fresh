import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'edit_expense_screen.dart';
import '../providers/expense_provider.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/comment_provider.dart';

final expenseDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/api/expenses/$id');
  if (res.statusCode == 200 && res.data['success'] == true) {
    return res.data['data'] as Map<String, dynamic>;
  }
  throw Exception('Failed to load expense details');
});

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const ExpenseDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      await ref.read(expenseCommentsProvider(widget.id).notifier).addComment(_commentController.text.trim());
      _commentController.clear();
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateInfo = ref.watch(expenseDetailProvider(widget.id));
    final commentsState = ref.watch(expenseCommentsProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
               context,
               MaterialPageRoute(builder: (ctx) => EditExpenseScreen(id: widget.id))
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: stateInfo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(e.toString())),
        data: (expense) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final splits = expense['splits'] as List<dynamic>? ?? [];
          final payer = expense['payer']?['name'] ?? 'Someone';
          final amount = expense['totalAmount'] as int? ?? 0;
          
          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(kSpacingXL),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark 
                                ? [AppColors.primary500.withValues(alpha: 0.2), AppColors.primary500.withValues(alpha: 0.1)]
                                : [AppColors.primary500.withValues(alpha: 0.1), Colors.white],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          children: [
                             Container(
                               width: 80, height: 80,
                               decoration: BoxDecoration(
                                 color: isDark ? Colors.white10 : Colors.white, 
                                 borderRadius: BorderRadius.circular(24), 
                                 boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 10)]
                               ),
                               child: const Icon(Icons.receipt_long, size: 40, color: AppColors.primary500),
                             ),
                             const SizedBox(height: 16),
                             Text(
                               expense['title'] ?? 'Expense', 
                               style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5)
                             ),
                             const SizedBox(height: 4),
                             Text(
                               '\$${(amount/100).toStringAsFixed(2)}', 
                               style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppColors.primary500, fontWeight: FontWeight.bold)
                             ),
                             const SizedBox(height: 12),
                             Row(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 CircleAvatar(radius: 12, backgroundColor: AppColors.primary500.withValues(alpha: 0.5), child: const Icon(Icons.person, size: 14, color: Colors.white)),
                                 const SizedBox(width: 8),
                                 Text(
                                   'Paid by $payer', 
                                   style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)
                                 ),
                               ],
                             ),
                          ],
                        )
                      )
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: kSpacingL)),
                    SliverToBoxAdapter(
                       child: Padding(
                         padding: const EdgeInsets.symmetric(horizontal: kSpacingL),
                         child: Text('Splits Breakdown', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                       ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: kSpacingS)),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final split = splits[index];
                          final user = split['user'];
                          final spltdAmt = split['owedAmount'] as int? ?? 0;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user?['avatarUrl'] != null ? NetworkImage(user['avatarUrl']) : null,
                              child: user?['avatarUrl'] == null ? Text(user?['name']?[0] ?? 'U') : null,
                            ),
                            title: Text(user?['name'] ?? 'User ${split['userId']}'),
                            trailing: Text('\$${(spltdAmt/100).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          );
                        },
                        childCount: splits.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: Divider(height: 64)),
                    SliverToBoxAdapter(
                       child: Padding(
                         padding: const EdgeInsets.symmetric(horizontal: kSpacingL),
                         child: Row(
                           children: [
                             const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey),
                             const SizedBox(width: 8),
                             Text('Comments', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                           ],
                         ),
                       ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: kSpacingM)),
                    commentsState.when(
                      loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                      error: (e, __) => const SliverToBoxAdapter(child: Center(child: Text('Error loading comments'))),
                      data: (comments) {
                        if (comments.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(kSpacingL),
                              child: Text('No comments yet. Be the first to start the conversation!', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                            ),
                          );
                        }
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final comment = comments[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: kSpacingL, vertical: kSpacingS),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundImage: comment.avatarUrl != null ? NetworkImage(comment.avatarUrl!) : null,
                                      child: comment.avatarUrl == null ? Text(comment.userName?[0] ?? 'U') : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(comment.userName ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${comment.createdAt.hour}:${comment.createdAt.minute.toString().padLeft(2, '0')}', 
                                                style: const TextStyle(color: Colors.grey, fontSize: 12)
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
                                              borderRadius: const BorderRadius.only(
                                                bottomLeft: Radius.circular(12),
                                                bottomRight: Radius.circular(12),
                                                topRight: Radius.circular(12),
                                              ),
                                            ),
                                            child: Text(comment.text ?? ''),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            childCount: comments.length,
                          ),
                        );
                      },
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
              // Bottom Input Area
              Container(
                padding: EdgeInsets.only(
                  left: kSpacingL, 
                  right: kSpacingL, 
                  top: kSpacingM, 
                  bottom: MediaQuery.of(context).padding.bottom + kSpacingM
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onSubmitted: (_) => _postComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSending ? null : _postComment,
                      icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      )
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('This will reverse all associated balances. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
             onPressed: () {
                ref.read(expenseNotifierProvider.notifier).deleteExpense(widget.id).then((_) {
                   Navigator.pop(ctx);
                   context.pop();
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted.')));
                });
             }, 
             child: const Text('Delete', style: TextStyle(color: AppColors.error))
          ),
        ],
      ),
    );
  }
}
