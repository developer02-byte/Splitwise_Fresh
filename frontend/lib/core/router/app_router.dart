import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../shared/widgets/layout/scaffold_with_nav_bar.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    
    // Global Redirect Guard
    redirect: (context, state) {
      final isAuth = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuth && !isLoggingIn) return '/login';
      if (isAuth && isLoggingIn) return '/dashboard';
      
      return null; // Let the route pass
    },
    
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      
      // ShellRoute wraps the inner pages with the persistent Bottom Navigation Bar
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return ScaffoldWithNavBar(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/groups',
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) => const Center(child: Text('Groups (Phase 5)')),
          ),
          GoRoute(
            path: '/friends',
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) => const Center(child: Text('Friends (Phase 6)')),
          ),
          GoRoute(
            path: '/activity',
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) => const Center(child: Text('Activity (Phase 7)')),
          ),
        ],
      ),
    ],
  );
});
