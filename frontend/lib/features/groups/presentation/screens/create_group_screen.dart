import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/dimensions.dart';
import '../providers/group_provider.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  String _selectedType = 'other';
  
  // Mock friends just like in expenses
  final List<Map<String, dynamic>> _mockFriends = [
    {'id': 2, 'name': 'Bob Smith'},
    {'id': 3, 'name': 'Charlie Brown'},
    {'id': 4, 'name': 'Diana Prince'},
  ];
  
  final Set<int> _selectedMembers = {};

  final List<String> _groupTypes = ['trip', 'home', 'couple', 'other'];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group name is required')));
      return;
    }
    
    // Add explicitly selected members. (The backend auto-adds the creator as owner)
    final membersConfig = _selectedMembers.toList();

    ref.read(groupsNotifierProvider.notifier).createGroup(
      _nameController.text.trim(),
      _selectedType,
      membersConfig,
    ).then((_) {
      if (mounted && !ref.read(groupsNotifierProvider).hasError) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group created successfully!')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(groupsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create a Group')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(kSpacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group Name
                    Row(
                      children: [
                        Container(
                           padding: const EdgeInsets.all(kSpacingS),
                           decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(kRadiusM)),
                           child: const Icon(Icons.group_add, size: 36),
                        ),
                        const SizedBox(width: kSpacingM),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            style: Theme.of(context).textTheme.headlineSmall,
                            decoration: const InputDecoration(hintText: 'Group name', border: InputBorder.none),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: kSpacingM),

                    // Group Type
                    Text('GROUP TYPE', style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedType,
                          items: _groupTypes.map((t) => DropdownMenuItem<String>(
                            value: t, child: Text(t.toUpperCase())
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedType = val);
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Add Members
                    Text('ADD MEMBERS', style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Column(
                      children: _mockFriends.map((friend) {
                        final id = friend['id'] as int;
                        final isSelected = _selectedMembers.contains(id);
                        return CheckboxListTile(
                          title: Text(friend['name'] as String),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedMembers.add(id);
                              } else {
                                _selectedMembers.remove(id);
                              }
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom Save Bar
            Container(
              padding: const EdgeInsets.all(kSpacingL),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (groupsState.hasError) 
                     Padding(
                       padding: const EdgeInsets.only(bottom: 8.0),
                       child: Text(groupsState.error.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                     ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: groupsState.isLoading ? null : _submit,
                      child: groupsState.isLoading 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
