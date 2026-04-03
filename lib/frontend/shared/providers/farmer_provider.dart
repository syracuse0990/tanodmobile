import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';

class FarmerProvider extends ChangeNotifier {
  FarmerProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  List<Map<String, dynamic>> _farmers = [];
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  List<Map<String, dynamic>> get farmers => _farmers;
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

  Future<void> fetchFarmers() async {
    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final response = await _apiClient.get(AppEndpoints.myFarmers);
      final dataList = response is List
          ? response as List<dynamic>
          : (response['data'] as List<dynamic>? ?? []);
      _farmers = dataList.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      _error = 'Failed to load farmers';
      debugPrint('FarmerProvider.fetchFarmers error: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<bool> addFarmer({
    required String name,
    required String phone,
    String? email,
  }) async {
    _submitting = true;
    _safeNotify();

    try {
      final response = await _apiClient.post(
        AppEndpoints.myFarmers,
        data: {
          'name': name,
          'phone': phone,
          if (email != null && email.isNotEmpty) 'email': email,
        },
      );

      _farmers = [response, ..._farmers];

      return true;
    } catch (e) {
      debugPrint('FarmerProvider.addFarmer error: $e');
      return false;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }

  Future<bool> updateFarmer({
    required int farmerId,
    required String name,
    required String phone,
    String? email,
  }) async {
    _submitting = true;
    _safeNotify();

    try {
      await _apiClient.put(
        '${AppEndpoints.myFarmers}/$farmerId',
        data: {
          'name': name,
          'phone': phone,
          if (email != null && email.isNotEmpty) 'email': email,
        },
      );

      final index = _farmers.indexWhere((f) => f['id'] == farmerId);
      if (index != -1) {
        _farmers[index] = {
          ..._farmers[index],
          'name': name,
          'phone': phone,
          'email': email,
        };
      }

      return true;
    } catch (e) {
      debugPrint('FarmerProvider.updateFarmer error: $e');
      return false;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }

  Future<bool> removeFarmer(int farmerId) async {
    try {
      await _apiClient.delete('${AppEndpoints.myFarmers}/$farmerId');
      _farmers = _farmers.where((f) => f['id'] != farmerId).toList();
      _safeNotify();
      return true;
    } catch (e) {
      debugPrint('FarmerProvider.removeFarmer error: $e');
      return false;
    }
  }

  List<Map<String, dynamic>> search(String query) {
    if (query.isEmpty) return _farmers;
    final q = query.toLowerCase();
    return _farmers
        .where((f) =>
            (f['name']?.toString().toLowerCase().contains(q) ?? false) ||
            (f['phone']?.toString().toLowerCase().contains(q) ?? false) ||
            (f['email']?.toString().toLowerCase().contains(q) ?? false))
        .toList();
  }
}
