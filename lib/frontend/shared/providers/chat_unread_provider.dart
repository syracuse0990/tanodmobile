import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/services/websocket/pusher_client.dart';

class ChatUnreadProvider extends ChangeNotifier with WidgetsBindingObserver {
  ChatUnreadProvider({required ApiClient apiClient}) : _apiClient = apiClient {
    WidgetsBinding.instance.addObserver(this);
  }

  final ApiClient _apiClient;

  int? _userId;
  int? _activeTicketId;
  bool _hasLoaded = false;
  Future<void>? _refreshing;
  String? _lastEventFingerprint;

  Map<int, int> _unreadCounts = const {};
  Map<int, List<int>> _notificationIdsByTicket = const {};

  int get totalUnreadCount =>
      _unreadCounts.values.fold(0, (sum, count) => sum + count);

  int unreadCountForTicket(int ticketId) => _unreadCounts[ticketId] ?? 0;

  void syncUser(int? userId) {
    if (_userId == userId) {
      return;
    }

    _userId = userId;
    _activeTicketId = null;
    _hasLoaded = false;
    _refreshing = null;
    _lastEventFingerprint = null;
    _unreadCounts = const {};
    _notificationIdsByTicket = const {};
    _safeNotify();

    if (userId != null) {
      unawaited(refreshUnreadCounts());
    }
  }

  void setActiveTicketId(int? ticketId) {
    if (_activeTicketId == ticketId) {
      return;
    }

    _activeTicketId = ticketId;

    if (ticketId != null) {
      unawaited(markTicketAsRead(ticketId));
    }
  }

  Future<void> refreshUnreadCounts() {
    if (_userId == null) {
      return Future.value();
    }

    return _refreshing ??= _loadUnreadCounts().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<void> markTicketAsRead(int ticketId) async {
    if (_userId == null) {
      return;
    }

    if (!_hasLoaded) {
      await refreshUnreadCounts();
    }

    final notificationIds = List<int>.from(
      _notificationIdsByTicket[ticketId] ?? const <int>[],
    );

    if (notificationIds.isEmpty) {
      return;
    }

    try {
      for (final notificationId in notificationIds) {
        await _apiClient.post(
          '${AppEndpoints.notifications}/$notificationId/read',
        );
      }

      final unreadCounts = Map<int, int>.from(_unreadCounts);
      final notificationIdsByTicket = Map<int, List<int>>.from(
        _notificationIdsByTicket,
      );

      unreadCounts.remove(ticketId);
      notificationIdsByTicket.remove(ticketId);

      _unreadCounts = unreadCounts;
      _notificationIdsByTicket = notificationIdsByTicket;
      _safeNotify();
    } catch (error) {
      debugPrint('ChatUnreadProvider.markTicketAsRead error: $error');
      await refreshUnreadCounts();
    }
  }

  void consumeRealtimeEvent(PusherEvent? event) {
    if (_userId == null || event == null) {
      return;
    }

    final fingerprint = _fingerprint(event);
    if (_lastEventFingerprint == fingerprint) {
      return;
    }
    _lastEventFingerprint = fingerprint;

    final isTicketCommentEvent =
        event.channel == 'private-notifications.$_userId' &&
        event.event.contains('TicketCommentAdded');

    if (!isTicketCommentEvent) {
      return;
    }

    final comment = _asMap(event.data['comment']);
    final ticketId = _asInt(comment?['ticket_id']);
    if (ticketId == null) {
      return;
    }

    if (_activeTicketId == ticketId) {
      unawaited(_refreshAndMarkTicketAsRead(ticketId));
      return;
    }

    unawaited(refreshUnreadCounts());
  }

  Future<void> _refreshAndMarkTicketAsRead(int ticketId) async {
    await refreshUnreadCounts();
    await markTicketAsRead(ticketId);
  }

  Future<void> _loadUnreadCounts() async {
    final unreadCounts = <int, int>{};
    final notificationIdsByTicket = <int, List<int>>{};

    var page = 1;
    var lastPage = 1;

    try {
      do {
        final response = await _apiClient.get(
          AppEndpoints.notifications,
          queryParameters: {'unread': '1', 'page': '$page', 'per_page': '100'},
        );

        final dataList = response['data'] as List<dynamic>? ?? const [];
        for (final item in dataList.whereType<Map<String, dynamic>>()) {
          if (item['type']?.toString() != 'ticket_comment') {
            continue;
          }

          final notificationId = _asInt(item['id']);
          final data = _asMap(item['data']);
          final ticketId = _asInt(data?['ticket_id']);

          if (notificationId == null || ticketId == null) {
            continue;
          }

          unreadCounts.update(
            ticketId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
          notificationIdsByTicket
              .putIfAbsent(ticketId, () => <int>[])
              .add(notificationId);
        }

        final currentPage = _asInt(response['current_page']) ?? page;
        lastPage = _asInt(response['last_page']) ?? currentPage;
        page = currentPage + 1;
      } while (page <= lastPage);

      _hasLoaded = true;
      _unreadCounts = unreadCounts;
      _notificationIdsByTicket = notificationIdsByTicket;
      _safeNotify();
    } catch (error) {
      debugPrint('ChatUnreadProvider.refreshUnreadCounts error: $error');
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  String _fingerprint(PusherEvent event) {
    final comment = _asMap(event.data['comment']);
    final commentId = _asInt(comment?['id']);
    if (commentId != null) {
      return '${event.channel}|${event.event}|$commentId';
    }

    final ticketId = _asInt(comment?['ticket_id']);
    return '${event.channel}|${event.event}|$ticketId|${event.data}';
  }

  void _safeNotify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _userId != null) {
      unawaited(refreshUnreadCounts());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
