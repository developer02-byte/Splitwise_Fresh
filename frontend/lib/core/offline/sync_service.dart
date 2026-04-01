import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer';
import 'dart:convert';

import '../network/dio_provider.dart';
import 'sqlite_queue.dart';

final syncServiceProvider = Provider((ref) => OfflineSyncService(ref));

class OfflineSyncService {
  final Ref _ref;
  StreamSubscription? _subscription;
  bool _isSyncing = false;

  OfflineSyncService(this._ref);

  void start() {
    _subscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        log('Network restored. Starting sync...', name: 'SyncService');
        _performSync();
      }
    });

    // Also try sync on start
    _performSync();
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final dio = _ref.read(dioProvider);
      final actions = await SQLiteQueueHelper.getPendingActions();
      
      log('Syncing ${actions.length} pending actions', name: 'SyncService');

      for (final action in actions) {
        final id = action['id'] as int;
        final type = action['action_type'] as String;
        final payload = jsonDecode(action['payload'] as String);
        final idempotencyKey = action['idempotency_key'] as String?;

        try {
          if (type == 'POST_EXPENSE') {
            await dio.post('/api/expenses', data: {
              ...payload,
              'idempotencyKey': idempotencyKey,
            });
          }
          // handle other types...

          await SQLiteQueueHelper.markCompleted(id);
          log('Successfully synced action $id', name: 'SyncService');
        } catch (e) {
          log('Failed to sync action $id: $e', error: true, name: 'SyncService');
          // If it's a 4xx error (validation), we might want to discard it or keep it
          // For now, we stop syncing and wait for next heartbeat/restoration
          break; 
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
