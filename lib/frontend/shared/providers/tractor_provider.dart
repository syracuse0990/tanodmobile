import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/models/domain/tractor_location.dart';

class TractorProvider extends ChangeNotifier {
  TractorProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  static const _defaultInterval = Duration(seconds: 20);
  static const _focusedInterval = Duration(seconds: 10);

  Timer? _pollTimer;
  Timer? _countdownTimer;
  List<TractorLocation> _tractors = [];
  bool _loading = false;
  String? _error;
  String _searchQuery = '';

  int? _focusedTractorId;
  int _secondsUntilPoll = 0;
  bool _homeVisible = true;
  DateTime? _nextPollAt;
  int _pollSessionId = 0;
  int _latestAllRequestId = 0;
  int _latestFocusedRequestId = 0;

  List<TractorLocation> get tractors => _tractors;
  List<TractorLocation> get withLocation =>
      _tractors.where((t) => t.hasLocation).toList(growable: false);
  bool get loading => _loading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  int get movingCount => _tractors.where((t) => t.isMoving).length;
  int get onlineCount => _tractors.where((t) => t.isOnline).length;
  int get idleCount => _tractors.where((t) => t.isIdle).length;
  int get offlineCount => _tractors.where((t) => !t.isOnline).length;
  int? get focusedTractorId => _focusedTractorId;
  int get secondsUntilPoll => _secondsUntilPoll;
  bool get isFocused => _focusedTractorId != null;
  bool get homeVisible => _homeVisible;

  /// Set whether the home screen is visible. Starts/stops polling accordingly.
  void setHomeVisible(bool visible) {
    _homeVisible = visible;
    if (visible) {
      startPolling();
    } else {
      stopPolling();
    }
  }

  Duration get _activeInterval =>
      isFocused ? _focusedInterval : _defaultInterval;

  /// Focus on a single tractor – switches to 10s polling.
  void focusTractor(int tractorId) {
    _pollSessionId += 1;
    _focusedTractorId = tractorId;
    notifyListeners();
    _restartPolling();
  }

  /// Clear focus – returns to 20s polling.
  void clearFocus() {
    _pollSessionId += 1;
    _focusedTractorId = null;
    notifyListeners();
    _restartPolling();
  }

  /// Apply a backend-scoped search query to the tractor list.
  Future<void> setSearchQuery(String query, {bool clearFocus = false}) async {
    final normalized = query.trim();
    final shouldClearFocus = clearFocus && _focusedTractorId != null;
    if (_searchQuery == normalized && !shouldClearFocus) {
      return;
    }

    _pollSessionId += 1;
    _searchQuery = normalized;
    if (shouldClearFocus) {
      _focusedTractorId = null;
    }
    _nextPollAt = null;
    notifyListeners();
    _restartPolling(fetchImmediately: false);
    if (_homeVisible) {
      await fetch();
    }
  }

  /// Fetch tractors from the API and merge live GPS from Jimi.
  /// When focused on a single tractor, only fetches that device's
  /// real-time location (no cache) instead of all devices.
  Future<void> fetch() async {
    if (isFocused) {
      return _fetchFocused();
    }
    return _fetchAll();
  }

  /// Fetch all tractors + all live locations (20s polling).
  Future<void> _fetchAll() async {
    final requestId = ++_latestAllRequestId;
    final sessionId = _pollSessionId;

    _loading = _tractors.isEmpty;
    _error = null;
    notifyListeners();

    try {
      // Fetch the first tractor page and live GPS in parallel, then load any
      // remaining tractor pages so fleet counts reflect the full scope.
      final tractorQueryParameters = <String, dynamic>{'per_page': '200'};
      if (_searchQuery.isNotEmpty) {
        tractorQueryParameters['search'] = _searchQuery;
      }

      final results = await Future.wait([
        _apiClient.get(
          AppEndpoints.tractors,
          queryParameters: {
            ...tractorQueryParameters,
            'page': '1',
          },
        ),
        _apiClient.get(AppEndpoints.devicesLiveLocations),
      ]);

      final tractorResponse = results[0];
      final liveResponse = results[1];

      if (
          requestId != _latestAllRequestId ||
          sessionId != _pollSessionId ||
          isFocused) {
        return;
      }

      final dataList = <dynamic>[
        ...(tractorResponse['data'] as List<dynamic>? ?? const []),
      ];
      final lastPage = _extractLastPage(tractorResponse);

      for (var page = 2; page <= lastPage; page++) {
        if (
            requestId != _latestAllRequestId ||
            sessionId != _pollSessionId ||
            isFocused) {
          return;
        }

        final nextPageResponse = await _apiClient.get(
          AppEndpoints.tractors,
          queryParameters: {
            ...tractorQueryParameters,
            'page': page.toString(),
          },
        );

        if (
            requestId != _latestAllRequestId ||
            sessionId != _pollSessionId ||
            isFocused) {
          return;
        }

        dataList.addAll(nextPageResponse['data'] as List<dynamic>? ?? const []);
      }

      final liveList = liveResponse['locations'] as List<dynamic>? ?? [];

      // Index live locations by device_id for O(1) lookup.
      final liveByDeviceId = <int, Map<String, dynamic>>{};
      for (final loc in liveList) {
        if (loc is Map<String, dynamic>) {
          final id = loc['device_id'] as int?;
          if (id != null) liveByDeviceId[id] = loc;
        }
      }

      _tractors = _mergeTractorsWithLive(dataList, liveByDeviceId);
      _error = null;
    } catch (e) {
      if (
          requestId != _latestAllRequestId ||
          sessionId != _pollSessionId ||
          isFocused) {
        return;
      }

      _error = 'Failed to load tractors';
      debugPrint('TractorProvider._fetchAll error: $e');
    } finally {
      if (
          requestId == _latestAllRequestId &&
          sessionId == _pollSessionId &&
          !isFocused) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  int _extractLastPage(Map<String, dynamic> response) {
    final topLevelLastPage = (response['last_page'] as num?)?.toInt();
    if (topLevelLastPage != null && topLevelLastPage > 0) {
      return topLevelLastPage;
    }

    final meta = response['meta'];
    if (meta is Map<String, dynamic>) {
      final metaLastPage = (meta['last_page'] as num?)?.toInt();
      if (metaLastPage != null && metaLastPage > 0) {
        return metaLastPage;
      }
    }

    if (meta is Map) {
      final normalizedMeta = Map<String, dynamic>.from(meta);
      final metaLastPage = (normalizedMeta['last_page'] as num?)?.toInt();
      if (metaLastPage != null && metaLastPage > 0) {
        return metaLastPage;
      }
    }

    return 1;
  }

  /// Fetch only the focused tractor's real-time location (10s polling).
  /// Uses the direct follow endpoint — no cache on the server.
  Future<void> _fetchFocused() async {
    final requestId = ++_latestFocusedRequestId;
    final sessionId = _pollSessionId;
    final focusedId = _focusedTractorId;
    if (focusedId == null) return;

    // Find the device_id for the focused tractor.
    final focused = _tractors.cast<TractorLocation?>().firstWhere(
          (t) => t?.id == focusedId,
          orElse: () => null,
        );
    if (focused == null || focused.deviceId == null) return;

    try {
      final response = await _apiClient.get(
        '${AppEndpoints.devicesFollow}/${focused.deviceId}',
      );

      final live = response['location'] as Map<String, dynamic>?;

      if (
          requestId != _latestFocusedRequestId ||
          sessionId != _pollSessionId ||
          _focusedTractorId != focusedId) {
        return;
      }

      // Update only the focused tractor in the list.
      _tractors = _tractors.map((t) {
        if (t.id != focusedId) return t;

        return _mergeLiveIntoTractor(
          t,
          live,
          keepLastKnownLocationOnMissing: true,
        );
      }).toList(growable: false);

      _error = null;
    } catch (e) {
      if (
          requestId != _latestFocusedRequestId ||
          sessionId != _pollSessionId ||
          _focusedTractorId != focusedId) {
        return;
      }

      debugPrint('TractorProvider._fetchFocused error: $e');
    } finally {
      if (
          requestId == _latestFocusedRequestId &&
          sessionId == _pollSessionId &&
          _focusedTractorId == focusedId) {
        notifyListeners();
      }
    }
  }

  /// Merge tractor metadata with live GPS data.
  List<TractorLocation> _mergeTractorsWithLive(
    List<dynamic> dataList,
    Map<int, Map<String, dynamic>> liveByDeviceId,
  ) {
    return dataList.whereType<Map<String, dynamic>>().map((json) {
      final tractor = TractorLocation.fromTractorJson(
        json,
        includeDeviceLocation: false,
      );

      // Merge live GPS if available for this tractor's device.
      final live = tractor.deviceId != null
          ? liveByDeviceId[tractor.deviceId]
          : null;

      return _mergeLiveIntoTractor(tractor, live);
    }).toList(growable: false);
  }

  TractorLocation _mergeLiveIntoTractor(
    TractorLocation tractor,
    Map<String, dynamic>? live, {
    bool keepLastKnownLocationOnMissing = false,
  }) {
    if (live == null) {
      return TractorLocation(
        id: tractor.id,
        noPlate: tractor.noPlate,
        brand: tractor.brand,
        model: tractor.model,
        isOnline: false,
        lat: keepLastKnownLocationOnMissing ? tractor.lat : 0,
        lng: keepLastKnownLocationOnMissing ? tractor.lng : 0,
        speed: null,
        direction: null,
        heartbeatAt:
            keepLastKnownLocationOnMissing ? tractor.heartbeatAt : null,
        deviceId: tractor.deviceId,
        imei: tractor.imei,
      );
    }

    return TractorLocation(
      id: tractor.id,
      noPlate: tractor.noPlate,
      brand: tractor.brand,
      model: tractor.model,
      isOnline: (live['status'] as int?) == 1,
      lat: (live['lat'] as num?)?.toDouble() ?? tractor.lat,
      lng: (live['lng'] as num?)?.toDouble() ?? tractor.lng,
      speed: (live['speed'] as num?)?.toDouble(),
      direction: (live['direction'] as num?)?.toDouble(),
      heartbeatAt: live['heartbeat_at']?.toString(),
      deviceId: tractor.deviceId,
      imei: tractor.imei,
    );
  }

  /// Create a share link for a device.
  Future<Map<String, dynamic>?> createShare(int deviceId,
      {int duration = 1}) async {
    try {
      final response = await _apiClient.post(
        AppEndpoints.devicesShare,
        data: {'device_id': deviceId, 'duration': duration},
      );
      return response;
    } catch (e) {
      debugPrint('TractorProvider.createShare error: $e');
      return null;
    }
  }

  /// Fetch track data for a device.
  Future<Map<String, dynamic>?> fetchTrackData(
    int deviceId,
    String period, {
    String? from,
    String? to,
  }) async {
    try {
      final params = <String, dynamic>{
        'device_id': deviceId.toString(),
        'period': period,
      };
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;

      return await _apiClient.get(
        AppEndpoints.devicesTrackData,
        queryParameters: params,
      );
    } catch (e) {
      debugPrint('TractorProvider.fetchTrackData error: $e');
      return null;
    }
  }

  /// Start polling. Safe to call multiple times.
  /// Uses wall-clock timestamps so the countdown survives app backgrounding.
  void startPolling({bool fetchImmediately = true}) {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();

    final now = DateTime.now();
    final bool overdue = _nextPollAt != null && _nextPollAt!.isBefore(now);

    // Fetch immediately on first start or if we're overdue from background.
    if (fetchImmediately && (_nextPollAt == null || overdue)) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_pollTimer == null) return; // stopped before callback ran
        fetch();
      });
    }

    _nextPollAt = now.add(_activeInterval);

    _pollTimer = Timer.periodic(_activeInterval, (_) {
      _nextPollAt = DateTime.now().add(_activeInterval);
      fetch();
    });

    // Defer countdown start to avoid notifyListeners() during build phase.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_pollTimer == null) return;
      _startCountdown();
    });
  }

  /// Stop polling (e.g. when screen is not visible).
  void stopPolling() {
    _pollSessionId += 1;
    _pollTimer?.cancel();
    _pollTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    // Keep _nextPollAt so we know whether we're overdue on resume.
    _secondsUntilPoll = 0;
    notifyListeners();
  }

  void _restartPolling({bool fetchImmediately = true}) {
    if (_pollTimer != null) {
      startPolling(fetchImmediately: fetchImmediately);
    }
  }

  /// Countdown driven by wall-clock difference — never drifts or stalls.
  void _startCountdown() {
    _countdownTimer?.cancel();

    // Immediately compute current value.
    _updateCountdownValue();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdownValue();
    });
  }

  void _updateCountdownValue() {
    if (_nextPollAt == null) {
      if (_secondsUntilPoll != 0) {
        _secondsUntilPoll = 0;
        notifyListeners();
      }
      return;
    }
    final remaining = _nextPollAt!.difference(DateTime.now()).inSeconds;
    final clamped = remaining.clamp(0, _activeInterval.inSeconds);
    if (clamped != _secondsUntilPoll) {
      _secondsUntilPoll = clamped;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
