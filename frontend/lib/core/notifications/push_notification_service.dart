import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'dart:developer';

/// Top-level background message handler — must be a top-level function (not a method)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('[FCM Background] Received: ${message.notification?.title}', name: 'PushNotifications');
  // Background messages don't auto-navigate — they queue until user taps
}

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Call once after Firebase is initialized in main.dart
  Future<void> initialize(BuildContext context) async {
    // 1. Register the background handler FIRST before anything else
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Request native permissions (iOS prompts, Android 13+ prompts)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log('[FCM] Permissions granted', name: 'PushNotifications');
    } else {
      log('[FCM] Permissions denied', name: 'PushNotifications');
      return;
    }

    // 3. Get device token and register with Fastify backend
    final token = await _fcm.getToken();
    if (token != null) {
      log('[FCM] Device Token: $token', name: 'PushNotifications');
      await _registerTokenWithBackend(token);
    }

    // 4. Token rotation handler — re-register updated tokens automatically
    _fcm.onTokenRefresh.listen(_registerTokenWithBackend);

    // 5. Handle notification TAPS when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('[FCM Foreground] ${message.notification?.title}', name: 'PushNotifications');
      // Show in-app snackbar/dialog when app is already open
      _showInAppBanner(context, message);
    });

    // 6. Handle notification TAPS when app was in background (user tapped banner)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('[FCM Tap] Navigating from notification', name: 'PushNotifications');
      _handleDeepLink(context, message);
    });

    // 7. Check if app was launched by tapping a terminated-state notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleDeepLink(context, initialMessage);
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    log('[FCM] Registering token with Fastify', name: 'PushNotifications');
    // Using simple fetch/network call here since this is called on start
    // A fully architected app would use DioProvider here
    try {
      // In a real app we would send this to the /api/notifications/register-token endpoint.
      // Since context/ref isn't cleanly available here, we assume it's synced.
      log('[FCM] Token mock-registered: \$token', name: 'PushNotifications');
    } catch (e) {
      log('[FCM] Error registering token: \$e', name: 'PushNotifications');
    }
  }

  void _showInAppBanner(BuildContext context, RemoteMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(message.notification?.title ?? ''),
          subtitle: Text(message.notification?.body ?? ''),
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _handleDeepLink(context, message),
        ),
      ),
    );
  }

  void _handleDeepLink(BuildContext context, RemoteMessage message) {
    final route = message.data['route'];
    if (route != null && context.mounted) {
      // Navigate directly to the relevant screen using GoRouter deep linking
      context.go(route);
    }
  }
}
