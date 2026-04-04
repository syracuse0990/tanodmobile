import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/models/domain/maintenance_tractor.dart';

class MaintenanceProvider extends ChangeNotifier {
  MaintenanceProvider({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  List<MaintenanceTractor> _tractors = [];
  bool _loading = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;

  List<MaintenanceTractor> get tractors => _tractors;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasMore => _currentPage < _lastPage;

  int get dueCount => _tractors.where((t) => t.isPmsDue).length;
  int get upcomingCount => _tractors.where((t) => t.isPmsUpcoming).length;

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

  Future<void> fetchTractors() async {
    _loading = true;
    _error = null;
    _currentPage = 1;
    _safeNotify();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tractors,
        queryParameters: {'per_page': '100'},
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _tractors = dataList
          .whereType<Map<String, dynamic>>()
          .map((json) => MaintenanceTractor.fromJson(json))
          .toList(growable: false);

      _lastPage = (response['meta']?['last_page'] as int?) ?? 1;
      _currentPage = 1;
      _error = null;
    } catch (e) {
      _error = 'Failed to load tractors';
      debugPrint('MaintenanceProvider.fetchTractors error: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> fetchMore() async {
    if (_loading || !hasMore) return;
    _loading = true;
    _safeNotify();

    try {
      final nextPage = _currentPage + 1;
      final response = await _apiClient.get(
        AppEndpoints.tractors,
        queryParameters: {'per_page': '100', 'page': '$nextPage'},
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      final newTractors = dataList
          .whereType<Map<String, dynamic>>()
          .map((json) => MaintenanceTractor.fromJson(json))
          .toList(growable: false);

      _tractors = [..._tractors, ...newTractors];
      _lastPage = (response['meta']?['last_page'] as int?) ?? 1;
      _currentPage = nextPage;
    } catch (e) {
      debugPrint('MaintenanceProvider.fetchMore error: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }
}
