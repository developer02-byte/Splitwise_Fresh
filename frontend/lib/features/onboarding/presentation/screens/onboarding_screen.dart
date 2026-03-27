import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Add your friends',
      'body': 'Connect with roommates, travel buddies, or your partner to easily keep track of shared expenses.',
      'icon': Icons.people_outline,
      'color': const Color(0xFF6366F1), // Indigo
    },
    {
      'title': 'Create a group',
      'body': 'Organize expenses by trip, apartment, or project. Everyone in the group can add expenses and see balances.',
      'icon': Icons.folder_shared_outlined,
      'color': const Color(0xFF10B981), // Emerald
    },
    {
      'title': 'Settle up seamlessly',
      'body': 'SplitEase automatically simplifies complex debts. Tap one button to record a payment and get back to even.',
      'icon': Icons.payment_outlined,
      'color': const Color(0xFFF59E0B), // Amber
    },
  ];

  Future<void> _completeOnboarding() async {
    if (mounted) context.go('/dashboard');
  }

  void _nextPage() {
    if (_currentPage == _pages.length - 1) {
      _completeOnboarding();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _completeOnboarding,
            child: Text('Skip', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: kSpacingM),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(kSpacingXXL),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: (page['color'] as Color).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page['icon'] as IconData, size: 80, color: page['color'] as Color),
                        ),
                        const SizedBox(height: 60),
                        Text(
                          page['title'] as String,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: kSpacingL),
                        Text(
                          page['body'] as String,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // ── Bottom Navigation Row ──
            Padding(
              padding: const EdgeInsets.all(kSpacingXXL),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicators
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index 
                              ? Theme.of(context).colorScheme.primary 
                              : Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  
                  // Next / Get Started Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusL)),
                    ),
                    onPressed: _nextPage,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
