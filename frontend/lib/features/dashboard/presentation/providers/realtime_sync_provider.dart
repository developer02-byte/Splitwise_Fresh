import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:developer';

import '../../../../core/network/socket_provider.dart';
// State providers to invalidate
import 'balance_provider.dart';

part 'realtime_sync_provider.g.dart';

/// Centralized Realtime Event listener.
/// Instead of injecting UI callbacks all over individual screens, this 
/// background logic-only provider reads incoming socket events and intelligently 
/// invalidates the localized Riverpod states, guaranteeing the UI updates 
/// smoothly across the entire app.
@Riverpod(keepAlive: true)
class RealtimeSyncManager extends _$RealtimeSyncManager {
  @override
  void build() {
    final socket = ref.watch(socketNotifierProvider);

    if (!socket.connected) {
      ref.read(socketNotifierProvider.notifier).connect();
    }

    // ---------------------------------------------------------
    // Event Payload Dictionary Mapping (Realtime_Contract.md)
    // ---------------------------------------------------------

    socket.on('expense:created', (data) {
      log('Live Event: New Expense recorded in group', name: 'RealtimeSync');
      // A new expense shifts balances. Trigger a UI refresh gracefully.
      ref.invalidate(balanceNotifierProvider);
      // TODO: Invalidate Group Ledger Provider
    });

    socket.on('settlement:created', (data) {
      log('Live Event: Settlement Payment Confirmed', name: 'RealtimeSync');
      // If Bob paid Alice across the country, Alice's phone will automatically
      // see the Dashboard balance clear.
      ref.invalidate(balanceNotifierProvider);
    });

    socket.on('expense:updated', (data) {
      log('Live Event: Expense edited', name: 'RealtimeSync');
      ref.invalidate(balanceNotifierProvider);
    });

    // Automatically clean up listeners if Provider is destroyed
    ref.onDispose(() {
      socket.off('expense:created');
      socket.off('settlement:created');
      socket.off('expense:updated');
    });
  }
}
