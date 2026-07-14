import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/core/constants/hive_boxes.dart';
import 'package:tanodmobile/models/local/offline_ticket_draft.dart';
import 'package:tanodmobile/services/connectivity/connectivity_service.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

class OfflineTicketProvider extends ChangeNotifier {
  OfflineTicketProvider({
    required HiveService hiveService,
    required ApiClient apiClient,
    required ConnectivityService connectivityService,
  })  : _hiveService = hiveService,
        _apiClient = apiClient,
        _connectivityService = connectivityService {
    _loadDrafts();
    _loadCachedTractors();
    _watchConnectivity();
  }

  final HiveService _hiveService;
  final ApiClient _apiClient;
  final ConnectivityService _connectivityService;

  List<OfflineTicketDraft> _drafts = [];
  List<Map<String, dynamic>> _cachedTractors = [];
  bool _loading = false;
  bool _isOnline = true;
  bool _justSynced = false;
  StreamSubscription<bool>? _connectivitySub;

  List<OfflineTicketDraft> get drafts => _drafts;
  List<OfflineTicketDraft> get pendingDrafts =>
      _drafts.where((d) => !d.synced).toList(growable: false);
  List<OfflineTicketDraft> get syncedDrafts =>
      _drafts.where((d) => d.synced).toList(growable: false);
  bool get loading => _loading;
  bool get isOnline => _isOnline;
  int get pendingCount => pendingDrafts.length;
  bool get justSynced => _justSynced;
  List<Map<String, dynamic>> get cachedTractors => _cachedTractors;

  /// Saves tractor list locally so dropdown works offline.
  Future<void> cacheTractors(List<Map<String, dynamic>> tractors) async {
    _cachedTractors = tractors;
    await _hiveService.savePreference(
      HiveBoxes.offlineTicketCachedTractorsKey,
      jsonEncode(tractors),
    );
    notifyListeners();
  }

  void _loadCachedTractors() {
    final raw = _hiveService.getPreference(HiveBoxes.offlineTicketCachedTractorsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _cachedTractors = decoded.cast<Map<String, dynamic>>();
      } catch (_) {
        _cachedTractors = [];
      }
    }
  }

  void _loadDrafts() {
    final raw = _hiveService.getPreference(HiveBoxes.offlineTicketDraftsKey);
    if (raw != null && raw.isNotEmpty) {
      _drafts = [...OfflineTicketDraft.listFromJson(raw)];
    }
    notifyListeners();
  }

  void _persistDrafts() {
    _hiveService.savePreference(
      HiveBoxes.offlineTicketDraftsKey,
      OfflineTicketDraft.listToJson(_drafts),
    );
  }

  void _watchConnectivity() {
    _connectivitySub = _connectivityService.watchConnectivity().listen((online) {
      _isOnline = online;
      notifyListeners();
      if (online) {
        _syncPendingDrafts();
        _fetchAndCacheTractors();
      }
    });
    _connectivityService.isConnected().then((online) {
      _isOnline = online;
      notifyListeners();
      if (online) {
        // Delay initial fetch to let auth complete first
        _retryFetchTractors();
      }
    });
  }

  /// Retries fetching tractors with a delay to allow auth to complete.
  Future<void> _retryFetchTractors({int attempt = 1}) async {
    await Future.delayed(Duration(seconds: attempt * 2));
    await _fetchAndCacheTractors();
    if (_cachedTractors.isEmpty && attempt < 3) {
      await _retryFetchTractors(attempt: attempt + 1);
    }
  }

  /// Fetches tractors from API and saves locally for offline use.
  Future<void> _fetchAndCacheTractors() async {
    try {
      final response = await _apiClient.get(
        AppEndpoints.tractors,
        queryParameters: {'per_page': '200'},
      );
      final rawList = response['data'] as List<dynamic>? ?? [];
      final tractors = rawList.whereType<Map<String, dynamic>>().toList();
      if (tractors.isNotEmpty) {
        await cacheTractors(tractors);
      }
    } catch (_) {
      // Silently fail - retryFetchTractors will retry if cache is still empty
    }
  }

  /// Manually refresh cached tractors (called from UI screens)
  Future<void> refreshCachedTractors() async {
    if (_isOnline) {
      await _fetchAndCacheTractors();
    }
  }

  /// Reset the justSynced flag after navigation
  void resetJustSynced() {
    _justSynced = false;
    notifyListeners();
  }

  Future<void> saveDraft(OfflineTicketDraft draft) async {
    final existingIndex = _drafts.indexWhere((d) => d.id == draft.id);
    final updated = draft.copyWith(
      updatedAt: DateTime.now(),
      synced: false,
    );
    final List<OfflineTicketDraft> newList = [];
    if (existingIndex >= 0) {
      newList.addAll(_drafts);
      newList[existingIndex] = updated;
    } else {
      newList.add(updated);
      newList.addAll(_drafts);
    }
    _drafts = newList;
    _persistDrafts();
    notifyListeners();
  }

  Future<void> deleteDraft(String draftId) async {
    _drafts = _drafts.where((d) => d.id != draftId).toList();
    _persistDrafts();
    notifyListeners();
  }

  Future<void> _syncPendingDrafts() async {
    final pending = pendingDrafts;
    if (pending.isEmpty) return;

    _loading = true;
    _justSynced = false;
    notifyListeners();

    for (final draft in pending) {
      try {
        final hasPhotos = draft.nameplatePhotoPath != null ||
            draft.dashboardPhotoPath != null ||
            draft.damagePhotoPaths.isNotEmpty;

        if (hasPhotos) {
          await _syncDraftWithPhotos(draft);
        } else {
          await _apiClient.post(
            AppEndpoints.tickets,
            data: draft.payload,
          );
        }

        // Remove draft after successful sync
        _drafts = _drafts.where((d) => d.id != draft.id).toList();
      } catch (e) {
        debugPrint('OfflineTicketProvider._syncPendingDrafts error: $e');
        break;
      }
    }

    _persistDrafts();
    _loading = false;
    if (pendingCount == 0) {
      _justSynced = true;
    }
    notifyListeners();
  }

  /// Sync a draft that has photos using multipart upload.
  Future<void> _syncDraftWithPhotos(OfflineTicketDraft draft) async {
    final formMap = <String, dynamic>{
      'subject': draft.subject,
      'description': draft.description ?? '',
      if (draft.category != null) 'category': draft.category,
      if (draft.tractorId != null) 'tractor_id': draft.tractorId,
      if (draft.dateOfFailure != null)
        'reported_date': draft.dateOfFailure!.toIso8601String().split('T').first,
      if (draft.actionTaken != null) 'action_taken': draft.actionTaken,
    };

    if (draft.nameplatePhotoPath != null) {
      formMap['nameplate_photo'] = await MultipartFile.fromFile(
        draft.nameplatePhotoPath!,
        filename: draft.nameplatePhotoPath!.split(Platform.pathSeparator).last,
      );
    }
    if (draft.dashboardPhotoPath != null) {
      formMap['dashboard_photo'] = await MultipartFile.fromFile(
        draft.dashboardPhotoPath!,
        filename: draft.dashboardPhotoPath!.split(Platform.pathSeparator).last,
      );
    }
    if (draft.damagePhotoPaths.isNotEmpty) {
      for (var i = 0; i < draft.damagePhotoPaths.length; i++) {
        formMap['damage_photos[$i]'] = await MultipartFile.fromFile(
          draft.damagePhotoPaths[i],
          filename: draft.damagePhotoPaths[i].split(Platform.pathSeparator).last,
        );
      }
    }

    final formData = FormData.fromMap(formMap);
    await _apiClient.postMultipart(
      AppEndpoints.tickets,
      formData: formData,
    );
  }

  /// Manually trigger sync (called from UI)
  Future<void> syncNow() async {
    if (!_isOnline) return;
    await _syncPendingDrafts();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
