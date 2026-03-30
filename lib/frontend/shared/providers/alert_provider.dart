import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/models/domain/alert.dart';

class AlertProvider extends ChangeNotifier {
  AlertProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  static const _pollInterval = Duration(minutes: 2);

  Timer? _pollTimer;

  List<Alert> _alerts = [];
  bool _loading = false;
  String? _error;
  int _unacknowledgedCount = 0;
  int _currentPage = 1;
  int _lastPage = 1;
  String? _typeFilter;

  List<Alert> get alerts => _alerts;
  bool get loading => _loading;
  String? get error => _error;
  int get unacknowledgedCount => _unacknowledgedCount;
  bool get hasMore => _currentPage < _lastPage;
  String? get typeFilter => _typeFilter;

  /// Set a type filter and refresh (null = all).
  void setFilter(String? type) {
    if (_typeFilter == type) return;
    _typeFilter = type;
    _alerts = [];
    _currentPage = 1;
    _lastPage = 1;
    notifyListeners();
    fetchAlerts();
  }

  /// Fetch first page of alerts.
  Future<void> fetchAlerts() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{'per_page': '20', 'page': '1'};
      if (_typeFilter != null) params['type'] = _typeFilter!;

      final response = await _apiClient.get(
        AppEndpoints.alerts,
        queryParameters: params,
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _alerts = dataList
          .whereType<Map<String, dynamic>>()
          .map(Alert.fromJson)
          .toList();
      _currentPage = (response['current_page'] as num?)?.toInt() ?? 1;
      _lastPage = (response['last_page'] as num?)?.toInt() ?? 1;
      _error = null;
    } catch (e) {
      _error = 'Failed to load alerts';
      debugPrint('AlertProvider.fetchAlerts error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Load next page (pagination).
  Future<void> fetchMore() async {
    if (!hasMore || _loading) return;

    _loading = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final params = <String, dynamic>{
        'per_page': '20',
        'page': nextPage.toString(),
      };
      if (_typeFilter != null) params['type'] = _typeFilter!;

      final response = await _apiClient.get(
        AppEndpoints.alerts,
        queryParameters: params,
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      final newAlerts = dataList
          .whereType<Map<String, dynamic>>()
          .map(Alert.fromJson)
          .toList();
      _alerts = [..._alerts, ...newAlerts];
      _currentPage = nextPage;
      _lastPage = (response['last_page'] as num?)?.toInt() ?? _lastPage;
    } catch (e) {
      debugPrint('AlertProvider.fetchMore error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetch unacknowledged count (for badge).
  Future<void> fetchUnacknowledgedCount() async {
    try {
      final response = await _apiClient.get(
        '${AppEndpoints.alerts}/unacknowledged-count',
      );
      _unacknowledgedCount =
          (response['unacknowledged_count'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('AlertProvider.fetchUnacknowledgedCount error: $e');
    }
  }

  /// Acknowledge an alert.
  Future<bool> acknowledge(int alertId) async {
    try {
      await _apiClient.post('${AppEndpoints.alerts}/$alertId/acknowledge');

      // Update local state.
      final index = _alerts.indexWhere((a) => a.id == alertId);
      if (index != -1) {
        final old = _alerts[index];
        _alerts[index] = Alert(
          id: old.id,
          type: old.type,
          title: old.title,
          message: old.message,
          isAcknowledged: true,
          createdAt: old.createdAt,
          tractorId: old.tractorId,
          tractorLabel: old.tractorLabel,
          deviceId: old.deviceId,
          meta: old.meta,
        );
        if (_unacknowledgedCount > 0) _unacknowledgedCount--;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('AlertProvider.acknowledge error: $e');
      return false;
    }
  }

  /// Start polling for new alerts.
  void startPolling() {
    _pollTimer?.cancel();
    fetchAlerts();
    fetchUnacknowledgedCount();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      fetchAlerts();
      fetchUnacknowledgedCount();
    });
  }

  /// Stop polling.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
