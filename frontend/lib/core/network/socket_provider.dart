import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:developer';

part 'socket_provider.g.dart';

@Riverpod(keepAlive: true)
class SocketNotifier extends _$SocketNotifier {
  late IO.Socket _socket;

  @override
  IO.Socket build() {
    // 1. Initialize Socket.io connecting to Fastify
    _socket = IO.io('http://localhost:3000', IO.OptionBuilder()
      .setTransports(['websocket']) 
      .disableAutoConnect()
      // Send HttpOnly cookies automatically attached by the browser/engine
      .setExtraHeaders({'withCredentials': true})
      .build()
    );

    // 2. Global Connection Logs
    _socket.onConnect((_) {
      log('Real-time Socket Connected', name: 'Realtime Contract');
    });

    _socket.onConnectError((err) {
      log('Socket Error: $err', name: 'Realtime Contract', error: true);
    });

    _socket.onDisconnect((_) {
      log('Socket Disconnected', name: 'Realtime Contract');
    });

    return _socket;
  }

  void connect() => _socket.connect();
  void disconnect() => _socket.disconnect();

  /// Joins a specific group room after optimistic client-side creation
  void joinGroupRoom(int groupId) {
    _socket.emit('room:join', groupId);
  }
}
