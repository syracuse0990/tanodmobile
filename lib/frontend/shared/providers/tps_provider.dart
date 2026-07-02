import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/core/utils/url_helper.dart';
import 'package:tanodmobile/core/constants/hive_boxes.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/models/domain/distribution.dart';
import 'package:tanodmobile/models/domain/farmer_feedback.dart';
import 'package:tanodmobile/models/domain/fca_tractor_option.dart';
import 'package:tanodmobile/models/domain/location_option.dart';
import 'package:tanodmobile/models/domain/ticket.dart';
import 'package:tanodmobile/models/domain/tps_user_option.dart';
import 'package:tanodmobile/models/domain/tps_fca.dart';
import 'package:tanodmobile/models/local/offline_distribution_draft.dart';
import 'package:tanodmobile/models/local/offline_fca_draft.dart';
import 'package:tanodmobile/models/local/offline_location_cache_summary.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

class TpsProvider extends ChangeNotifier {
  TpsProvider({
    required ApiClient apiClient,
    required Dio dio,
    required HiveService hiveService,
  }) : _apiClient = apiClient,
       _dio = dio,
       _hiveService = hiveService;

  final ApiClient _apiClient;
  final Dio _dio;
  final HiveService _hiveService;

  static const _offlineSyncPerPage = 100;

  // Dashboard stats
  int tractorsCount = 0;
  int openTickets = 0;
  int pendingMaintenance = 0;
  int activeDistributions = 0;
  bool _dashboardLoading = false;
  bool get dashboardLoading => _dashboardLoading;

  // Tickets
  List<Ticket> _tickets = [];
  List<Ticket> _chatTickets = [];
  bool _ticketsLoading = false;
  bool _chatTicketsLoading = false;
  String? _ticketsError;
  String? _chatTicketsError;
  int _ticketsPage = 1;
  int _chatTicketsPage = 1;
  int _ticketsLastPage = 1;
  int _chatTicketsLastPage = 1;
  String _ticketSearchQuery = '';

  List<Ticket> get tickets => _tickets;
  List<Ticket> get chatTickets => _chatTickets;
  bool get ticketsLoading => _ticketsLoading;
  bool get chatTicketsLoading => _chatTicketsLoading;
  String? get ticketsError => _ticketsError;
  String? get chatTicketsError => _chatTicketsError;
  bool get hasMoreTickets => _ticketsPage < _ticketsLastPage;
  bool get hasMoreChatTickets => _chatTicketsPage < _chatTicketsLastPage;
  String get ticketSearchQuery => _ticketSearchQuery;

  // Feedbacks
  List<FarmerFeedbackItem> _feedbacks = [];
  bool _feedbacksLoading = false;
  int _feedbacksPage = 1;
  int _feedbacksLastPage = 1;
  String _feedbackSearchQuery = '';

  List<FarmerFeedbackItem> get feedbacks => _feedbacks;
  bool get feedbacksLoading => _feedbacksLoading;
  bool get hasMoreFeedbacks => _feedbacksPage < _feedbacksLastPage;
  String get feedbackSearchQuery => _feedbackSearchQuery;

  // Tractors
  List<Map<String, dynamic>> _tractors = [];
  bool _tractorsLoading = false;
  int _tractorsPage = 1;
  int _tractorsLastPage = 1;
  String _tractorSearchQuery = '';

  List<Map<String, dynamic>> get tractors => _tractors;
  bool get tractorsLoading => _tractorsLoading;
  bool get hasMoreTractors => _tractorsPage < _tractorsLastPage;
  String get tractorSearchQuery => _tractorSearchQuery;

  // Distributions
  List<Distribution> _distributions = [];
  bool _distributionsLoading = false;
  int _distributionsPage = 1;
  int _distributionsLastPage = 1;
  String _distributionSearchQuery = '';

  List<Distribution> get distributions => _distributions;
  bool get distributionsLoading => _distributionsLoading;
  bool get hasMoreDistributions => _distributionsPage < _distributionsLastPage;
  String get distributionSearchQuery => _distributionSearchQuery;

  // FCAs
  List<TpsFca> _fcas = [];
  bool _fcasLoading = false;
  int _fcasPage = 1;
  int _fcasLastPage = 1;
  String _fcaSearchQuery = '';
  List<OfflineDistributionDraft> _offlineDistributionDrafts = [];
  List<OfflineFcaDraft> _offlineFcaDrafts = [];
  DateTime? _offlineDistributionsSyncedAt;
  DateTime? _offlineFcasSyncedAt;
  DateTime? _offlineReferenceDataSyncedAt;
  OfflineLocationCacheSummary _offlineLocationCacheSummary =
      OfflineLocationCacheSummary.empty;

  List<TpsFca> get fcas => _fcas;
  bool get fcasLoading => _fcasLoading;
  bool get hasMoreFcas => _fcasPage < _fcasLastPage;
  String get fcaSearchQuery => _fcaSearchQuery;
  List<OfflineDistributionDraft> get offlineDistributionDrafts =>
      List.unmodifiable(_offlineDistributionDrafts);
  List<OfflineFcaDraft> get offlineFcaDrafts =>
      List.unmodifiable(_offlineFcaDrafts);
  DateTime? get offlineDistributionsSyncedAt => _offlineDistributionsSyncedAt;
  DateTime? get offlineFcasSyncedAt => _offlineFcasSyncedAt;
  DateTime? get offlineReferenceDataSyncedAt => _offlineReferenceDataSyncedAt;
  OfflineLocationCacheSummary get offlineLocationCacheSummary =>
      _offlineLocationCacheSummary;

  // ─── Dashboard ─────────────────────────────────

  Future<void> fetchDashboard() async {
    _dashboardLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(AppEndpoints.tpsDashboard);
      tractorsCount = (response['tractors_count'] as num?)?.toInt() ?? 0;
      openTickets = (response['open_tickets'] as num?)?.toInt() ?? 0;
      pendingMaintenance =
          (response['pending_maintenance'] as num?)?.toInt() ?? 0;
      activeDistributions =
          (response['active_distributions'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('TpsProvider.fetchDashboard error: $e');
    } finally {
      _dashboardLoading = false;
      notifyListeners();
    }
  }

  // ─── Tickets ───────────────────────────────────

  String _normalizeSearchQuery(String? query) => query?.trim() ?? '';

  int _extractCurrentPage(Map<String, dynamic> response) {
    final topLevelCurrentPage = (response['current_page'] as num?)?.toInt();
    if (topLevelCurrentPage != null && topLevelCurrentPage > 0) {
      return topLevelCurrentPage;
    }

    final meta = response['meta'];
    if (meta is Map<String, dynamic>) {
      final metaCurrentPage = (meta['current_page'] as num?)?.toInt();
      if (metaCurrentPage != null && metaCurrentPage > 0) {
        return metaCurrentPage;
      }
    }

    if (meta is Map) {
      final normalizedMeta = Map<String, dynamic>.from(meta);
      final metaCurrentPage = (normalizedMeta['current_page'] as num?)?.toInt();
      if (metaCurrentPage != null && metaCurrentPage > 0) {
        return metaCurrentPage;
      }
    }

    return 1;
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

  List<Map<String, dynamic>> _extractMapList(dynamic rawData) {
    final dataList = rawData as List<dynamic>? ?? const [];

    return dataList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchAllPagedRecords(String path) async {
    final firstResponse = await _apiClient.get(
      path,
      queryParameters: {
        'per_page': _offlineSyncPerPage.toString(),
        'page': '1',
      },
    );

    final records = <Map<String, dynamic>>[
      ..._extractMapList(firstResponse['data']),
    ];
    final lastPage = _extractLastPage(firstResponse);

    for (var page = 2; page <= lastPage; page++) {
      final response = await _apiClient.get(
        path,
        queryParameters: {
          'per_page': _offlineSyncPerPage.toString(),
          'page': page.toString(),
        },
      );

      records.addAll(_extractMapList(response['data']));
    }

    return records;
  }

  Future<void> _saveOfflineCollection(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    await _hiveService.savePreference(key, jsonEncode(items));
  }

  Future<void> _saveOfflineTimestamp(String key, DateTime value) async {
    await _hiveService.savePreference(key, value.toIso8601String());
  }

  DateTime? _readOfflineTimestamp(String key) {
    final raw = _hiveService.getPreference(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }

  List<Map<String, dynamic>> _readOfflineCollection(String key) {
    final raw = _hiveService.getPreference(key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String _searchHaystack(Iterable<String?> parts) {
    return parts
        .whereType<String>()
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .join(' ');
  }

  List<Distribution> _parseOfflineDistributions(String query) {
    final normalizedSearch = _normalizeSearchQuery(query).toLowerCase();
    return _readOfflineCollection(HiveBoxes.tpsOfflineDistributionsKey)
        .map(Distribution.fromJson)
        .where((item) => _matchesDistributionSearch(item, normalizedSearch))
        .toList(growable: false);
  }

  List<TpsFca> _parseOfflineFcas(String query) {
    final normalizedSearch = _normalizeSearchQuery(query).toLowerCase();
    return _readOfflineCollection(HiveBoxes.tpsOfflineFcasKey)
        .map(TpsFca.fromJson)
        .where((item) => _matchesFcaSearch(item, normalizedSearch))
        .toList(growable: false);
  }

  List<OfflineDistributionDraft> _readOfflineDistributionDrafts() {
    final raw = _hiveService.getPreference(
      HiveBoxes.tpsOfflineDistributionDraftsKey,
    );
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      final drafts = decoded
          .whereType<Map>()
          .map(
            (item) => OfflineDistributionDraft.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);

      return _sortOfflineDistributionDrafts(drafts);
    } catch (_) {
      return const [];
    }
  }

  List<OfflineDistributionDraft> _sortOfflineDistributionDrafts(
    List<OfflineDistributionDraft> drafts,
  ) {
    final sortedDrafts = [...drafts]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return sortedDrafts;
  }

  Future<void> _persistOfflineDistributionDrafts(
    List<OfflineDistributionDraft> drafts,
  ) async {
    await _hiveService.savePreference(
      HiveBoxes.tpsOfflineDistributionDraftsKey,
      jsonEncode(drafts.map((draft) => draft.toJson()).toList(growable: false)),
    );
  }

  List<OfflineFcaDraft> _readOfflineFcaDrafts() {
    final raw = _hiveService.getPreference(HiveBoxes.tpsOfflineFcaDraftsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      final drafts = decoded
          .whereType<Map>()
          .map(
            (item) => OfflineFcaDraft.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);

      return _sortOfflineFcaDrafts(drafts);
    } catch (_) {
      return const [];
    }
  }

  List<OfflineFcaDraft> _sortOfflineFcaDrafts(List<OfflineFcaDraft> drafts) {
    final sortedDrafts = [...drafts]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return sortedDrafts;
  }

  Future<void> _persistOfflineFcaDrafts(List<OfflineFcaDraft> drafts) async {
    await _hiveService.savePreference(
      HiveBoxes.tpsOfflineFcaDraftsKey,
      jsonEncode(drafts.map((draft) => draft.toJson()).toList(growable: false)),
    );
  }

  bool _matchesDistributionSearch(Distribution distribution, String query) {
    if (query.isEmpty) {
      return true;
    }

    final haystack = _searchHaystack([
      distribution.status,
      distribution.statusLabel,
      distribution.area,
      distribution.notes,
      distribution.tractorLabel,
      distribution.tractorBrand,
      distribution.tractorModel,
      distribution.distributedToName,
      distribution.distributedToEmail,
    ]);

    return haystack.contains(query);
  }

  bool _matchesFcaSearch(TpsFca fca, String query) {
    if (query.isEmpty) {
      return true;
    }

    final haystack = _searchHaystack([
      fca.name,
      fca.organizationName,
      fca.firstName,
      fca.lastName,
      fca.contactLabel,
      fca.locationLabel,
      fca.province,
      fca.cityTown,
      fca.barangay,
    ]);

    return haystack.contains(query);
  }

  Future<bool> _restoreCachedDistributions() async {
    final parsed = _parseOfflineDistributions(_distributionSearchQuery);
    if (parsed.isEmpty) {
      return false;
    }

    _distributions = parsed;
    _distributionsPage = 1;
    _distributionsLastPage = 1;
    _offlineDistributionsSyncedAt = _readOfflineTimestamp(
      HiveBoxes.tpsOfflineDistributionsSyncedAtKey,
    );
    return true;
  }

  Future<bool> _restoreCachedFcas() async {
    final parsed = _parseOfflineFcas(_fcaSearchQuery);
    if (parsed.isEmpty) {
      return false;
    }

    _fcas = parsed;
    _fcasPage = 1;
    _fcasLastPage = 1;
    _offlineFcasSyncedAt = _readOfflineTimestamp(
      HiveBoxes.tpsOfflineFcasSyncedAtKey,
    );
    return true;
  }

  Future<void> loadOfflineWorkspaceSnapshot() async {
    _distributionSearchQuery = '';
    _fcaSearchQuery = '';
    _distributions = _parseOfflineDistributions('');
    _fcas = _parseOfflineFcas('');
    _offlineDistributionDrafts = _readOfflineDistributionDrafts();
    _offlineFcaDrafts = _readOfflineFcaDrafts();
    _offlineDistributionsSyncedAt = _readOfflineTimestamp(
      HiveBoxes.tpsOfflineDistributionsSyncedAtKey,
    );
    _offlineFcasSyncedAt = _readOfflineTimestamp(
      HiveBoxes.tpsOfflineFcasSyncedAtKey,
    );
    _offlineReferenceDataSyncedAt = _readOfflineTimestamp(
      HiveBoxes.tpsOfflineReferenceDataSyncedAtKey,
    );
    _offlineLocationCacheSummary = _buildOfflineLocationCacheSummary();
    _distributionsPage = 1;
    _distributionsLastPage = 1;
    _fcasPage = 1;
    _fcasLastPage = 1;
    notifyListeners();
  }

  Future<void> _clearOfflineSavedRecordCaches() async {
    await _hiveService.removePreference(HiveBoxes.tpsOfflineDistributionsKey);
    await _hiveService.removePreference(HiveBoxes.tpsOfflineFcasKey);
    await _hiveService.removePreference(
      HiveBoxes.tpsOfflineDistributionsSyncedAtKey,
    );
    await _hiveService.removePreference(HiveBoxes.tpsOfflineFcasSyncedAtKey);

    _distributions = [];
    _fcas = [];
    _offlineDistributionsSyncedAt = null;
    _offlineFcasSyncedAt = null;
  }

  Future<void> loadOfflineDistributionsFromCache({String query = ''}) async {
    _distributionSearchQuery = _normalizeSearchQuery(query);
    _distributions = _parseOfflineDistributions(_distributionSearchQuery);
    _distributionsPage = 1;
    _distributionsLastPage = 1;
    _offlineDistributionsSyncedAt = _readOfflineTimestamp(
      HiveBoxes.tpsOfflineDistributionsSyncedAtKey,
    );
    notifyListeners();
  }

  Future<void> loadOfflineFcasFromCache({String query = ''}) async {
    _fcaSearchQuery = _normalizeSearchQuery(query);
    _fcas = _parseOfflineFcas(_fcaSearchQuery);
    _fcasPage = 1;
    _fcasLastPage = 1;
    _offlineFcasSyncedAt = _readOfflineTimestamp(
      HiveBoxes.tpsOfflineFcasSyncedAtKey,
    );
    notifyListeners();
  }

  Future<void> loadOfflineDistributionDrafts() async {
    _offlineDistributionDrafts = _readOfflineDistributionDrafts();
    _offlineReferenceDataSyncedAt = _readOfflineTimestamp(
      HiveBoxes.tpsOfflineReferenceDataSyncedAtKey,
    );
    _offlineLocationCacheSummary = _buildOfflineLocationCacheSummary();
    notifyListeners();
  }

  Future<void> loadOfflineFcaDrafts() async {
    _offlineFcaDrafts = _readOfflineFcaDrafts();
    _offlineReferenceDataSyncedAt = _readOfflineTimestamp(
      HiveBoxes.tpsOfflineReferenceDataSyncedAtKey,
    );
    _offlineLocationCacheSummary = _buildOfflineLocationCacheSummary();
    notifyListeners();
  }

  Future<void> saveOfflineDistributionDraft(
    OfflineDistributionDraft draft,
  ) async {
    final drafts = [..._readOfflineDistributionDrafts()];
    final nextDraft = draft.copyWith(updatedAt: DateTime.now());
    final existingIndex = drafts.indexWhere((item) => item.id == draft.id);

    if (existingIndex >= 0) {
      drafts[existingIndex] = nextDraft;
    } else {
      drafts.insert(0, nextDraft);
    }

    final sortedDrafts = _sortOfflineDistributionDrafts(drafts);
    await _persistOfflineDistributionDrafts(sortedDrafts);
    _offlineDistributionDrafts = sortedDrafts;
    notifyListeners();
  }

  Future<void> deleteOfflineDistributionDraft(String draftId) async {
    final drafts = _readOfflineDistributionDrafts()
        .where((draft) => draft.id != draftId)
        .toList(growable: false);
    await _persistOfflineDistributionDrafts(drafts);
    _offlineDistributionDrafts = drafts;
    notifyListeners();
  }

  Future<void> saveOfflineFcaDraft(OfflineFcaDraft draft) async {
    final drafts = [..._readOfflineFcaDrafts()];
    final nextDraft = draft.copyWith(updatedAt: DateTime.now());
    final existingIndex = drafts.indexWhere((item) => item.id == draft.id);

    if (existingIndex >= 0) {
      drafts[existingIndex] = nextDraft;
    } else {
      drafts.insert(0, nextDraft);
    }

    final sortedDrafts = _sortOfflineFcaDrafts(drafts);
    await _persistOfflineFcaDrafts(sortedDrafts);
    _offlineFcaDrafts = sortedDrafts;
    notifyListeners();
  }

  Future<void> deleteOfflineFcaDraft(String draftId) async {
    final drafts = _readOfflineFcaDrafts()
        .where((draft) => draft.id != draftId)
        .toList(growable: false);
    await _persistOfflineFcaDrafts(drafts);
    _offlineFcaDrafts = drafts;
    notifyListeners();
  }

  Future<int> syncOfflineDistributions() async {
    try {
      final records = await _fetchAllPagedRecords(
        AppEndpoints.tpsDistributions,
      );
      final syncedAt = DateTime.now();
      await _saveOfflineCollection(
        HiveBoxes.tpsOfflineDistributionsKey,
        records,
      );
      await _saveOfflineTimestamp(
        HiveBoxes.tpsOfflineDistributionsSyncedAtKey,
        syncedAt,
      );
      _distributions = records
          .map(Distribution.fromJson)
          .toList(growable: false);
      _distributionsPage = 1;
      _distributionsLastPage = 1;
      _offlineDistributionsSyncedAt = syncedAt;
      notifyListeners();
      return records.length;
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    } catch (_) {
      throw const AppException('Failed to download offline distributions.');
    }
  }

  Future<int> syncOfflineFcas() async {
    try {
      final records = await _fetchAllPagedRecords(AppEndpoints.tpsFcas);
      final syncedAt = DateTime.now();
      await _saveOfflineCollection(HiveBoxes.tpsOfflineFcasKey, records);
      await _saveOfflineTimestamp(
        HiveBoxes.tpsOfflineFcasSyncedAtKey,
        syncedAt,
      );
      _fcas = records.map(TpsFca.fromJson).toList(growable: false);
      _fcasPage = 1;
      _fcasLastPage = 1;
      _offlineFcasSyncedAt = syncedAt;
      notifyListeners();
      return records.length;
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    } catch (_) {
      throw const AppException('Failed to download offline FCA data.');
    }
  }

  bool _hasCompleteOfflineFcaLocationCache() {
    final provinces = _readCachedLocationOptions(
      HiveBoxes.tpsFcaProvinceOptionsCacheKey,
    );
    if (provinces.isEmpty) {
      return false;
    }

    for (final province in provinces) {
      final cities = _readCachedLocationOptions(
        _fcaCitiesCacheKey(province.code),
      );
      if (cities.isEmpty) {
        return false;
      }

      for (final city in cities) {
        final barangays = _readCachedLocationOptions(
          _fcaBarangaysCacheKey(city.code),
        );
        if (barangays.isEmpty) {
          return false;
        }
      }
    }

    return true;
  }

  Future<void> syncOfflineFcaLocationCache() async {
    if (_hasCompleteOfflineFcaLocationCache()) {
      return;
    }

    try {
      final provinces = await fetchFcaProvinces();
      for (final province in provinces) {
        final cities = await fetchFcaCities(provinceCode: province.code);
        for (final city in cities) {
          await fetchFcaBarangays(cityMunicipalityCode: city.code);
        }
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        'Failed to download offline FCA location lists.',
      );
    }
  }

  Future<void> syncOfflineReferenceData() async {
    try {
      await _clearOfflineSavedRecordCaches();
      await syncOfflineFcaLocationCache();
      await fetchFcaTractorOptions();
      await fetchTpsUserOptions();
      final syncedAt = DateTime.now();
      await _saveOfflineTimestamp(
        HiveBoxes.tpsOfflineReferenceDataSyncedAtKey,
        syncedAt,
      );
      _offlineReferenceDataSyncedAt = syncedAt;
      _offlineLocationCacheSummary = _buildOfflineLocationCacheSummary();
      notifyListeners();
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Failed to download offline reference data.');
    }
  }

  Future<void> syncOfflineTractorOptions() async {
    await fetchFcaTractorOptions();
  }

  Future<void> syncOfflineUserOptions() async {
    await fetchTpsUserOptions();
  }

  Future<void> finalizeOfflineReferenceDataSync() async {
    final syncedAt = DateTime.now();
    await _saveOfflineTimestamp(HiveBoxes.tpsOfflineReferenceDataSyncedAtKey, syncedAt);
    _offlineReferenceDataSyncedAt = syncedAt;
    _offlineLocationCacheSummary = _buildOfflineLocationCacheSummary();
    notifyListeners();
  }

  Map<String, dynamic> _ticketQueryParameters({
    required int page,
    String? status,
    bool forChat = false,
  }) {
    final normalizedSearch = _normalizeSearchQuery(_ticketSearchQuery);

    return {
      'per_page': '20',
      'page': page.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (!forChat && normalizedSearch.isNotEmpty) 'search': normalizedSearch,
      if (forChat) 'for_chat': '1',
    };
  }

  List<Ticket> _parseTicketList(Map<String, dynamic> response) {
    final dataList = response['data'] as List<dynamic>? ?? [];
    return dataList
        .whereType<Map<String, dynamic>>()
        .map(Ticket.fromJson)
        .toList();
  }

  void _upsertChatTicket(Ticket ticket) {
    _chatTickets = [
      ticket,
      ..._chatTickets.where((item) => item.id != ticket.id),
    ];
  }

  void _applyCommentToChatTicket(int ticketId, TicketComment comment) {
    final index = _chatTickets.indexWhere((ticket) => ticket.id == ticketId);
    if (index < 0) {
      return;
    }

    final existing = _chatTickets[index];
    if (existing.lastComment?.id == comment.id) {
      return;
    }

    _upsertChatTicket(existing.copyWithNewComment(comment));
  }

  Future<void> fetchTickets({String? status}) async {
    _ticketsLoading = true;
    _ticketsError = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsTickets,
        queryParameters: _ticketQueryParameters(page: 1, status: status),
      );

      _tickets = _parseTicketList(response);
      _ticketsPage = _extractCurrentPage(response);
      _ticketsLastPage = _extractLastPage(response);
    } catch (e) {
      _ticketsError = 'Failed to load tickets';
      debugPrint('TpsProvider.fetchTickets error: $e');
    } finally {
      _ticketsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreTickets({String? status}) async {
    if (!hasMoreTickets || _ticketsLoading) return;

    _ticketsLoading = true;
    notifyListeners();

    try {
      final nextPage = _ticketsPage + 1;
      final response = await _apiClient.get(
        AppEndpoints.tpsTickets,
        queryParameters: _ticketQueryParameters(page: nextPage, status: status),
      );

      final newTickets = _parseTicketList(response);
      _tickets = [..._tickets, ...newTickets];
      _ticketsPage = _extractCurrentPage(response);
      _ticketsLastPage = _extractLastPage(response);
    } catch (e) {
      debugPrint('TpsProvider.fetchMoreTickets error: $e');
    } finally {
      _ticketsLoading = false;
      notifyListeners();
    }
  }

  Future<void> setTicketSearchQuery(String query, {String? status}) async {
    final normalizedQuery = _normalizeSearchQuery(query);
    if (_ticketSearchQuery == normalizedQuery) {
      return;
    }

    _ticketSearchQuery = normalizedQuery;
    _tickets = [];
    _ticketsPage = 1;
    _ticketsLastPage = 1;
    notifyListeners();
    await fetchTickets(status: status);
  }

  Future<void> fetchChatTickets() async {
    _chatTicketsLoading = true;
    _chatTicketsError = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsTickets,
        queryParameters: _ticketQueryParameters(page: 1, forChat: true),
      );

      _chatTickets = _parseTicketList(response);
      _chatTicketsPage = (response['current_page'] as num?)?.toInt() ?? 1;
      _chatTicketsLastPage = (response['last_page'] as num?)?.toInt() ?? 1;
    } catch (e) {
      _chatTicketsError = 'Failed to load chat rooms';
      debugPrint('TpsProvider.fetchChatTickets error: $e');
    } finally {
      _chatTicketsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreChatTickets() async {
    if (!hasMoreChatTickets || _chatTicketsLoading) {
      return;
    }

    _chatTicketsLoading = true;
    notifyListeners();

    try {
      final nextPage = _chatTicketsPage + 1;
      final response = await _apiClient.get(
        AppEndpoints.tpsTickets,
        queryParameters: _ticketQueryParameters(page: nextPage, forChat: true),
      );

      final newTickets = _parseTicketList(response);
      _chatTickets = [..._chatTickets, ...newTickets];
      _chatTicketsPage = nextPage;
      _chatTicketsLastPage =
          (response['last_page'] as num?)?.toInt() ?? _chatTicketsLastPage;
    } catch (e) {
      debugPrint('TpsProvider.fetchMoreChatTickets error: $e');
    } finally {
      _chatTicketsLoading = false;
      notifyListeners();
    }
  }

  // ─── Feedbacks ────────────────────────────────

  Map<String, dynamic> _feedbackQueryParameters({required int page}) {
    final normalizedSearch = _normalizeSearchQuery(_feedbackSearchQuery);

    return {
      'per_page': '20',
      'page': page.toString(),
      if (normalizedSearch.isNotEmpty) 'search': normalizedSearch,
    };
  }

  Future<void> fetchFeedbacks() async {
    _feedbacksLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsFeedbacks,
        queryParameters: _feedbackQueryParameters(page: 1),
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _feedbacks = dataList
          .whereType<Map<String, dynamic>>()
          .map(FarmerFeedbackItem.fromJson)
          .toList();
      _feedbacksPage = _extractCurrentPage(response);
      _feedbacksLastPage = _extractLastPage(response);
    } catch (e) {
      debugPrint('TpsProvider.fetchFeedbacks error: $e');
    } finally {
      _feedbacksLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreFeedbacks() async {
    if (!hasMoreFeedbacks || _feedbacksLoading) {
      return;
    }

    _feedbacksLoading = true;
    notifyListeners();

    try {
      final nextPage = _feedbacksPage + 1;
      final response = await _apiClient.get(
        AppEndpoints.tpsFeedbacks,
        queryParameters: _feedbackQueryParameters(page: nextPage),
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      final newFeedbacks = dataList
          .whereType<Map<String, dynamic>>()
          .map(FarmerFeedbackItem.fromJson)
          .toList();

      _feedbacks = [..._feedbacks, ...newFeedbacks];
      _feedbacksPage = _extractCurrentPage(response);
      _feedbacksLastPage = _extractLastPage(response);
    } catch (e) {
      debugPrint('TpsProvider.fetchMoreFeedbacks error: $e');
    } finally {
      _feedbacksLoading = false;
      notifyListeners();
    }
  }

  Future<void> setFeedbackSearchQuery(String query) async {
    final normalizedQuery = _normalizeSearchQuery(query);
    if (_feedbackSearchQuery == normalizedQuery) {
      return;
    }

    _feedbackSearchQuery = normalizedQuery;
    _feedbacks = [];
    _feedbacksPage = 1;
    _feedbacksLastPage = 1;
    notifyListeners();
    await fetchFeedbacks();
  }

  // ─── Tractors ──────────────────────────────────

  Map<String, dynamic> _tractorQueryParameters({required int page}) {
    final normalizedSearch = _normalizeSearchQuery(_tractorSearchQuery);

    return {
      'per_page': '20',
      'page': page.toString(),
      if (normalizedSearch.isNotEmpty) 'search': normalizedSearch,
    };
  }

  Future<void> fetchTractors() async {
    _tractorsLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsTractors,
        queryParameters: _tractorQueryParameters(page: 1),
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _tractors = dataList.whereType<Map<String, dynamic>>().toList();
      _tractorsPage = _extractCurrentPage(response);
      _tractorsLastPage = _extractLastPage(response);
    } catch (e) {
      debugPrint('TpsProvider.fetchTractors error: $e');
    } finally {
      _tractorsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreTractors() async {
    if (!hasMoreTractors || _tractorsLoading) {
      return;
    }

    _tractorsLoading = true;
    notifyListeners();

    try {
      final nextPage = _tractorsPage + 1;
      final response = await _apiClient.get(
        AppEndpoints.tpsTractors,
        queryParameters: _tractorQueryParameters(page: nextPage),
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      final newTractors = dataList.whereType<Map<String, dynamic>>().toList();

      _tractors = [..._tractors, ...newTractors];
      _tractorsPage = _extractCurrentPage(response);
      _tractorsLastPage = _extractLastPage(response);
    } catch (e) {
      debugPrint('TpsProvider.fetchMoreTractors error: $e');
    } finally {
      _tractorsLoading = false;
      notifyListeners();
    }
  }

  Future<void> setTractorSearchQuery(String query) async {
    final normalizedQuery = _normalizeSearchQuery(query);
    if (_tractorSearchQuery == normalizedQuery) {
      return;
    }

    _tractorSearchQuery = normalizedQuery;
    _tractors = [];
    _tractorsPage = 1;
    _tractorsLastPage = 1;
    notifyListeners();
    await fetchTractors();
  }

  // ─── Distributions ─────────────────────────────

  Map<String, dynamic> _distributionQueryParameters({required int page}) {
    final normalizedSearch = _normalizeSearchQuery(_distributionSearchQuery);

    return {
      'per_page': '20',
      'page': page.toString(),
      if (normalizedSearch.isNotEmpty) 'search': normalizedSearch,
    };
  }

  Future<void> fetchDistributions() async {
    _distributionsLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsDistributions,
        queryParameters: _distributionQueryParameters(page: 1),
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _distributions = dataList
          .whereType<Map<String, dynamic>>()
          .map(Distribution.fromJson)
          .toList();
      _distributionsPage = _extractCurrentPage(response);
      _distributionsLastPage = _extractLastPage(response);
    } catch (e) {
      final restored = await _restoreCachedDistributions();
      if (!restored) {
        debugPrint('TpsProvider.fetchDistributions error: $e');
      }
    } finally {
      _distributionsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreDistributions() async {
    if (!hasMoreDistributions || _distributionsLoading) {
      return;
    }

    _distributionsLoading = true;
    notifyListeners();

    try {
      final nextPage = _distributionsPage + 1;
      final response = await _apiClient.get(
        AppEndpoints.tpsDistributions,
        queryParameters: _distributionQueryParameters(page: nextPage),
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      final newDistributions = dataList
          .whereType<Map<String, dynamic>>()
          .map(Distribution.fromJson)
          .toList();

      _distributions = [..._distributions, ...newDistributions];
      _distributionsPage = _extractCurrentPage(response);
      _distributionsLastPage = _extractLastPage(response);
    } catch (e) {
      debugPrint('TpsProvider.fetchMoreDistributions error: $e');
    } finally {
      _distributionsLoading = false;
      notifyListeners();
    }
  }

  Future<void> setDistributionSearchQuery(String query) async {
    final normalizedQuery = _normalizeSearchQuery(query);
    if (_distributionSearchQuery == normalizedQuery) {
      return;
    }

    _distributionSearchQuery = normalizedQuery;
    _distributions = [];
    _distributionsPage = 1;
    _distributionsLastPage = 1;
    notifyListeners();
    await fetchDistributions();
  }

  // ─── FCAs ──────────────────────────────────────

  Map<String, dynamic> _fcaQueryParameters({required int page}) {
    final normalizedSearch = _normalizeSearchQuery(_fcaSearchQuery);

    return {
      'per_page': '20',
      'page': page.toString(),
      if (normalizedSearch.isNotEmpty) 'search': normalizedSearch,
    };
  }

  Future<void> fetchFcas() async {
    _fcasLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsFcas,
        queryParameters: _fcaQueryParameters(page: 1),
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _fcas = dataList
          .whereType<Map<String, dynamic>>()
          .map(TpsFca.fromJson)
          .toList();
      _fcasPage = _extractCurrentPage(response);
      _fcasLastPage = _extractLastPage(response);
    } catch (e) {
      final restored = await _restoreCachedFcas();
      if (!restored) {
        debugPrint('TpsProvider.fetchFcas error: $e');
      }
    } finally {
      _fcasLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreFcas() async {
    if (!hasMoreFcas || _fcasLoading) {
      return;
    }

    _fcasLoading = true;
    notifyListeners();

    try {
      final nextPage = _fcasPage + 1;
      final response = await _apiClient.get(
        AppEndpoints.tpsFcas,
        queryParameters: _fcaQueryParameters(page: nextPage),
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      final newFcas = dataList
          .whereType<Map<String, dynamic>>()
          .map(TpsFca.fromJson)
          .toList();

      _fcas = [..._fcas, ...newFcas];
      _fcasPage = _extractCurrentPage(response);
      _fcasLastPage = _extractLastPage(response);
    } catch (e) {
      debugPrint('TpsProvider.fetchMoreFcas error: $e');
    } finally {
      _fcasLoading = false;
      notifyListeners();
    }
  }

  Future<void> setFcaSearchQuery(String query) async {
    final normalizedQuery = _normalizeSearchQuery(query);
    if (_fcaSearchQuery == normalizedQuery) {
      return;
    }

    _fcaSearchQuery = normalizedQuery;
    _fcas = [];
    _fcasPage = 1;
    _fcasLastPage = 1;
    notifyListeners();
    await fetchFcas();
  }

  Future<List<TpsFca>> fetchFcaSuggestions({String search = ''}) async {
    final normalizedSearch = _normalizeSearchQuery(search);
    if (normalizedSearch.isEmpty) {
      return const [];
    }

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsFcas,
        queryParameters: {
          'per_page': '10',
          'page': '1',
          'search': normalizedSearch,
        },
      );

      final dataList = response['data'] as List<dynamic>? ?? const [];
      final suggestions = dataList
          .whereType<Map<String, dynamic>>()
          .map(TpsFca.fromJson)
          .where((fca) => fca.id > 0)
          .toList(growable: false);

      return suggestions;
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> fetchFcaDetail(int fcaId) async {
    try {
      final response = await _apiClient.get('${AppEndpoints.tpsFcas}/$fcaId');
      final data = response['data'];

      if (data is Map<String, dynamic>) {
        return data;
      }

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      throw const AppException('Failed to load FCA details.');
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  // ─── Selected Ticket Detail ─────────────────────

  Ticket? _selectedTicket;
  bool _loadingDetail = false;

  Ticket? get selectedTicket => _selectedTicket;
  bool get loadingDetail => _loadingDetail;

  Future<void> fetchTicketDetail(int ticketId) async {
    _loadingDetail = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        '${AppEndpoints.tpsTickets}/$ticketId',
      );

      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        _selectedTicket = Ticket.fromJson(data);
      }
    } catch (e) {
      debugPrint('TpsProvider.fetchTicketDetail error: $e');
    } finally {
      _loadingDetail = false;
      notifyListeners();
    }
  }

  // ─── Ticket Form Data ─────────────────────────

  List<Map<String, dynamic>> _ticketTractors = [];
  bool _loadingTicketFormData = false;

  List<Map<String, dynamic>> get ticketTractors => _ticketTractors;
  bool get loadingTicketFormData => _loadingTicketFormData;

  Future<void> fetchTicketFormData() async {
    _loadingTicketFormData = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(AppEndpoints.tpsTicketFormData);
      final tractorList = response['tractors'] as List<dynamic>? ?? [];
      _ticketTractors = tractorList.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('TpsProvider.fetchTicketFormData error: $e');
    } finally {
      _loadingTicketFormData = false;
      notifyListeners();
    }
  }

  // ─── Create Ticket (multipart) ─────────────────

  Future<Ticket?> createTicket({
    required String subject,
    required String description,
    required String priority,
    String? category,
    int? tractorId,
    File? photo,
  }) async {
    try {
      final formMap = <String, dynamic>{
        'subject': subject,
        'description': description,
        'priority': priority,
        'category': ?category,
        'tractor_id': ?tractorId,
      };

      if (photo != null) {
        formMap['photo'] = await MultipartFile.fromFile(
          photo.path,
          filename: photo.path.split(Platform.pathSeparator).last,
        );
      }

      final formData = FormData.fromMap(formMap);

      final response = await _dio.post(
        AppEndpoints.tickets,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final rawData = (response.data as Map?)?['data'];
      final data = rawData is Map<String, dynamic>
          ? rawData
          : rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : null;
      final createdTicket = data != null ? Ticket.fromJson(data) : null;

      if (createdTicket != null) {
        _selectedTicket = createdTicket;
        _upsertChatTicket(createdTicket);
      }

      await Future.wait([fetchTickets(), fetchChatTickets()]);
      return createdTicket;
    } catch (e) {
      debugPrint('TpsProvider.createTicket error: $e');
      return null;
    }
  }

  // ─── Resolve Ticket (multipart) ────────────────

  Future<bool> resolveTicket({
    required int ticketId,
    String? resolutionNotes,
    File? resolutionPhoto,
    double? serviceCharge,
    double? downPayment,
    int? installments,
    List<Map<String, dynamic>>? parts,
    List<File>? drPhotos,
  }) async {
    try {
      final formMap = <String, dynamic>{
        'resolution_notes': ?resolutionNotes,
        if (serviceCharge != null) 'service_charge': serviceCharge.toString(),
        if (downPayment != null) 'down_payment': downPayment.toString(),
        if (installments != null) 'installments': installments.toString(),
      };

      if (resolutionPhoto != null) {
        formMap['resolution_photo'] = await MultipartFile.fromFile(
          resolutionPhoto.path,
          filename: resolutionPhoto.path.split(Platform.pathSeparator).last,
        );
      }

      if (parts != null && parts.isNotEmpty) {
        for (var i = 0; i < parts.length; i++) {
          final p = parts[i];
          formMap['parts[$i][name]'] = p['name'];
          formMap['parts[$i][amount]'] = (p['amount'] ?? 0).toString();
          formMap['parts[$i][quantity]'] = (p['quantity'] ?? 1).toString();
          if (p['id'] != null) formMap['parts[$i][id]'] = p['id'].toString();
        }
      }

      if (drPhotos != null && drPhotos.isNotEmpty) {
        for (var i = 0; i < drPhotos.length; i++) {
          formMap['dr_photos[$i]'] = await MultipartFile.fromFile(
            drPhotos[i].path,
            filename: drPhotos[i].path.split(Platform.pathSeparator).last,
          );
        }
      }

      final formData = FormData.fromMap(formMap);

      await _dio.post(
        '${AppEndpoints.tickets}/$ticketId/resolve',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      await Future.wait([fetchTicketDetail(ticketId), fetchChatTickets()]);
      return true;
    } catch (e) {
      debugPrint('TpsProvider.resolveTicket error: $e');
      return false;
    }
  }

  // ─── Tractor Parts ─────────────────────────────

  List<Map<String, dynamic>> _tractorParts = [];
  List<Map<String, dynamic>> get tractorParts => _tractorParts;

  Future<void> fetchTractorParts() async {
    try {
      final response = await _apiClient.get(AppEndpoints.tractorParts);
      final data = (response is Map ? response['data'] : null) as List<dynamic>? ?? [];
      _tractorParts = data.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('TpsProvider.fetchTractorParts error: $e');
      _tractorParts = [];
    }
  }

  // ─── Close Ticket ──────────────────────────────

  Future<bool> closeTicket(int ticketId) async {
    try {
      await _apiClient.post('${AppEndpoints.tickets}/$ticketId/close');
      await fetchTicketDetail(ticketId);
      return true;
    } catch (e) {
      debugPrint('TpsProvider.closeTicket error: $e');
      return false;
    }
  }

  // ─── Request Assistance ────────────────────────

  Future<bool> requestAssistance({
    required int ticketId,
    required String message,
  }) async {
    try {
      await _apiClient.post(
        '${AppEndpoints.tpsTickets}/$ticketId/request-assistance',
        data: {'message': message},
      );
      return true;
    } catch (e) {
      debugPrint('TpsProvider.requestAssistance error: $e');
      return false;
    }
  }

  // ─── Add Comment ───────────────────────────────

  Future<bool> addComment({
    required int ticketId,
    String? body,
    File? attachment,
    String? socketId,
  }) async {
    try {
      if (attachment != null) {
        final formMap = <String, dynamic>{
          if (body != null && body.isNotEmpty) 'body': body,
          if (socketId != null && socketId.isNotEmpty) 'socket_id': socketId,
          'attachment': await MultipartFile.fromFile(
            attachment.path,
            filename: attachment.path.split(Platform.pathSeparator).last,
          ),
        };

        final formData = FormData.fromMap(formMap);

        final response = await _dio.post(
          '${AppEndpoints.tickets}/$ticketId/comment',
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );

        final data =
            (response.data as Map<String, dynamic>?)?['data']
                as Map<String, dynamic>?;
        if (data != null) {
          data['attachment_url'] = UrlHelper.fixStorageUrl(data['attachment_url']?.toString());
          final comment = TicketComment.fromJson(data);
          if (_selectedTicket != null) {
            _selectedTicket = _selectedTicket!.copyWithNewComment(comment);
          }

          _applyCommentToChatTicket(ticketId, comment);
          notifyListeners();
        }
      } else {
        final response = await _apiClient.post(
          '${AppEndpoints.tickets}/$ticketId/comment',
          data: {
            'body': body,
            if (socketId != null && socketId.isNotEmpty) 'socket_id': socketId,
          },
        );

        final data = response['data'] as Map<String, dynamic>?;
        if (data != null) {
          data['attachment_url'] = UrlHelper.fixStorageUrl(data['attachment_url']?.toString());
          final comment = TicketComment.fromJson(data);
          if (_selectedTicket != null) {
            _selectedTicket = _selectedTicket!.copyWithNewComment(comment);
          }

          _applyCommentToChatTicket(ticketId, comment);
          notifyListeners();
        }
      }

      return true;
    } catch (e) {
      debugPrint('TpsProvider.addComment error: $e');
      return false;
    }
  }

  void appendRealtimeComment(Map<String, dynamic> commentData) {
    final attachmentPath = commentData['attachment_path']?.toString();
    commentData['attachment_url'] = UrlHelper.fixStorageUrl(
      commentData['attachment_url']?.toString() ?? attachmentPath,
    );

    final id = commentData['id'] as int?;
    if (id != null &&
        _selectedTicket != null &&
        _selectedTicket!.comments != null &&
        _selectedTicket!.comments!.any((comment) => comment.id == id)) {
      return;
    }

    final comment = TicketComment.fromJson(commentData);
    if (_selectedTicket != null) {
      _selectedTicket = _selectedTicket!.copyWithNewComment(comment);
    }

    final rawTicketId = commentData['ticket_id'];
    final ticketId = rawTicketId is num
        ? rawTicketId.toInt()
        : int.tryParse(rawTicketId?.toString() ?? '');

    if (ticketId != null) {
      _applyCommentToChatTicket(ticketId, comment);
    }

    notifyListeners();
  }

  // ─── Load all data ─────────────────────────────

  Future<void> loadAll() async {
    await Future.wait([
      fetchDashboard(),
      fetchTickets(),
      fetchFcas(),
      fetchFeedbacks(),
      fetchTractors(),
      fetchDistributions(),
    ]);
  }

  // ─── Distribution Form Data ────────────────────

  Future<Map<String, dynamic>> fetchDistributionFormData() async {
    try {
      return await _apiClient.get(AppEndpoints.tpsDistributionFormData);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  List<LocationOption> _parseLocationOptions(dynamic rawData) {
    final dataList = switch (rawData) {
      List<dynamic> data => data,
      Map<String, dynamic> data =>
        data.entries
            .map(
              (entry) =>
                  entry.value is Map || entry.value is Map<String, dynamic>
                  ? entry.value
                  : <String, dynamic>{
                      'code': entry.key,
                      'name': entry.value?.toString(),
                    },
            )
            .toList(growable: false),
      Map data =>
        data.entries
            .map(
              (entry) =>
                  entry.value is Map || entry.value is Map<String, dynamic>
                  ? entry.value
                  : <String, dynamic>{
                      'code': entry.key.toString(),
                      'name': entry.value?.toString(),
                    },
            )
            .toList(growable: false),
      _ => const <dynamic>[],
    };

    return dataList
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          }

          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }

          return <String, dynamic>{};
        })
        .where((item) => item.isNotEmpty)
        .map(LocationOption.fromJson)
        .toList(growable: false);
  }

  String _fcaCitiesCacheKey(String provinceCode) {
    return '${HiveBoxes.tpsFcaCitiesCachePrefix}${provinceCode.trim()}';
  }

  String _fcaBarangaysCacheKey(String cityMunicipalityCode) {
    return '${HiveBoxes.tpsFcaBarangaysCachePrefix}${cityMunicipalityCode.trim()}';
  }

  List<LocationOption> _readCachedLocationOptions(String key) {
    final raw = _hiveService.getPreference(key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      return _parseLocationOptions(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  OfflineLocationCacheSummary _buildOfflineLocationCacheSummary() {
    final provinces =
        [..._readCachedLocationOptions(HiveBoxes.tpsFcaProvinceOptionsCacheKey)]
          ..sort(
            (left, right) =>
                left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          );

    if (provinces.isEmpty) {
      return OfflineLocationCacheSummary.empty;
    }

    final provinceSummaries = <OfflineLocationProvinceSummary>[];
    var totalCities = 0;
    var totalBarangays = 0;

    for (final province in provinces) {
      final cities =
          [..._readCachedLocationOptions(_fcaCitiesCacheKey(province.code))]
            ..sort(
              (left, right) =>
                  left.name.toLowerCase().compareTo(right.name.toLowerCase()),
            );
      final citySummaries = <OfflineLocationCitySummary>[];

      for (final city in cities) {
        final barangayNames =
            _readCachedLocationOptions(_fcaBarangaysCacheKey(city.code))
                .map((barangay) => barangay.name.trim())
                .where((name) => name.isNotEmpty)
                .toList(growable: false)
              ..sort(
                (left, right) =>
                    left.toLowerCase().compareTo(right.toLowerCase()),
              );

        citySummaries.add(
          OfflineLocationCitySummary(
            code: city.code.trim(),
            name: city.name.trim(),
            barangays: barangayNames,
          ),
        );
        totalBarangays += barangayNames.length;
      }

      totalCities += citySummaries.length;
      provinceSummaries.add(
        OfflineLocationProvinceSummary(
          code: province.code.trim(),
          name: province.name.trim(),
          cities: citySummaries,
        ),
      );
    }

    return OfflineLocationCacheSummary(
      provinces: provinceSummaries,
      cityCount: totalCities,
      barangayCount: totalBarangays,
    );
  }

  Future<void> _persistCachedLocationOptions(
    String key,
    List<LocationOption> options,
  ) async {
    await _hiveService.savePreference(
      key,
      jsonEncode(
        options
            .map((option) => {'code': option.code, 'name': option.name})
            .toList(growable: false),
      ),
    );
  }

  List<TpsUserOption> _readCachedTpsUserOptions() {
    final raw = _hiveService.getPreference(HiveBoxes.tpsTpsUserOptionsCacheKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => TpsUserOption.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((option) => option.id > 0 && option.name.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistCachedTpsUserOptions(List<TpsUserOption> options) async {
    await _hiveService.savePreference(
      HiveBoxes.tpsTpsUserOptionsCacheKey,
      jsonEncode(
        options
            .map(
              (option) => {
                'id': option.id,
                'name': option.name,
                'email': option.email,
                'phone': option.phone,
              },
            )
            .toList(growable: false),
      ),
    );
  }

  List<FcaTractorOption> _readCachedFcaTractorOptions() {
    final raw = _hiveService.getPreference(
      HiveBoxes.tpsFcaTractorOptionsCacheKey,
    );
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                FcaTractorOption.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((option) => option.id > 0)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistCachedFcaTractorOptions(
    List<FcaTractorOption> options,
  ) async {
    await _hiveService.savePreference(
      HiveBoxes.tpsFcaTractorOptionsCacheKey,
      jsonEncode(
        options
            .map(
              (option) => {
                'id': option.id,
                'no_plate': option.noPlate,
                'brand': option.brand,
                'model': option.model,
                'dr_no': option.drNo,
                'id_no': option.serialNumber,
                'engine_no': option.engineNumber,
                'front_loader_sn': option.frontLoaderSerialNumber,
                'rotary_tiller_sn': option.rotavatorSerialNumber,
                'disc_plow_sn': option.diskPlowSerialNumber,
                'imei': option.gpsImei,
                'device': {
                  'sim_iccid': option.gpsSimNumber,
                  'sim': option.gpsMobileNumber,
                },
              },
            )
            .toList(growable: false),
      ),
    );
  }

  bool _matchesFcaTractorOptionSearch(FcaTractorOption option, String query) {
    if (query.isEmpty) {
      return true;
    }

    final haystack = _searchHaystack([
      option.noPlate,
      option.brand,
      option.model,
      option.drNo,
      option.serialNumber,
      option.engineNumber,
      option.gpsImei,
      option.gpsSimNumber,
      option.gpsMobileNumber,
      option.displayLabel,
      option.displaySubtitle,
    ]);

    return haystack.contains(query);
  }

  Future<List<LocationOption>> fetchFcaProvinces() async {
    final cachedOptions = _readCachedLocationOptions(
      HiveBoxes.tpsFcaProvinceOptionsCacheKey,
    );

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsFcaLocationProvinces,
      );
      final options = _parseLocationOptions(response['data']);
      await _persistCachedLocationOptions(
        HiveBoxes.tpsFcaProvinceOptionsCacheKey,
        options,
      );
      return options;
    } on DioException catch (error) {
      if (cachedOptions.isNotEmpty) {
        return cachedOptions;
      }

      throw AppException.fromDio(error);
    }
  }

  Future<List<LocationOption>> fetchFcaCities({
    required String provinceCode,
  }) async {
    final cacheKey = _fcaCitiesCacheKey(provinceCode);
    final cachedOptions = _readCachedLocationOptions(cacheKey);

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsFcaLocationCities,
        queryParameters: {'province_code': provinceCode},
      );

      final options = _parseLocationOptions(response['data']);
      await _persistCachedLocationOptions(cacheKey, options);
      return options;
    } on DioException catch (error) {
      if (cachedOptions.isNotEmpty) {
        return cachedOptions;
      }

      throw AppException.fromDio(error);
    }
  }

  Future<List<LocationOption>> fetchFcaBarangays({
    required String cityMunicipalityCode,
  }) async {
    final cacheKey = _fcaBarangaysCacheKey(cityMunicipalityCode);
    final cachedOptions = _readCachedLocationOptions(cacheKey);

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsFcaLocationBarangays,
        queryParameters: {'city_municipality_code': cityMunicipalityCode},
      );

      final options = _parseLocationOptions(response['data']);
      await _persistCachedLocationOptions(cacheKey, options);
      return options;
    } on DioException catch (error) {
      if (cachedOptions.isNotEmpty) {
        return cachedOptions;
      }

      throw AppException.fromDio(error);
    }
  }

  Future<List<TpsUserOption>> fetchTpsUserOptions({String search = ''}) async {
    final normalizedSearch = _normalizeSearchQuery(search);
    final cachedOptions = _readCachedTpsUserOptions();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsUsers,
        queryParameters: {
          if (normalizedSearch.isNotEmpty) 'search': normalizedSearch,
        },
      );

      final dataList = response['data'] as List<dynamic>? ?? const [];
      final options = dataList
          .map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            }

            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }

            return <String, dynamic>{};
          })
          .where((item) => item.isNotEmpty)
          .map(TpsUserOption.fromJson)
          .where((option) => option.id > 0 && option.name.isNotEmpty)
          .toList(growable: false);

      if (normalizedSearch.isEmpty) {
        await _persistCachedTpsUserOptions(options);
      }

      return options;
    } on DioException catch (error) {
      if (cachedOptions.isNotEmpty) {
        return cachedOptions
            .where((option) => option.matches(normalizedSearch))
            .toList(growable: false);
      }

      throw AppException.fromDio(error);
    }
  }

  Future<List<FcaTractorOption>> fetchFcaTractorOptions({
    String search = '',
  }) async {
    final normalizedSearch = _normalizeSearchQuery(search);
    final cachedOptions = _readCachedFcaTractorOptions();
    final tractors = <Map<String, dynamic>>[];
    var currentPage = 1;
    var lastPage = 1;

    try {
      do {
        final response = await _apiClient.get(
          AppEndpoints.tpsTractors,
          queryParameters: {
            'per_page': '200',
            'page': currentPage.toString(),
            if (normalizedSearch.isNotEmpty) 'search': normalizedSearch,
          },
        );

        final dataList = response['data'] as List<dynamic>? ?? const [];
        tractors.addAll(
          dataList
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return item;
                }

                if (item is Map) {
                  return Map<String, dynamic>.from(item);
                }

                return <String, dynamic>{};
              })
              .where((item) => item.isNotEmpty),
        );

        lastPage = _extractLastPage(response);
        currentPage += 1;
      } while (currentPage <= lastPage);

      final options = tractors
          .map(FcaTractorOption.fromJson)
          .where((option) => option.id > 0)
          .toList();

      options.sort(
        (left, right) => left.displayLabel.toLowerCase().compareTo(
          right.displayLabel.toLowerCase(),
        ),
      );

      if (normalizedSearch.isEmpty) {
        await _persistCachedFcaTractorOptions(options);
      }

      return options;
    } on DioException catch (error) {
      if (cachedOptions.isNotEmpty) {
        return cachedOptions
            .where(
              (option) =>
                  _matchesFcaTractorOptionSearch(option, normalizedSearch),
            )
            .toList(growable: false);
      }

      throw AppException.fromDio(error);
    }
  }

  Future<void> storeDistribution({required Map<String, dynamic> data}) async {
    try {
      await _apiClient.post(AppEndpoints.tpsDistributions, data: data);
      // Refresh distributions and dashboard after successful creation
      await Future.wait([fetchDistributions(), fetchDashboard()]);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<void> storeFca({required Map<String, dynamic> data}) async {
    try {
      final formData = FormData();

      for (final entry in data.entries) {
        await _appendMultipartValue(formData, entry.key, entry.value);
      }

      await _dio.post(
        AppEndpoints.tpsFcas,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      await fetchFcas();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<void> updateFca({
    required int fcaId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final formData = FormData.fromMap({'_method': 'PUT'});

      for (final entry in data.entries) {
        await _appendMultipartValue(formData, entry.key, entry.value);
      }

      await _dio.post(
        '${AppEndpoints.tpsFcas}/$fcaId',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      await fetchFcas();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<int> saveFcaDraft({required Map<String, dynamic> data}) async {
    try {
      final response = await _apiClient.post(
        AppEndpoints.tpsFcaDrafts,
        data: data,
      );
      final draft = response['data'];

      if (draft is Map<String, dynamic>) {
        return (draft['id'] as num?)?.toInt() ?? 0;
      }

      if (draft is Map) {
        return (draft['id'] as num?)?.toInt() ?? 0;
      }

      return 0;
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<void> deleteFcaDraft(int draftId) async {
    try {
      await _apiClient.delete('${AppEndpoints.tpsFcaDrafts}/$draftId');
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<void> _appendMultipartValue(
    FormData formData,
    String key,
    dynamic value,
  ) async {
    if (value == null) {
      return;
    }

    if (value is File) {
      formData.files.add(MapEntry(key, await _multipartFileFromFile(value)));
      return;
    }

    if (value is List) {
      for (var index = 0; index < value.length; index++) {
        await _appendMultipartValue(formData, '$key[$index]', value[index]);
      }
      return;
    }

    if (value is Map<String, dynamic>) {
      for (final entry in value.entries) {
        await _appendMultipartValue(
          formData,
          '$key[${entry.key}]',
          entry.value,
        );
      }
      return;
    }

    final normalizedValue = switch (value) {
      DateTime dateTime => dateTime.toIso8601String().split('T').first,
      bool booleanValue => booleanValue ? '1' : '0',
      _ => value.toString(),
    };

    formData.fields.add(MapEntry(key, normalizedValue));
  }

  Future<MultipartFile> _multipartFileFromFile(File file) async {
    return MultipartFile.fromFile(
      file.path,
      filename: file.path.split(Platform.pathSeparator).last,
    );
  }
}
