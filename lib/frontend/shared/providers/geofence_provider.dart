import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/models/domain/geo_fence.dart';

class GeoFenceProvider extends ChangeNotifier {
  GeoFenceProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  List<GeoFence> _geofences = [];
  List<GeoFenceDevice> _availableDevices = [];
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  List<GeoFence> get geofences => _geofences;
  List<GeoFenceDevice> get availableDevices => _availableDevices;
  bool get loading => _loading;
  bool get submitting => _submitting;
  String? get error => _error;

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

  /// Fetch all geofences accessible to the user.
  Future<void> fetchGeofences() async {
    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final response = await _apiClient.get(
        AppEndpoints.geofences,
        queryParameters: {'per_page': '50'},
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _geofences = dataList
          .whereType<Map<String, dynamic>>()
          .map(GeoFence.fromJson)
          .toList(growable: false);
      _error = null;
    } catch (e) {
      _error = 'Failed to load geofences';
      debugPrint('GeoFenceProvider.fetchGeofences error: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  /// Fetch available devices the user can assign to a geofence.
  Future<void> fetchAvailableDevices() async {
    try {
      final response = await _apiClient.get(AppEndpoints.geofenceDevices);
      final dataList = response['data'] as List<dynamic>? ?? [];
      _availableDevices = dataList
          .whereType<Map<String, dynamic>>()
          .map(GeoFenceDevice.fromJson)
          .toList(growable: false);
      _safeNotify();
    } catch (e) {
      debugPrint('GeoFenceProvider.fetchAvailableDevices error: $e');
    }
  }

  /// Fetch a single geofence detail.
  Future<GeoFence?> fetchGeofenceDetail(int id) async {
    try {
      final response = await _apiClient.get('${AppEndpoints.geofences}/$id');
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        return GeoFence.fromJson(data);
      }
    } catch (e) {
      debugPrint('GeoFenceProvider.fetchGeofenceDetail error: $e');
    }
    return null;
  }

  /// Create a new geofence.
  Future<bool> createGeofence({
    required String name,
    required String shape,
    required String alertOn,
    required List<int> deviceIds,
    double? centerLat,
    double? centerLng,
    double? radius,
    List<GeoFenceCoordinate>? coordinates,
  }) async {
    _submitting = true;
    _error = null;
    _safeNotify();

    try {
      final data = <String, dynamic>{
        'name': name,
        'shape': shape,
        'alert_on': alertOn,
        'device_ids': deviceIds,
      };

      if (shape == 'circle') {
        data['center_lat'] = centerLat;
        data['center_lng'] = centerLng;
        data['radius'] = radius;
      } else {
        data['coordinates'] =
            coordinates?.map((c) => c.toJson()).toList() ?? [];
      }

      await _apiClient.post(AppEndpoints.geofences, data: data);

      _submitting = false;
      _safeNotify();
      return true;
    } catch (e) {
      _error = 'Failed to create geofence';
      debugPrint('GeoFenceProvider.createGeofence error: $e');
      _submitting = false;
      _safeNotify();
      return false;
    }
  }

  /// Update an existing geofence.
  Future<bool> updateGeofence({
    required int id,
    required String name,
    required String shape,
    required String alertOn,
    required List<int> deviceIds,
    double? centerLat,
    double? centerLng,
    double? radius,
    List<GeoFenceCoordinate>? coordinates,
  }) async {
    _submitting = true;
    _error = null;
    _safeNotify();

    try {
      final data = <String, dynamic>{
        'name': name,
        'shape': shape,
        'alert_on': alertOn,
        'device_ids': deviceIds,
      };

      if (shape == 'circle') {
        data['center_lat'] = centerLat;
        data['center_lng'] = centerLng;
        data['radius'] = radius;
      } else {
        data['coordinates'] =
            coordinates?.map((c) => c.toJson()).toList() ?? [];
      }

      await _apiClient.put('${AppEndpoints.geofences}/$id', data: data);

      _submitting = false;
      _safeNotify();
      return true;
    } catch (e) {
      _error = 'Failed to update geofence';
      debugPrint('GeoFenceProvider.updateGeofence error: $e');
      _submitting = false;
      _safeNotify();
      return false;
    }
  }

  /// Delete a geofence.
  Future<bool> deleteGeofence(int id) async {
    try {
      await _apiClient.delete('${AppEndpoints.geofences}/$id');
      _geofences = _geofences.where((g) => g.id != id).toList();
      _safeNotify();
      return true;
    } catch (e) {
      debugPrint('GeoFenceProvider.deleteGeofence error: $e');
      return false;
    }
  }
}
