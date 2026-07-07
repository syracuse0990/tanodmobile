import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/core/utils/url_helper.dart';
import 'package:tanodmobile/frontend/modules/tickets/models/ticket_issue_photo.dart';
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
  List<Ticket> _chatTickets = [];
  bool _loading = false;
  bool _chatLoading = false;
  String? _error;
  String? _chatError;
  int _currentPage = 1;
  int _chatCurrentPage = 1;
  int _lastPage = 1;
  int _chatLastPage = 1;
  String? _statusFilter;

  // Tractor list for the create form selector
  List<Map<String, dynamic>> _tractors = [];
  bool _loadingTractors = false;

  // Detail ticket
  Ticket? _selectedTicket;
  bool _loadingDetail = false;

  List<Ticket> get tickets => _tickets;
  List<Ticket> get chatTickets => _chatTickets;
  bool get loading => _loading;
  bool get chatLoading => _chatLoading;
  String? get error => _error;
  String? get chatError => _chatError;
  bool get hasMore => _currentPage < _lastPage;
  bool get hasMoreChatTickets => _chatCurrentPage < _chatLastPage;
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

  Map<String, dynamic> _ticketQueryParameters({
    required int page,
    String? status,
    bool forChat = false,
  }) {
    return {
      'per_page': '30',
      'page': page.toString(),
      'status': ?status,
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

  // ─── Fetch tickets ─────────────────────────────

  Future<void> fetchTickets() async {
    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tickets,
        queryParameters: _ticketQueryParameters(page: 1, status: _statusFilter),
      );

      _tickets = _parseTicketList(response);
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
      final response = await _apiClient.get(
        AppEndpoints.tickets,
        queryParameters: _ticketQueryParameters(
          page: nextPage,
          status: _statusFilter,
        ),
      );

      final newTickets = _parseTicketList(response);
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

  Future<void> fetchChatTickets() async {
    _chatLoading = true;
    _chatError = null;
    _safeNotify();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tickets,
        queryParameters: _ticketQueryParameters(page: 1, forChat: true),
      );

      _chatTickets = _parseTicketList(response);
      _chatCurrentPage = (response['current_page'] as num?)?.toInt() ?? 1;
      _chatLastPage = (response['last_page'] as num?)?.toInt() ?? 1;
    } catch (e) {
      _chatError = 'Failed to load chat rooms';
      debugPrint('TicketProvider.fetchChatTickets error: $e');
    } finally {
      _chatLoading = false;
      _safeNotify();
    }
  }

  Future<void> fetchMoreChatTickets() async {
    if (!hasMoreChatTickets || _chatLoading) {
      return;
    }

    _chatLoading = true;
    _safeNotify();

    try {
      final nextPage = _chatCurrentPage + 1;
      final response = await _apiClient.get(
        AppEndpoints.tickets,
        queryParameters: _ticketQueryParameters(page: nextPage, forChat: true),
      );

      final newTickets = _parseTicketList(response);
      _chatTickets = [..._chatTickets, ...newTickets];
      _chatCurrentPage = nextPage;
      _chatLastPage = (response['last_page'] as num?)?.toInt() ?? _chatLastPage;
    } catch (e) {
      debugPrint('TicketProvider.fetchMoreChatTickets error: $e');
    } finally {
      _chatLoading = false;
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

  Future<Ticket?> createTicket({
    required String subject,
    required String description,
    String priority = 'medium',
    String? category,
    int? tractorId,
    DateTime? dateOfFailure,
    File? nameplatePhoto,
    File? dashboardPhoto,
    List<File>? damagePhotos,
    List<Map<String, dynamic>>? pmsChecklist,
    bool autoResolve = false,
    String? actionTaken,
  }) async {
    try {
      final formMap = <String, dynamic>{
        'subject': subject,
        'description': description,
        'priority': priority,
        'category': ?category,
        'tractor_id': ?tractorId,
        if (dateOfFailure != null) 'reported_date': dateOfFailure.toIso8601String().split('T').first,
      };

      if (nameplatePhoto != null) {
        formMap['nameplate_photo'] = await MultipartFile.fromFile(
          nameplatePhoto.path,
          filename: nameplatePhoto.path.split(Platform.pathSeparator).last,
        );
      }
      if (dashboardPhoto != null) {
        formMap['dashboard_photo'] = await MultipartFile.fromFile(
          dashboardPhoto.path,
          filename: dashboardPhoto.path.split(Platform.pathSeparator).last,
        );
      }
      if (damagePhotos != null && damagePhotos.isNotEmpty) {
        for (var i = 0; i < damagePhotos.length; i++) {
          formMap['damage_photos[$i]'] = await MultipartFile.fromFile(
            damagePhotos[i].path,
            filename: damagePhotos[i].path.split(Platform.pathSeparator).last,
          );
        }
      }

      // PMS checklist
      if (pmsChecklist != null && pmsChecklist.isNotEmpty) {
        for (var i = 0; i < pmsChecklist.length; i++) {
          formMap['pms_checklist[$i][name]'] = pmsChecklist[i]['name'];
          formMap['pms_checklist[$i][done]'] = pmsChecklist[i]['done'] == true ? '1' : '0';
          if (pmsChecklist[i]['notes'] != null) {
            formMap['pms_checklist[$i][notes]'] = pmsChecklist[i]['notes'];
          }
        }
      }

      // Auto-resolve & action taken (for PMS self-service)
      if (autoResolve) {
        formMap['auto_resolve'] = '1';
      }
      if (actionTaken != null) {
        formMap['action_taken'] = actionTaken;
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
      debugPrint('TicketProvider.createTicket error: $e');
      return null;
    }
  }

  // ─── Resolve ticket (multipart) ────────────────

  Future<bool> resolveTicket({
    required int ticketId,
    String? resolutionNotes,
    File? resolutionPhoto,
    double? serviceCharge,
    double? downPayment,
    int? installments,
    bool partial = false,
    List<Map<String, dynamic>>? parts,
    List<File>? drPhotos,
    List<String>? keepDrPhotos,
  }) async {
    try {
      final formMap = <String, dynamic>{
        'resolution_notes': resolutionNotes,
        if (partial) 'partial': '1',
      };

      if (resolutionPhoto != null) {
        formMap['resolution_photo'] = await MultipartFile.fromFile(
          resolutionPhoto.path,
          filename: resolutionPhoto.path.split(Platform.pathSeparator).last,
        );
      }

      if (serviceCharge != null) {
        formMap['service_charge'] = serviceCharge.toString();
      }

      if (downPayment != null) {
        formMap['down_payment'] = downPayment.toString();
      }

      if (installments != null) {
        formMap['installments'] = installments.toString();
      }

      if (parts != null && parts.isNotEmpty) {
        for (var i = 0; i < parts.length; i++) {
          formMap['parts[$i][id]'] = parts[i]['id'].toString();
          formMap['parts[$i][amount]'] = parts[i]['amount'].toString();
        }
      }

      if (drPhotos != null && drPhotos.isNotEmpty) {
        debugPrint('TicketProvider.resolveTicket: attaching ${drPhotos.length} new DR photo(s)');
        for (var i = 0; i < drPhotos.length; i++) {
          formMap['dr_photos[$i]'] = await MultipartFile.fromFile(
            drPhotos[i].path,
            filename: drPhotos[i].path.split(Platform.pathSeparator).last,
          );
        }
      }

      if (keepDrPhotos != null && keepDrPhotos.isNotEmpty) {
        debugPrint('TicketProvider.resolveTicket: preserving ${keepDrPhotos.length} existing DR photo URL(s)');
        for (var i = 0; i < keepDrPhotos.length; i++) {
          formMap['keep_dr_photos[$i]'] = keepDrPhotos[i];
        }
      }

      final formData = FormData.fromMap(formMap);

      await _dio.post(
        '${AppEndpoints.tickets}/$ticketId/resolve',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      await Future.wait([fetchTickets(), fetchChatTickets()]);
      return true;
    } catch (e) {
      debugPrint('TicketProvider.resolveTicket error: $e');
      return false;
    }
  }

  // ─── Validate photo (AI) ───────────────────────

  Future<TicketIssuePhotoValidationResult> validatePhoto({
    required File photo,
    required String type,
  }) async {
    try {
      final formMap = <String, dynamic>{
        'type': type,
      };

      formMap['photo'] = await MultipartFile.fromFile(
        photo.path,
        filename: photo.path.split(Platform.pathSeparator).last,
      );

      final formData = FormData.fromMap(formMap);

      final response = await _dio.post(
        AppEndpoints.ticketValidatePhoto,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      return TicketIssuePhotoValidationResult(
        valid: data['valid'] == true,
        message: data['message']?.toString() ?? '',
      );
    } on DioException {
      // Fail-open on network errors
      return const TicketIssuePhotoValidationResult(
        valid: true,
        message: 'Validation skipped.',
      );
    } catch (e) {
      debugPrint('validatePhoto error: $e');
      return const TicketIssuePhotoValidationResult(
        valid: true,
        message: 'Validation skipped.',
      );
    }
  }

  // ─── Add comment ───────────────────────────────

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
          _safeNotify();
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
          _safeNotify();
        }
      }

      return true;
    } catch (e) {
      debugPrint('TicketProvider.addComment error: $e');
      if (e is DioException) {
        debugPrint('  status: ${e.response?.statusCode}');
        debugPrint('  body: ${e.response?.data}');
      }
      return false;
    }
  }

  /// Append a comment received via WebSocket (avoids duplicates).
  void appendRealtimeComment(Map<String, dynamic> commentData) {
    // Build attachment_url from path using the mobile's known server base
    final attachmentPath = commentData['attachment_path']?.toString();
    commentData['attachment_url'] = UrlHelper.fixStorageUrl(
      commentData['attachment_url']?.toString() ?? attachmentPath,
    );

    final id = commentData['id'] as int?;
    if (id != null &&
        _selectedTicket != null &&
        _selectedTicket!.comments != null &&
        _selectedTicket!.comments!.any((c) => c.id == id)) {
      return; // already exists
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

    _safeNotify();
  }
}
