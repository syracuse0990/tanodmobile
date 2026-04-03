import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/core/config/app_config.dart';
import 'package:tanodmobile/models/domain/ticket.dart';

class TicketProvider extends ChangeNotifier {
  TicketProvider({required ApiClient apiClient, required Dio dio})
    : _apiClient = apiClient,
      _dio = dio;

  final ApiClient _apiClient;
  final Dio _dio;

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

  List<Ticket> _tickets = [];
  bool _loading = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  String? _statusFilter;

  // Tractor list for the create form selector
  List<Map<String, dynamic>> _tractors = [];
  bool _loadingTractors = false;

  // Detail ticket
  Ticket? _selectedTicket;
  bool _loadingDetail = false;

  List<Ticket> get tickets => _tickets;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasMore => _currentPage < _lastPage;
  String? get statusFilter => _statusFilter;
  List<Map<String, dynamic>> get tractors => _tractors;
  bool get loadingTractors => _loadingTractors;
  Ticket? get selectedTicket => _selectedTicket;
  bool get loadingDetail => _loadingDetail;

  // ─── Filter ────────────────────────────────────

  void setFilter(String? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    _tickets = [];
    _currentPage = 1;
    _lastPage = 1;
    _safeNotify();
    fetchTickets();
  }

  // ─── Fetch tickets ─────────────────────────────

  Future<void> fetchTickets() async {
    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final params = <String, dynamic>{'per_page': '30', 'page': '1'};
      if (_statusFilter != null) params['status'] = _statusFilter!;

      final response = await _apiClient.get(
        AppEndpoints.tickets,
        queryParameters: params,
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _tickets = dataList
          .whereType<Map<String, dynamic>>()
          .map(Ticket.fromJson)
          .toList();
      _currentPage = (response['current_page'] as num?)?.toInt() ?? 1;
      _lastPage = (response['last_page'] as num?)?.toInt() ?? 1;
    } catch (e) {
      _error = 'Failed to load tickets';
      debugPrint('TicketProvider.fetchTickets error: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> fetchMore() async {
    if (!hasMore || _loading) return;

    _loading = true;
    _safeNotify();

    try {
      final nextPage = _currentPage + 1;
      final params = <String, dynamic>{
        'per_page': '30',
        'page': nextPage.toString(),
      };
      if (_statusFilter != null) params['status'] = _statusFilter!;

      final response = await _apiClient.get(
        AppEndpoints.tickets,
        queryParameters: params,
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      final newTickets = dataList
          .whereType<Map<String, dynamic>>()
          .map(Ticket.fromJson)
          .toList();
      _tickets = [..._tickets, ...newTickets];
      _currentPage = nextPage;
      _lastPage = (response['last_page'] as num?)?.toInt() ?? _lastPage;
    } catch (e) {
      debugPrint('TicketProvider.fetchMore error: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  // ─── Fetch single ticket detail ────────────────

  Future<void> fetchTicketDetail(int ticketId) async {
    _loadingDetail = true;
    _safeNotify();

    try {
      final response = await _apiClient.get(
        '${AppEndpoints.tickets}/$ticketId',
      );
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        _selectedTicket = Ticket.fromJson(data);
      }
    } catch (e) {
      debugPrint('TicketProvider.fetchTicketDetail error: $e');
    } finally {
      _loadingDetail = false;
      _safeNotify();
    }
  }

  // ─── Fetch tractors for selector ───────────────

  Future<void> fetchTractors() async {
    _loadingTractors = true;
    _safeNotify();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tractors,
        queryParameters: {'per_page': '200'},
      );
      final dataList = response['data'] as List<dynamic>? ?? [];
      _tractors = dataList.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('TicketProvider.fetchTractors error: $e');
    } finally {
      _loadingTractors = false;
      _safeNotify();
    }
  }

  // ─── Create ticket (multipart) ─────────────────

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
      debugPrint('TicketProvider.createTicket error: $e');
      return false;
    }
  }

  // ─── Resolve ticket (multipart) ────────────────

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
          filename: resolutionPhoto.path.split(Platform.pathSeparator).last,
        );
      }

      final formData = FormData.fromMap(formMap);

      await _dio.post(
        '${AppEndpoints.tickets}/$ticketId/resolve',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      await fetchTickets();
      return true;
    } catch (e) {
      debugPrint('TicketProvider.resolveTicket error: $e');
      return false;
    }
  }

  // ─── Add comment ───────────────────────────────

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
          _safeNotify();
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
          _safeNotify();
        }
      }

      return true;
    } catch (e) {
      debugPrint('TicketProvider.addComment error: $e');
      return false;
    }
  }

  /// Append a comment received via WebSocket (avoids duplicates).
  void appendRealtimeComment(Map<String, dynamic> commentData) {
    if (_selectedTicket == null) return;

    // Build attachment_url from path using the mobile's known server base
    final attachmentPath = commentData['attachment_path']?.toString();
    if (attachmentPath != null && attachmentPath.isNotEmpty) {
      final baseUrl = AppConfig.apiBaseUrl.replaceAll(
        RegExp(r'/api/v\d+$'),
        '',
      );
      commentData['attachment_url'] = '$baseUrl/storage/$attachmentPath';
    }

    final id = commentData['id'] as int?;
    if (id != null &&
        _selectedTicket!.comments != null &&
        _selectedTicket!.comments!.any((c) => c.id == id)) {
      return; // already exists
    }

    final comment = TicketComment.fromJson(commentData);
    _selectedTicket = _selectedTicket!.copyWithNewComment(comment);
    _safeNotify();
  }
}
