import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/groups/presentation/screens/group_list_screen.dart';
import 'features/groups/presentation/screens/group_detail_screen.dart';
import 'features/groups/presentation/screens/group_settings_screen.dart';
import 'features/groups/presentation/screens/create_group_screen.dart';
import 'features/activity/presentation/screens/activity_screen.dart';
import 'features/friends/presentation/screens/friends_screen.dart';
import 'features/friends/presentation/screens/friend_detail_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/profile/presentation/screens/legal_screens.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/notifications/presentation/screens/notification_screen.dart';
import 'features/search/presentation/screens/search_screen.dart';
import 'features/settlements/presentation/screens/settle_all_screen.dart';
import 'shared/widgets/layout/scaffold_with_nav_bar.dart';

final _shellNavigatorKey = GlobalKey<NavigatorState>();

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

final _routerProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      if (authState.hasError) return loc == '/login' ? null : '/login';
      if (authState.isLoading) return loc == '/splash' ? null : '/splash';

      final isAuth = authState.valueOrNull != null;
      if (!isAuth) {
        if (loc == '/legal/privacy' || loc == '/legal/terms') return null;
        return loc == '/login' ? null : '/login';
      }

      final onboardingCompleted = authState.valueOrNull?['onboardingCompleted'] == true;
      if (loc == '/splash' || loc == '/login') {
        return onboardingCompleted ? '/dashboard' : '/onboarding';
      }
      if (!onboardingCompleted && loc != '/onboarding') return '/onboarding';
      if (onboardingCompleted && loc == '/onboarding') return '/dashboard';
      
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const _SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationListScreen()),
      GoRoute(path: '/search', builder: (context, state) => const GlobalSearchScreen()),
      GoRoute(path: '/settle-all', builder: (context, state) => const SettleAllScreen()),
      GoRoute(path: '/legal/privacy', builder: (context, state) => const PrivacyPolicyScreen()),
      GoRoute(path: '/legal/terms', builder: (context, state) => const TermsScreen()),
      GoRoute(path: '/groups/create', builder: (context, state) => const CreateGroupScreen()),
      GoRoute(path: '/groups/:id', builder: (context, state) => GroupDetailScreen(groupId: int.parse(state.pathParameters['id']!))),
      GoRoute(path: '/groups/:id/settings', builder: (context, state) => GroupSettingsScreen(groupId: int.parse(state.pathParameters['id']!))),
      GoRoute(path: '/friends/:id', builder: (context, state) => FriendDetailScreen(friendId: int.parse(state.pathParameters['id']!))),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/groups', builder: (context, state) => const GroupListScreen()),
          GoRoute(path: '/friends', builder: (context, state) => const FriendsScreen()),
          GoRoute(path: '/activity', builder: (context, state) => const ActivityScreen()),
        ],
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF9FAFB),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            Text('SplitEase', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1))),
          ],
        ),
      ),
    );
  }
}

class SplitEaseApp extends ConsumerWidget {
  const SplitEaseApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    final themeMode = ref.watch(themeNotifierProvider);
    return MaterialApp.router(
      title: 'SplitEase',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
