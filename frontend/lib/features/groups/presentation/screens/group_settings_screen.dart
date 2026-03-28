import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/group_provider.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final int groupId;
  const GroupSettingsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  final _nameController = TextEditingController();
  String? _selectedType;
  bool _simplified = true;
  double _threshold = 0;
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groups = ref.read(groupsNotifierProvider).value ?? [];
      final group = groups.firstWhere((g) => g.id == widget.groupId);
      setState(() {
        _nameController.text = group.name;
        _selectedType = group.type;
        _simplified = group.simplifiedSettlement;
        _threshold = group.settlementThreshold.toDouble();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveSettings,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('General', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary500)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Group Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: ['trip', 'home', 'couple', 'other'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _selectedType = val),
              decoration: const InputDecoration(labelText: 'Group Type', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            Text('Advanced', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary500)),
            SwitchListTile(
              title: const Text('Simplified Settlements'),
              subtitle: const Text('Automatically reduces the total number of payments between members.'),
              value: _simplified,
              onChanged: (val) => setState(() => _simplified = val),
            ),
            const SizedBox(height: 8),
            Text('Settlement Threshold (\$${(_threshold / 100).toStringAsFixed(2)})', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text('Minimum amount to bother settling (in cents).', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Slider(
              value: _threshold,
              min: 0,
              max: 5000,
              divisions: 50,
              label: '${(_threshold / 100).toStringAsFixed(2)}',
              onChanged: (val) => setState(() => _threshold = val),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Members', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary500)),
                IconButton(icon: const Icon(Icons.person_add_alt_outlined), onPressed: _showAddMemberDialog),
              ],
            ),
            const SizedBox(height: 16),
            membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading members: $err'),
              data: (members) {
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final m = members[index];
                    final user = m['user'];
                    final role = m['role'];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text(user['name'][0])),
                      title: Text(user['name']),
                      subtitle: Text(role.toString().toUpperCase()),
                      trailing: role == 'owner' ? null : IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () => _showMemberActions(context, user['id'], role),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 64),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _confirmDeleteGroup,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                child: const Text('Delete Group'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveSettings() async {
    try {
      await ref.read(groupsNotifierProvider.notifier).updateGroupSettings(widget.groupId, {
        'name': _nameController.text,
        'type': _selectedType,
        'simplifiedSettlement': _simplified,
        'settlementThreshold': _threshold.toInt(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'User Email', hintText: 'example@email.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(groupsNotifierProvider.notifier).addMember(widget.groupId, _emailController.text);
                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showMemberActions(BuildContext context, int userId, String currentRole) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentRole == 'member')
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Promote to Admin'),
              onTap: () {
                ref.read(groupsNotifierProvider.notifier).updateMemberRole(widget.groupId, userId, 'admin');
                Navigator.pop(ctx);
              },
            ),
          if (currentRole == 'admin')
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Demote to Member'),
              onTap: () {
                ref.read(groupsNotifierProvider.notifier).updateMemberRole(widget.groupId, userId, 'member');
                Navigator.pop(ctx);
              },
            ),
          ListTile(
            leading: const Icon(Icons.person_remove, color: AppColors.error),
            title: const Text('Remove from Group', style: TextStyle(color: AppColors.error)),
            onTap: () {
              ref.read(groupsNotifierProvider.notifier).removeMember(widget.groupId, userId);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group?'),
        content: const Text('This action is permanent. All group data will be hidden and balances will remain for individual history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(groupsNotifierProvider.notifier).deleteGroup(widget.groupId);
              if (mounted) {
                Navigator.pop(ctx); // Dialog
                context.go('/groups'); // Back to list
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
