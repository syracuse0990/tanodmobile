import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Lightweight Pusher-compatible WebSocket client.
///
/// Implements the minimum Pusher protocol needed for private-channel
/// subscriptions with a custom (non-Pusher-hosted) WebSocket server.
class PusherClient {
  PusherClient({
    required this.host,
    required this.appKey,
    required this.authCallback,
    this.port = 443,
    this.useTls = true,
  });

  final String host;
  final String appKey;
  final int port;
  final bool useTls;

  /// Called to obtain an auth signature for a private/presence channel.
  /// Should POST to the Laravel broadcasting/auth endpoint and return
  /// the JSON response body (e.g. `{auth: "key:sig"}`).
  final Future<Map<String, dynamic>> Function(
    String socketId,
    String channelName,
  ) authCallback;

  WebSocketChannel? _channel;
  String? _socketId;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _intentionalDisconnect = false;

  final _eventController = StreamController<PusherEvent>.broadcast();
  final Map<String, bool> _subscribedChannels = {};

  /// Stream of incoming events from subscribed channels.
  Stream<PusherEvent> get events => _eventController.stream;

  /// Current socket ID (available after connection is established).
  String? get socketId => _socketId;

  /// Whether the client is currently connected.
  bool get isConnected => _socketId != null;

  /// Connect to the WebSocket server.
  Future<void> connect() async {
    _intentionalDisconnect = false;
    final scheme = useTls ? 'wss' : 'ws';
    final uri = Uri.parse('$scheme://$host:$port/app/$appKey');

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
    } catch (e) {
      debugPrint('PusherClient: connection failed: $e');
      _scheduleReconnect();
    }
  }

  /// Disconnect and clean up.
  void disconnect() {
    _intentionalDisconnect = true;
    _cleanup();
  }

  /// Subscribe to a private channel.
  Future<void> subscribe(String channelName) async {
    if (_socketId == null) {
      // Queue subscription for after connection.
      _subscribedChannels[channelName] = false;
      return;
    }

    try {
      final authData = await authCallback(_socketId!, channelName);

      _send({
        'event': 'pusher:subscribe',
        'data': {
          'channel': channelName,
          'auth': authData['auth'],
          if (authData.containsKey('channel_data'))
            'channel_data': authData['channel_data'],
        },
      });

      _subscribedChannels[channelName] = true;
    } catch (e) {
      debugPrint('PusherClient: subscribe failed for $channelName: $e');
    }
  }

  /// Unsubscribe from a channel.
  void unsubscribe(String channelName) {
    _send({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channelName},
    });
    _subscribedChannels.remove(channelName);
  }

  /// Send a client event on a channel (Pusher `client-` prefix convention).
  /// The server broadcasts it to all other subscribers of the channel.
  void trigger(String channelName, String event, Map<String, dynamic> data) {
    if (!_subscribedChannels.containsKey(channelName)) return;
    _send({
      'event': event,
      'channel': channelName,
      'data': data,
    });
  }

  // ─── Internal ──────────────────────────────────────────

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = msg['event'] as String? ?? '';

      switch (event) {
        case 'pusher:connection_established':
          final data = jsonDecode(msg['data'] as String) as Map<String, dynamic>;
          _socketId = data['socket_id'] as String?;
          debugPrint('PusherClient: connected (socketId=$_socketId)');
          _startPing();
          _resubscribeAll();
          break;

        case 'pusher:pong':
          // Server responded to our ping — connection is alive.
          break;

        case 'pusher_internal:subscription_succeeded':
          final ch = msg['channel'] as String? ?? '';
          _subscribedChannels[ch] = true;
          debugPrint('PusherClient: subscribed to $ch');
          break;

        case 'pusher:error':
          debugPrint('PusherClient: server error: ${msg['data']}');
          break;

        default:
          // Application event.
          final channel = msg['channel'] as String?;
          dynamic data = msg['data'];
          if (data is String) {
            try {
              data = jsonDecode(data);
            } catch (_) {}
          }

          _eventController.add(PusherEvent(
            event: event,
            channel: channel,
            data: data is Map<String, dynamic> ? data : <String, dynamic>{},
          ));
      }
    } catch (e) {
      debugPrint('PusherClient: message parse error: $e');
    }
  }

  void _onError(Object error) {
    debugPrint('PusherClient: stream error: $error');
  }

  void _onDone() {
    debugPrint('PusherClient: connection closed');
    _socketId = null;
    _pingTimer?.cancel();

    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _send({'event': 'pusher:ping', 'data': {}});
    });
  }

  void _resubscribeAll() {
    for (final channel in _subscribedChannels.keys.toList()) {
      subscribe(channel);
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      debugPrint('PusherClient: reconnecting...');
      connect();
    });
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _socketId = null;
    _subscribedChannels.clear();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _intentionalDisconnect = true;
    _cleanup();
    _eventController.close();
  }
}

/// Represents a single event received from the WebSocket server.
class PusherEvent {
  const PusherEvent({
    required this.event,
    this.channel,
    this.data = const {},
  });

  final String event;
  final String? channel;
  final Map<String, dynamic> data;

  @override
  String toString() => 'PusherEvent(event=$event, channel=$channel)';
}
