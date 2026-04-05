import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/models/domain/distribution.dart';
import 'package:tanodmobile/models/domain/farmer_feedback.dart';
import 'package:tanodmobile/models/domain/ticket.dart';

class TpsProvider extends ChangeNotifier {
  TpsProvider({required ApiClient apiClient, required Dio dio})
    : _apiClient = apiClient,
      _dio = dio;

  final ApiClient _apiClient;
  final Dio _dio;

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
      _ticketTractors =
          tractorList.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('TpsProvider.fetchTicketFormData error: $e');
    } finally {
      _loadingTicketFormData = false;
      notifyListeners();
    }
  }

  // ─── Create Ticket (multipart) ─────────────────

  Future<bool> createTicket({
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
        if (category != null) 'category': category,
        if (tractorId != null) 'tractor_id': tractorId,
      };

      if (photo != null) {
        formMap['photo'] = await MultipartFile.fromFile(
          photo.path,
          filename: photo.path.split(Platform.pathSeparator).last,
        );
      }

      final formData = FormData.fromMap(formMap);

      await _dio.post(
        AppEndpoints.tickets,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      await fetchTickets();
      return true;
    } catch (e) {
      debugPrint('TpsProvider.createTicket error: $e');
      return false;
    }
  }

  // ─── Resolve Ticket (multipart) ────────────────

  Future<bool> resolveTicket({
    required int ticketId,
    String? resolutionNotes,
    File? resolutionPhoto,
  }) async {
    try {
      final formMap = <String, dynamic>{
        if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
      };

      if (resolutionPhoto != null) {
        formMap['resolution_photo'] = await MultipartFile.fromFile(
          resolutionPhoto.path,
          filename:
              resolutionPhoto.path.split(Platform.pathSeparator).last,
        );
      }

      final formData = FormData.fromMap(formMap);

      await _dio.post(
        '${AppEndpoints.tickets}/$ticketId/resolve',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      await fetchTicketDetail(ticketId);
      return true;
    } catch (e) {
      debugPrint('TpsProvider.resolveTicket error: $e');
      return false;
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
  }) async {
    try {
      if (attachment != null) {
        final formMap = <String, dynamic>{
          if (body != null && body.isNotEmpty) 'body': body,
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
        if (data != null && _selectedTicket != null) {
          final comment = TicketComment.fromJson(data);
          _selectedTicket = _selectedTicket!.copyWithNewComment(comment);
          notifyListeners();
        }
      } else {
        final response = await _apiClient.post(
          '${AppEndpoints.tickets}/$ticketId/comment',
          data: {'body': body},
        );

        final data = response['data'] as Map<String, dynamic>?;
        if (data != null && _selectedTicket != null) {
          final comment = TicketComment.fromJson(data);
          _selectedTicket = _selectedTicket!.copyWithNewComment(comment);
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
    if (_selectedTicket == null) return;
    final comment = TicketComment.fromJson(commentData);
    _selectedTicket = _selectedTicket!.copyWithNewComment(comment);
    notifyListeners();
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

  // ─── Distribution Form Data ────────────────────

  Future<Map<String, dynamic>> fetchDistributionFormData() async {
    try {
      return await _apiClient.get(AppEndpoints.tpsDistributionFormData);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<void> storeDistribution({
    required Map<String, dynamic> data,
  }) async {
    try {
      await _apiClient.post(AppEndpoints.tpsDistributions, data: data);
      // Refresh distributions and dashboard after successful creation
      await Future.wait([fetchDistributions(), fetchDashboard()]);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }
}
