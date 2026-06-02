import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/models/domain/maintenance_tractor.dart';

class MaintenanceProvider extends ChangeNotifier {
  MaintenanceProvider({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const int defaultPageSize = 100;

  final ApiClient _apiClient;

  List<MaintenanceTractor> _tractors = [];
  bool _loading = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  int _pageSize = defaultPageSize;
  String _searchQuery = '';

  List<MaintenanceTractor> get tractors => _tractors;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasMore => _currentPage < _lastPage;
  String get searchQuery => _searchQuery;

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

  Map<String, dynamic> _queryParameters({
    required int page,
    int? pageSize,
  }) {
    final normalizedSearch = _searchQuery.trim();
    final effectivePageSize = pageSize ?? _pageSize;

    return {
      'per_page': '$effectivePageSize',
      'page': '$page',
      if (normalizedSearch.isNotEmpty) 'search': normalizedSearch,
    };
  }

  Future<void> setSearchQuery(String query, {int? pageSize}) async {
    final normalizedQuery = query.trim();
    final effectivePageSize = pageSize ?? _pageSize;

    if (_searchQuery == normalizedQuery && _pageSize == effectivePageSize) {
      return;
    }

    _pageSize = effectivePageSize;
    _searchQuery = normalizedQuery;
    _tractors = [];
    _currentPage = 1;
    _lastPage = 1;
    _safeNotify();
    await fetchTractors(pageSize: effectivePageSize);
  }

  Future<void> fetchTractors({int pageSize = defaultPageSize}) async {
    _pageSize = pageSize;
    _loading = true;
    _error = null;
    _currentPage = 1;
    _safeNotify();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tractors,
        queryParameters: _queryParameters(page: 1, pageSize: pageSize),
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _tractors = dataList
          .whereType<Map<String, dynamic>>()
          .map((json) => MaintenanceTractor.fromJson(json))
          .toList(growable: false);

      _lastPage = (response['meta']?['last_page'] as int?) ?? 1;
      _currentPage = (response['meta']?['current_page'] as int?) ?? 1;
      _error = null;
    } catch (e) {
      _error = 'Failed to load tractors';
      debugPrint('MaintenanceProvider.fetchTractors error: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> fetchMore({int? pageSize}) async {
    if (_loading || !hasMore) return;

    final effectivePageSize = pageSize ?? _pageSize;
    _pageSize = effectivePageSize;
    _loading = true;
    _safeNotify();

    try {
      final nextPage = _currentPage + 1;
      final response = await _apiClient.get(
        AppEndpoints.tractors,
        queryParameters: _queryParameters(
          page: nextPage,
          pageSize: effectivePageSize,
        ),
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      final newTractors = dataList
          .whereType<Map<String, dynamic>>()
          .map((json) => MaintenanceTractor.fromJson(json))
          .toList(growable: false);

      _tractors = [..._tractors, ...newTractors];
      _lastPage = (response['meta']?['last_page'] as int?) ?? 1;
      _currentPage = (response['meta']?['current_page'] as int?) ?? nextPage;
    } catch (e) {
      debugPrint('MaintenanceProvider.fetchMore error: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }
}
