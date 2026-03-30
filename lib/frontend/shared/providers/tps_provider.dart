import 'package:flutter/foundation.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/models/domain/distribution.dart';
import 'package:tanodmobile/models/domain/farmer_feedback.dart';
import 'package:tanodmobile/models/domain/ticket.dart';

class TpsProvider extends ChangeNotifier {
  TpsProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  // Dashboard stats
  int tractorsCount = 0;
  int openTickets = 0;
  int pendingMaintenance = 0;
  int activeDistributions = 0;
  bool _dashboardLoading = false;
  bool get dashboardLoading => _dashboardLoading;

  // Tickets
  List<Ticket> _tickets = [];
  bool _ticketsLoading = false;
  String? _ticketsError;
  int _ticketsPage = 1;
  int _ticketsLastPage = 1;

  List<Ticket> get tickets => _tickets;
  bool get ticketsLoading => _ticketsLoading;
  String? get ticketsError => _ticketsError;
  bool get hasMoreTickets => _ticketsPage < _ticketsLastPage;

  // Feedbacks
  List<FarmerFeedbackItem> _feedbacks = [];
  bool _feedbacksLoading = false;

  List<FarmerFeedbackItem> get feedbacks => _feedbacks;
  bool get feedbacksLoading => _feedbacksLoading;

  // Tractors
  List<Map<String, dynamic>> _tractors = [];
  bool _tractorsLoading = false;

  List<Map<String, dynamic>> get tractors => _tractors;
  bool get tractorsLoading => _tractorsLoading;

  // Distributions
  List<Distribution> _distributions = [];
  bool _distributionsLoading = false;

  List<Distribution> get distributions => _distributions;
  bool get distributionsLoading => _distributionsLoading;

  // ─── Dashboard ─────────────────────────────────

  Future<void> fetchDashboard() async {
    _dashboardLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(AppEndpoints.tpsDashboard);
      tractorsCount = (response['tractors_count'] as num?)?.toInt() ?? 0;
      openTickets = (response['open_tickets'] as num?)?.toInt() ?? 0;
      pendingMaintenance = (response['pending_maintenance'] as num?)?.toInt() ?? 0;
      activeDistributions = (response['active_distributions'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('TpsProvider.fetchDashboard error: $e');
    } finally {
      _dashboardLoading = false;
      notifyListeners();
    }
  }

  // ─── Tickets ───────────────────────────────────

  Future<void> fetchTickets({String? status}) async {
    _ticketsLoading = true;
    _ticketsError = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{'per_page': '20', 'page': '1'};
      if (status != null) params['status'] = status;

      final response = await _apiClient.get(
        AppEndpoints.tpsTickets,
        queryParameters: params,
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _tickets = dataList
          .whereType<Map<String, dynamic>>()
          .map(Ticket.fromJson)
          .toList();
      _ticketsPage = (response['current_page'] as num?)?.toInt() ?? 1;
      _ticketsLastPage = (response['last_page'] as num?)?.toInt() ?? 1;
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
      final params = <String, dynamic>{
        'per_page': '20',
        'page': nextPage.toString(),
      };
      if (status != null) params['status'] = status;

      final response = await _apiClient.get(
        AppEndpoints.tpsTickets,
        queryParameters: params,
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      final newTickets = dataList
          .whereType<Map<String, dynamic>>()
          .map(Ticket.fromJson)
          .toList();
      _tickets = [..._tickets, ...newTickets];
      _ticketsPage = nextPage;
      _ticketsLastPage = (response['last_page'] as num?)?.toInt() ?? _ticketsLastPage;
    } catch (e) {
      debugPrint('TpsProvider.fetchMoreTickets error: $e');
    } finally {
      _ticketsLoading = false;
      notifyListeners();
    }
  }

  // ─── Feedbacks ────────────────────────────────

  Future<void> fetchFeedbacks() async {
    _feedbacksLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsFeedbacks,
        queryParameters: {'per_page': '30'},
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _feedbacks = dataList
          .whereType<Map<String, dynamic>>()
          .map(FarmerFeedbackItem.fromJson)
          .toList();
    } catch (e) {
      debugPrint('TpsProvider.fetchFeedbacks error: $e');
    } finally {
      _feedbacksLoading = false;
      notifyListeners();
    }
  }

  // ─── Tractors ──────────────────────────────────

  Future<void> fetchTractors() async {
    _tractorsLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsTractors,
        queryParameters: {'per_page': '100'},
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _tractors = dataList.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('TpsProvider.fetchTractors error: $e');
    } finally {
      _tractorsLoading = false;
      notifyListeners();
    }
  }

  // ─── Distributions ─────────────────────────────

  Future<void> fetchDistributions() async {
    _distributionsLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsDistributions,
        queryParameters: {'per_page': '30'},
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _distributions = dataList
          .whereType<Map<String, dynamic>>()
          .map(Distribution.fromJson)
          .toList();
    } catch (e) {
      debugPrint('TpsProvider.fetchDistributions error: $e');
    } finally {
      _distributionsLoading = false;
      notifyListeners();
    }
  }

  // ─── Load all data ─────────────────────────────

  Future<void> loadAll() async {
    await Future.wait([
      fetchDashboard(),
      fetchTickets(),
      fetchFeedbacks(),
      fetchTractors(),
      fetchDistributions(),
    ]);
  }
}
