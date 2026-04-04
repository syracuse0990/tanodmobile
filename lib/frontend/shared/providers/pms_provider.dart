import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/models/domain/pms_record.dart';

class PmsProvider extends ChangeNotifier {
  PmsProvider({required ApiClient apiClient, required Dio dio})
    : _apiClient = apiClient,
      _dio = dio;

  final ApiClient _apiClient;
  final Dio _dio;

  List<PmsRecord> _records = [];
  List<PmsChecklistItem> _defaultChecklist = [];
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  List<PmsRecord> get records => _records;
  List<PmsChecklistItem> get defaultChecklist => _defaultChecklist;
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

  /// Fetch PMS checklist item names from API.
  Future<void> fetchChecklist() async {
    if (_defaultChecklist.isNotEmpty) return;

    try {
      final response = await _apiClient.get(
        AppEndpoints.maintenancesChecklist,
      );
      final dataList = response['data'] as List<dynamic>? ?? [];
      _defaultChecklist = dataList
          .whereType<Map<String, dynamic>>()
          .map((json) => PmsChecklistItem(name: json['name']?.toString() ?? ''))
          .toList(growable: false);
      _safeNotify();
    } catch (e) {
      debugPrint('PmsProvider.fetchChecklist error: $e');
    }
  }

  /// Fetch PMS records for a specific tractor.
  Future<void> fetchRecordsForTractor(int tractorId) async {
    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final response = await _apiClient.get(
        AppEndpoints.maintenances,
        queryParameters: {'tractor_id': '$tractorId', 'per_page': '50'},
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _records = dataList
          .whereType<Map<String, dynamic>>()
          .map(PmsRecord.fromJson)
          .toList(growable: false);
      _error = null;
    } catch (e) {
      _error = 'Failed to load PMS records';
      debugPrint('PmsProvider.fetchRecordsForTractor error: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  /// FCA records PMS themselves.
  Future<bool> recordPms({
    required int tractorId,
    required List<PmsChecklistItem> checklist,
    required double hoursAtMaintenance,
    required double kmAtMaintenance,
    String? description,
    List<File> images = const [],
  }) async {
    _submitting = true;
    _error = null;
    _safeNotify();

    try {
      final formMap = <String, dynamic>{
        'tractor_id': tractorId,
        'type': 'record',
        'hours_at_maintenance': hoursAtMaintenance,
        'km_at_maintenance': kmAtMaintenance,
        if (description != null && description.isNotEmpty)
          'description': description,
      };

      // Add checklist items
      for (var i = 0; i < checklist.length; i++) {
        formMap['pms_checklist[$i][name]'] = checklist[i].name;
        formMap['pms_checklist[$i][done]'] = checklist[i].done ? '1' : '0';
        if (checklist[i].notes != null && checklist[i].notes!.isNotEmpty) {
          formMap['pms_checklist[$i][notes]'] = checklist[i].notes;
        }
      }

      // Add images
      for (var i = 0; i < images.length; i++) {
        formMap['images[$i]'] = await MultipartFile.fromFile(
          images[i].path,
          filename: images[i].path.split(Platform.pathSeparator).last,
        );
      }

      final formData = FormData.fromMap(formMap);

      await _dio.post(
        AppEndpoints.maintenances,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      _submitting = false;
      _safeNotify();
      return true;
    } catch (e) {
      _error = 'Failed to record PMS';
      debugPrint('PmsProvider.recordPms error: $e');
      _submitting = false;
      _safeNotify();
      return false;
    }
  }

  /// FCA requests TPS assistance.
  Future<bool> requestTpsHelp({
    required int tractorId,
    String? requestNotes,
  }) async {
    _submitting = true;
    _error = null;
    _safeNotify();

    try {
      await _apiClient.post(
        AppEndpoints.maintenances,
        data: {
          'tractor_id': tractorId,
          'type': 'request',
          if (requestNotes != null && requestNotes.isNotEmpty)
            'request_notes': requestNotes,
        },
      );

      _submitting = false;
      _safeNotify();
      return true;
    } catch (e) {
      _error = 'Failed to send request';
      debugPrint('PmsProvider.requestTpsHelp error: $e');
      _submitting = false;
      _safeNotify();
      return false;
    }
  }

  /// TPS completes a PMS request.
  Future<bool> completePms({
    required int maintenanceId,
    required List<PmsChecklistItem> checklist,
    String? description,
    String? conclusion,
    List<File> images = const [],
  }) async {
    _submitting = true;
    _error = null;
    _safeNotify();

    try {
      final formMap = <String, dynamic>{
        if (description != null && description.isNotEmpty)
          'description': description,
        if (conclusion != null && conclusion.isNotEmpty)
          'conclusion': conclusion,
      };

      for (var i = 0; i < checklist.length; i++) {
        formMap['pms_checklist[$i][name]'] = checklist[i].name;
        formMap['pms_checklist[$i][done]'] = checklist[i].done ? '1' : '0';
        if (checklist[i].notes != null && checklist[i].notes!.isNotEmpty) {
          formMap['pms_checklist[$i][notes]'] = checklist[i].notes;
        }
      }

      for (var i = 0; i < images.length; i++) {
        formMap['images[$i]'] = await MultipartFile.fromFile(
          images[i].path,
          filename: images[i].path.split(Platform.pathSeparator).last,
        );
      }

      final formData = FormData.fromMap(formMap);

      await _dio.post(
        '${AppEndpoints.maintenances}/$maintenanceId/complete',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      _submitting = false;
      _safeNotify();
      return true;
    } catch (e) {
      _error = 'Failed to complete PMS';
      debugPrint('PmsProvider.completePms error: $e');
      _submitting = false;
      _safeNotify();
      return false;
    }
  }
}
