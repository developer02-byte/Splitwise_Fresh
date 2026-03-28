import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/socket_provider.dart';
import 'dart:developer';

class NotificationModel {
  final int id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final int? referenceId;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.referenceId,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      type: json['referenceType'] ?? json['type'],
      title: json['title'],
      body: json['body'] ?? json['message'],
      read: json['isRead'] ?? json['read'] ?? false,
      referenceId: json['referenceId'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class NotificationNotifier extends AsyncNotifier<List<NotificationModel>> {
  @override
  Future<List<NotificationModel>> build() async {
    // ── WebSocket Integration ──────────────────────────────────────────────────
    // Listen for real-time notifications from Socket.io
    final socket = ref.watch(socketNotifierProvider);
    
    socket.on('notification:new', (data) {
      log('Real-time notification received: $data', name: 'Notify_Contract');
      try {
        final newNotification = NotificationModel.fromJson(data);
        
        // Push the new notification to the top of the state list
        final current = state.value ?? [];
        state = AsyncData([newNotification, ...current]);
      } catch (e) {
        log('Failed to parse real-time notification', error: e);
      }
    });

    return _fetchNotifications();
  }

  Future<List<NotificationModel>> _fetchNotifications() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/notifications');
    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = response.data['data'] as List<dynamic>;
      return list.map((e) => NotificationModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load notifications');
  }

  Future<void> markAsRead(int id) async {
    final dio = ref.read(dioProvider);
    await dio.put('/api/notifications/$id/read');
    final currentList = state.value ?? [];
    state = AsyncData(currentList.map((n) {
      if (n.id == id) return NotificationModel(id: n.id, type: n.type, title: n.title, body: n.body, read: true, referenceId: n.referenceId, createdAt: n.createdAt);
      return n;
    }).toList());
  }

  Future<void> markAllAsRead() async {
    final dio = ref.read(dioProvider);
    await dio.put('/api/notifications/read-all');
    final currentList = state.value ?? [];
    state = AsyncData(currentList.map((n) => NotificationModel(id: n.id, type: n.type, title: n.title, body: n.body, read: true, referenceId: n.referenceId, createdAt: n.createdAt)).toList());
  }

  Future<void> registerFCMToken(String token) async {
    final dio = ref.read(dioProvider);
    await dio.post('/api/notifications/register-token', data: {'token': token, 'deviceId': 'flutter-client'});
  }

  int get unreadCount {
    return state.value?.where((e) => !e.read).length ?? 0;
  }
}

final notificationNotifierProvider = AsyncNotifierProvider<NotificationNotifier, List<NotificationModel>>(NotificationNotifier.new);
