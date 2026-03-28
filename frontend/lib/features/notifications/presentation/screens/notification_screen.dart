import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/notification_provider.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationNotifierProvider.notifier).markAllAsRead(),
            child: const Text('Mark all as read'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showPreferencesDialog(context, ref),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err.toString())),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.', style: TextStyle(color: Colors.grey, fontSize: 16)));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(notificationNotifierProvider),
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: kSpacingL, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: n.read ? Colors.grey.withOpacity(0.2) : AppColors.primary500.withOpacity(0.2),
                    child: Icon(
                      n.type.contains('settlement') ? Icons.payment : Icons.receipt_long,
                      color: n.read ? Colors.grey : AppColors.primary500,
                    ),
                  ),
                  title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(n.body),
                  onTap: () {
                    if (!n.read) ref.read(notificationNotifierProvider.notifier).markAsRead(n.id);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showPreferencesDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notification Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Note: Real preferences storage is deferred to Story 35.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            SwitchListTile(
              title: const Text('Push Notifications'),
              value: true,
              onChanged: (val) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences updated locally')));
              },
            ),
            SwitchListTile(
              title: const Text('Email Digest'),
              value: true,
              onChanged: (val) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences updated locally')));
              },
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }
}
