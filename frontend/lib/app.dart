import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/groups/presentation/screens/group_list_screen.dart';
import 'features/activity/presentation/screens/activity_screen.dart';
import 'features/friends/presentation/screens/friends_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/profile/presentation/screens/legal_screens.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'shared/widgets/layout/scaffold_with_nav_bar.dart';

final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/legal/privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/legal/terms',
      builder: (context, state) => const TermsScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/groups',
          builder: (context, state) => const GroupListScreen(),
        ),
        GoRoute(
          path: '/friends',
          builder: (context, state) => const FriendsScreen(),
        ),
        GoRoute(
          path: '/activity',
          builder: (context, state) => const ActivityScreen(),
        ),
      ],
    ),
  ],
);

class SplitEaseApp extends ConsumerWidget {
  const SplitEaseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SplitEase',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
