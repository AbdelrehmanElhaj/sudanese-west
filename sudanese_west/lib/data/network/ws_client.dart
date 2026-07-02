import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Thin WebSocket wrapper — connect, send JSON, receive JSON stream.
///
/// Automatically reconnects after an unexpected disconnect using exponential
/// backoff (1 s, 2 s, 4 s … up to 30 s) for up to [_maxRetries] attempts.
/// [onReconnected] fires after each successful re-connection so callers can
/// re-authenticate (e.g. send REJOIN_ROOM).
class WsClient {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _disposed = false;
  bool _hasConnectedOnce = false;
  String? _url;
  int _retryCount = 0;
  static const int _maxRetries = 8;

  /// Called after every successful re-connection (not the initial connect).
  void Function()? onReconnected;

  Stream<Map<String, dynamic>> get messages => _controller.stream;
  bool get isConnected => _channel != null && !_disposed;

  Future<void> connect(String url) async {
    // A prior disconnect() latches _disposed and closes the controller —
    // undo both so this instance can be reused to join/host a new room.
    if (_disposed) {
      _controller = StreamController<Map<String, dynamic>>.broadcast();
      _disposed = false;
      _hasConnectedOnce = false;
    }
    _url = url;
    _retryCount = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_disposed || _url == null) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url!));
      await _channel!.ready; // throws on connection failure

      final wasReconnect = _hasConnectedOnce;
      _hasConnectedOnce = true;
      _retryCount = 0;

      _channel!.stream.listen(
        (raw) {
          if (_disposed) return;
          try {
            final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
            _controller.add(decoded);
          } catch (_) {}
        },
        onError: (_) {
          _channel = null;
          _scheduleReconnect();
        },
        onDone: () {
          _channel = null;
          if (!_disposed) _scheduleReconnect();
        },
        cancelOnError: false,
      );

      if (wasReconnect) onReconnected?.call();
    } catch (_) {
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (_retryCount >= _maxRetries) {
      if (!_controller.isClosed) _controller.addError('Connection lost');
      return;
    }
    final delaySecs = min(1 << _retryCount, 30);
    _retryCount++;
    Future.delayed(Duration(seconds: delaySecs), _doConnect);
  }

  void send(Map<String, dynamic> message) {
    if (!isConnected) return;
    _channel!.sink.add(jsonEncode(message));
  }

  Future<void> disconnect() async {
    _disposed = true;
    await _channel?.sink.close();
    _channel = null;
    if (!_controller.isClosed) await _controller.close();
  }
}
