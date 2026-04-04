import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:tanodmobile/core/config/app_config.dart';
import 'package:tanodmobile/frontend/shared/providers/alert_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/feedback_provider.dart';
import 'package:tanodmobile/services/notifications/local_notification_service.dart';
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
    required FeedbackProvider feedbackProvider,
  }) : _dio = dio,
       _alertProvider = alertProvider,
       _feedbackProvider = feedbackProvider {
    WidgetsBinding.instance.addObserver(this);
  }

  final Dio _dio;
  final AlertProvider _alertProvider;
  final FeedbackProvider _feedbackProvider;

  PusherClient? _client;
  StreamSubscription<PusherEvent>? _eventSub;
  int? _userId;

  bool _connected = false;
  bool get connected => _connected;

  /// Raw event stream for external listeners (e.g. ticket detail screen).
  Stream<PusherEvent>? get events => _client?.events;

  /// Subscribe to an additional private channel (e.g. ticket chat).
  Future<void> subscribeToChannel(String channel) async {
    await _client?.subscribe(channel);
  }

  /// Unsubscribe from an additional channel.
  void unsubscribeFromChannel(String channel) {
    _client?.unsubscribe(channel);
  }

  /// Send a client event on a channel (e.g. typing indicator).
  void triggerClientEvent(
    String channel,
    String event,
    Map<String, dynamic> data,
  ) {
    _client?.trigger(channel, event, data);
  }

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
      authCallback: (socketId, channelName) =>
          _authenticate(uri, socketId, channelName),
    );

    _eventSub = _client!.events.listen(_handleEvent);

    debugPrint('RealtimeProvider: connecting to WebSocket...');
    await _client!.connect();
    debugPrint(
      'RealtimeProvider: connected, socketId=${_client!.socketId}',
    );

    final channel = 'private-notifications.$_userId';
    debugPrint('RealtimeProvider: subscribing to $channel');
    await _client!.subscribe(channel);
    debugPrint(
      'RealtimeProvider: subscribe request sent for $channel',
    );

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

    debugPrint(
      'RealtimeProvider: auth request for $channelName (socketId=$socketId)',
    );

    final response = await _dio.post<dynamic>(
      authUrl,
      data: {'socket_id': socketId, 'channel_name': channelName},
    );

    debugPrint('RealtimeProvider: auth response for $channelName: ${response.statusCode}');

    return Map<String, dynamic>.from(response.data as Map);
  }

  // ─── Event Handling ────────────────────────────────────

  /// The last event received, exposed for consumers to react to.
  PusherEvent? _lastEvent;
  PusherEvent? get lastEvent => _lastEvent;

  void _handleEvent(PusherEvent event) {
    debugPrint('RealtimeProvider: ${event.event} on ${event.channel}');
    _lastEvent = event;

    final name = event.event;
    final isNotifChannel = event.channel == 'private-notifications.$_userId';

    debugPrint(
      'RealtimeProvider: event=$name channel=${event.channel} '
      'isNotifChannel=$isNotifChannel userId=$_userId',
    );

    // Laravel broadcasts event names as "App\\Events\\AlertCreated"
    // or just "AlertCreated" depending on configuration.
    if (name.contains('AlertCreated')) {
      _alertProvider.fetchAlerts();
      _alertProvider.fetchUnacknowledgedCount();
    }

    // Show local notification for ticket comments on the global channel.
    if (name.contains('TicketCommentAdded') && isNotifChannel) {
      debugPrint('RealtimeProvider: showing ticket comment notification');
      _showTicketCommentNotification(event.data);
    }

    // Auto-refresh feedback list when a new feedback is created.
    if (name.contains('FeedbackCreated') && isNotifChannel) {
      _feedbackProvider.fetchFeedbacks();
    }

    // All event types are exposed via notifyListeners so UI can react.
    notifyListeners();
  }

  void _showTicketCommentNotification(Map<String, dynamic> data) {
    debugPrint('RealtimeProvider: notification data=$data');
    final comment = data['comment'] as Map<String, dynamic>?;
    if (comment == null) {
      debugPrint('RealtimeProvider: no "comment" key in event data, skipping');
      return;
    }

    final user = comment['user'] as Map<String, dynamic>?;
    final senderName = user?['name']?.toString() ?? 'Someone';
    final ticketId = comment['ticket_id'];
    final body = comment['body']?.toString() ?? '';
    final hasAttachment =
        (comment['attachment_path']?.toString() ?? '').isNotEmpty;

    final notificationBody = body.isNotEmpty
        ? body
        : hasAttachment
        ? 'Sent an attachment'
        : 'Sent a message';

    // Use comment id for unique notification, fallback to ticket id.
    final commentId = comment['id'];
    final notifId = commentId is int
        ? commentId
        : ticketId is int
        ? ticketId
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;

    debugPrint(
      'RealtimeProvider: showing notification — id=$notifId '
      'sender=$senderName body=$notificationBody ticketId=$ticketId',
    );

    LocalNotificationService.instance.show(
      id: notifId,
      title: '$senderName replied on a ticket',
      body: notificationBody,
      payload: {'ticket_id': ticketId},
    );
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
