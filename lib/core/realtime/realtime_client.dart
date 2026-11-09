import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// A server-pushed event: `{"event": "ride.status", "data": {...}}`.
class RealtimeEvent {
  const RealtimeEvent(this.event, this.data);

  final String event;
  final Map<String, dynamic> data;

  int? get rideId => (data['ride_id'] as num?)?.toInt();

  @override
  String toString() => 'RealtimeEvent($event, $data)';
}

/// Resilient WebSocket connection to a Django Channels endpoint.
///
/// * authenticates with the JWT access token (`?token=`),
/// * reconnects with exponential backoff (1 s → 30 s) and jitter,
/// * keeps the connection alive with an app-level ping,
/// * asks the caller to refresh the token when the server closes with 4401.
///
/// The app never relies on the socket alone: screens also poll the REST API,
/// so a dropped connection only delays updates by a few seconds.
class RealtimeClient {
  RealtimeClient({
    required this.path,
    required this.storage,
    this.onAuthExpired,
  });

  final String path;
  final TokenStorage storage;

  /// Called on close code 4401: should trigger an authenticated REST call so
  /// the Dio interceptor refreshes the access token before we reconnect.
  final Future<void> Function()? onAuthExpired;

  final _events = StreamController<RealtimeEvent>.broadcast();
  final ValueNotifier<bool> connected = ValueNotifier(false);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _attempt = 0;
  bool _disposed = false;
  bool _wanted = false;

  Stream<RealtimeEvent> get events => _events.stream;

  Future<void> connect() async {
    _wanted = true;
    if (_disposed || _channel != null) return;
    final token = storage.access;
    if (token == null || token.isEmpty) return;

    final uri = Uri.parse('${AppConfig.wsOrigin}$path?token=$token');
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready;
      if (_disposed) {
        await channel.sink.close();
        return;
      }
      _attempt = 0;
      connected.value = true;
      _sub = channel.stream.listen(
        _onMessage,
        onDone: () => _onClosed(channel.closeCode),
        onError: (Object e) => _onClosed(null, error: e),
        cancelOnError: true,
      );
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      });
    } catch (e) {
      _onClosed(null, error: e);
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode('$raw');
      if (json is! Map) return;
      final event = '${json['event'] ?? ''}';
      if (event.isEmpty || event == 'pong') return;
      final data = json['data'];
      _events.add(
        RealtimeEvent(event, data is Map ? data.cast<String, dynamic>() : const {}),
      );
    } catch (e) {
      debugPrint('[Realtime] bad message: $e');
    }
  }

  Future<void> _onClosed(int? code, {Object? error}) async {
    if (error != null) debugPrint('[Realtime] $path closed: $error');
    _teardown();
    if (_disposed || !_wanted) return;

    if (code == 4401 && onAuthExpired != null) {
      try {
        await onAuthExpired!();
      } catch (_) {}
    }
    if (code == 4403) return; // not allowed to follow this channel: stop

    final seconds = math.min(30, math.pow(2, _attempt).toInt());
    _attempt++;
    final jitter = Duration(milliseconds: math.Random().nextInt(700));
    _reconnectTimer = Timer(Duration(seconds: seconds) + jitter, connect);
  }

  void _teardown() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    connected.value = false;
  }

  /// Closes the socket and stops reconnecting (logout, screen left).
  void disconnect() {
    _wanted = false;
    _reconnectTimer?.cancel();
    _teardown();
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _events.close();
    connected.dispose();
  }
}
