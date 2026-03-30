import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:tanodmobile/core/config/app_config.dart';
import 'package:tanodmobile/frontend/shared/providers/alert_provider.dart';
import 'package:tanodmobile/services/websocket/pusher_client.dart';

/// Manages a WebSocket connection to the Pusher-compatible server.
///
/// When the app is in the foreground and the user is authenticated, this
/// provider keeps a live WebSocket connection for real-time events.
/// When the app moves to the background, the connection is closed and
/// FCM push handles notifications instead.
class RealtimeProvider extends ChangeNotifier with WidgetsBindingObserver {
  RealtimeProvider({
    required Dio dio,
    required AlertProvider alertProvider,
  })  : _dio = dio,
        _alertProvider = alertProvider {
    WidgetsBinding.instance.addObserver(this);
  }

  final Dio _dio;
  final AlertProvider _alertProvider;

  PusherClient? _client;
  StreamSubscription<PusherEvent>? _eventSub;
  int? _userId;

  bool _connected = false;
  bool get connected => _connected;

  /// Start listening for the given user. No-op if already started for this user.
  void start(int userId) {
    if (_userId == userId && _client != null) return;
    stop();
    _userId = userId;
    _initAndConnect();
  }

  /// Stop listening and disconnect.
  void stop() {
    _eventSub?.cancel();
    _eventSub = null;
    _client?.dispose();
    _client = null;
    _connected = false;
    _userId = null;
    notifyListeners();
  }

  // ─── Connection Lifecycle ──────────────────────────────

  Future<void> _initAndConnect() async {
    final uri = Uri.parse(AppConfig.apiBaseUrl);

    _client = PusherClient(
      host: AppConfig.websocketHost,
      appKey: AppConfig.websocketKey,
      port: AppConfig.websocketPort,
      useTls: AppConfig.websocketUseTls,
      authCallback: (socketId, channelName) => _authenticate(
        uri,
        socketId,
        channelName,
      ),
    );

    _eventSub = _client!.events.listen(_handleEvent);

    await _client!.connect();
    await _client!.subscribe('private-notifications.$_userId');
    _connected = _client?.isConnected ?? false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _authenticate(
    Uri apiUri,
    String socketId,
    String channelName,
  ) async {
    // Build broadcasting auth URL from the API base.
    final port = (apiUri.port != 80 && apiUri.port != 443)
        ? ':${apiUri.port}'
        : '';
    final authUrl =
        '${apiUri.scheme}://${apiUri.host}$port/api/broadcasting/auth';

    final response = await _dio.post<dynamic>(
      authUrl,
      data: {
        'socket_id': socketId,
        'channel_name': channelName,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  // ─── Event Handling ────────────────────────────────────

  /// The last event received, exposed for consumers to react to.
  PusherEvent? _lastEvent;
  PusherEvent? get lastEvent => _lastEvent;

  void _handleEvent(PusherEvent event) {
    debugPrint('RealtimeProvider: ${event.event}');
    _lastEvent = event;

    final name = event.event;

    // Laravel broadcasts event names as "App\\Events\\AlertCreated"
    // or just "AlertCreated" depending on configuration.
    if (name.contains('AlertCreated')) {
      _alertProvider.fetchAlerts();
      _alertProvider.fetchUnacknowledgedCount();
    }

    // All event types are exposed via notifyListeners so UI can react.
    // Event types: AlertCreated, TicketCreated, TicketStatusUpdated,
    //              BookingCreated, BookingStatusUpdated, DistributionCreated
    notifyListeners();
  }

  // ─── App Lifecycle ─────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_userId == null) return;

    if (state == AppLifecycleState.resumed && !_connected) {
      _initAndConnect();
    } else if (state == AppLifecycleState.paused && _connected) {
      _eventSub?.cancel();
      _eventSub = null;
      _client?.disconnect();
      _connected = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSub?.cancel();
    _client?.dispose();
    super.dispose();
  }
}
