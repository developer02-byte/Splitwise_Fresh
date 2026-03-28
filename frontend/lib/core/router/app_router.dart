import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/groups/presentation/screens/group_list_screen.dart';
import '../../features/groups/presentation/screens/create_group_screen.dart';
import '../../features/groups/presentation/screens/group_detail_screen.dart';
import '../../features/friends/presentation/screens/friend_detail_screen.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/change_password_screen.dart';
import '../../features/settlements/presentation/screens/settle_up_screen.dart';
import '../../features/activity/presentation/screens/activity_screen.dart';
import '../../features/expenses/presentation/screens/expense_detail_screen.dart';
import '../../features/expenses/presentation/screens/edit_expense_screen.dart';
import '../../features/notifications/presentation/screens/notification_screen.dart';
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
      final isSigningUp = state.matchedLocation == '/signup';
      final isForgotPassword = state.matchedLocation == '/forgot-password';
      final isAuthRoute = isLoggingIn || isSigningUp || isForgotPassword;
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) {
        // Check if onboarding is completed
        final onboardingCompleted = authState.value?['onboardingCompleted'] == true;
        if (!onboardingCompleted) return '/onboarding';
        return '/dashboard';
      }
      if (isAuth && !isOnboarding) {
        final onboardingCompleted = authState.value?['onboardingCompleted'] == true;
        if (!onboardingCompleted && state.matchedLocation != '/onboarding') return '/onboarding';
      }

      return null; // Let the route pass
    },

    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password/:token',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return ResetPasswordScreen(token: token);
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
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
            builder: (context, state) => const GroupListScreen(),
          ),
          GoRoute(
            path: '/friends',
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) => const FriendsScreen(),
          ),
          GoRoute(
            path: '/activity',
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) => const ActivityScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/add-expense',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Add Expense (Story 03)')),
          body: const Center(child: Text('Add Expense Flow Coming Soon')),
        ),
      ),
      GoRoute(
        path: '/settle-up',
        builder: (context, state) {
          final paramId = int.tryParse(state.uri.queryParameters['friendId'] ?? '') ?? null;
          final paramAmt = double.tryParse(state.uri.queryParameters['amount'] ?? '') ?? null;
          return SettleUpScreen(prefilledPayeeId: paramId, prefilledAmount: paramAmt);
        },
      ),
      GoRoute(
        path: '/groups/create',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return GroupDetailScreen(groupId: id);
        },
      ),
    // ... other custom parameters over here
    GoRoute(
      path: '/expenses/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return ExpenseDetailScreen(id: id);
      },
    ),
    GoRoute(
      path: '/expenses/:id/edit',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return EditExpenseScreen(id: id);
      },
    ),
    GoRoute(
      path: '/friends/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return FriendDetailScreen(friendId: id);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/change-password',
      builder: (context, state) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationListScreen(),
    ),
  ],
);
});
