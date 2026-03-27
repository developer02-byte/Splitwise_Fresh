import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  bool _isSidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final int selectedIndex = _calculateSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bodyContent = Column(
      children: [
        // Top Navbar
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SplitEase',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary500,
                      child: Text('D', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        Expanded(child: widget.child),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Fixed Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
              width: _isSidebarCollapsed ? 80 : 250,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(right: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: _isSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                    children: [
                      if (!_isSidebarCollapsed)
                        const Padding(
                          padding: EdgeInsets.only(left: 24.0),
                          child: Icon(Icons.splitscreen_rounded, color: AppColors.primary500, size: 28),
                        ),
                      IconButton(
                        icon: Icon(_isSidebarCollapsed ? Icons.menu : Icons.menu_open),
                        onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _SidebarItem(icon: Icons.dashboard_rounded, label: 'Dashboard', isCollapsed: _isSidebarCollapsed, isSelected: selectedIndex == 0, onTap: () => _onItemTapped(0, context)),
                        _SidebarItem(icon: Icons.people_alt_rounded, label: 'Groups', isCollapsed: _isSidebarCollapsed, isSelected: selectedIndex == 1, onTap: () => _onItemTapped(1, context)),
                        _SidebarItem(icon: Icons.person_rounded, label: 'Friends', isCollapsed: _isSidebarCollapsed, isSelected: selectedIndex == 2, onTap: () => _onItemTapped(2, context)),
                        _SidebarItem(icon: Icons.receipt_long_rounded, label: 'Activity', isCollapsed: _isSidebarCollapsed, isSelected: selectedIndex == 3, onTap: () => _onItemTapped(3, context)),
                      ],
                    ),
                  ),
                  if (!_isSidebarCollapsed)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Expense'),
                        onPressed: () {},
                      ),
                    ),
                  if (_isSidebarCollapsed)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: AppColors.primary500,
                        onPressed: () {},
                        child: const Icon(Icons.add_rounded, color: Colors.white),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Expanded(child: bodyContent),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: bodyContent,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (int idx) => _onItemTapped(idx, context),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
              NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'Groups'),
              NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Friends'),
              NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/groups')) return 1;
    if (location.startsWith('/friends')) return 2;
    if (location.startsWith('/activity')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/dashboard'); break;
      case 1: context.go('/groups'); break;
      case 2: context.go('/friends'); break;
      case 3: context.go('/activity'); break;
    }
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isCollapsed;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({required this.icon, required this.label, required this.isCollapsed, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary500.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        contentPadding: isCollapsed ? const EdgeInsets.symmetric(horizontal: 16) : const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(icon, color: isSelected ? AppColors.primary500 : colorScheme.onSurfaceVariant),
        title: isCollapsed
            ? null
            : Text(label, style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary500 : colorScheme.onSurface,
              )),
      ),
    );
  }
}
