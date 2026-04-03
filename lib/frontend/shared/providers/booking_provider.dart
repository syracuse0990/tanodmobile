import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/models/domain/booking.dart';

class BookingProvider extends ChangeNotifier {
  BookingProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Safe wrapper that defers notifyListeners when called during the build phase.
  void _safeNotify() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  List<Booking> _bookings = [];
  bool _loading = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  String? _statusFilter;

  // Tractor list for the selector
  List<Map<String, dynamic>> _tractors = [];
  bool _loadingTractors = false;

  // Booking slots
  List<Map<String, dynamic>> _slots = [];

  // Farmers list (for FCA)
  List<Map<String, dynamic>> _farmers = [];
  bool _loadingFarmers = false;

  List<Booking> get bookings => _bookings;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasMore => _currentPage < _lastPage;
  String? get statusFilter => _statusFilter;
  List<Map<String, dynamic>> get tractors => _tractors;
  bool get loadingTractors => _loadingTractors;
  List<Map<String, dynamic>> get slots => _slots;
  List<Map<String, dynamic>> get farmers => _farmers;
  bool get loadingFarmers => _loadingFarmers;

  // ─── Filter helpers ────────────────────────────

  List<Booking> get upcoming =>
      _bookings.where((b) => b.status == 'pending' || b.status == 'approved').toList();

  List<Booking> get completed =>
      _bookings.where((b) => b.status == 'rejected' || b.status == 'cancelled').toList();

  /// All bookings grouped by date for calendar view.
  /// Multi-day bookings appear on every day from startDate to endDate.
  Map<DateTime, List<Booking>> get bookingsByDate {
    final map = <DateTime, List<Booking>>{};
    for (final b in _bookings) {
      final start = b.startDate ?? b.bookingDate;
      final end = b.endDate ?? start;
      final from = DateTime(start.year, start.month, start.day);
      final to = DateTime(end.year, end.month, end.day);
      for (var d = from;
          !d.isAfter(to);
          d = d.add(const Duration(days: 1))) {
        map.putIfAbsent(d, () => []).add(b);
      }
    }
    return map;
  }

  // ─── Set status filter ─────────────────────────

  void setFilter(String? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    _bookings = [];
    _currentPage = 1;
    _lastPage = 1;
    _safeNotify();
    fetchBookings();
  }

  // ─── Fetch bookings ────────────────────────────

  Future<void> fetchBookings() async {
    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final params = <String, dynamic>{'per_page': '30', 'page': '1'};
      if (_statusFilter != null) params['status'] = _statusFilter!;

      final response = await _apiClient.get(
        AppEndpoints.bookings,
        queryParameters: params,
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _bookings = dataList
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList();
      _currentPage = (response['current_page'] as num?)?.toInt() ?? 1;
      _lastPage = (response['last_page'] as num?)?.toInt() ?? 1;
    } catch (e) {
      _error = 'Failed to load bookings';
      debugPrint('BookingProvider.fetchBookings error: $e');
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
        AppEndpoints.bookings,
        queryParameters: params,
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      final newBookings = dataList
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList();
      _bookings = [..._bookings, ...newBookings];
      _currentPage = nextPage;
      _lastPage = (response['last_page'] as num?)?.toInt() ?? _lastPage;
    } catch (e) {
      debugPrint('BookingProvider.fetchMore error: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  // ─── Fetch tractor list for selector ───────────

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
      debugPrint('BookingProvider.fetchTractors error: $e');
    } finally {
      _loadingTractors = false;
      _safeNotify();
    }
  }

  // ─── Fetch booking slots ───────────────────────

  Future<void> fetchSlots() async {
    try {
      final response = await _apiClient.get(AppEndpoints.bookingSlots);
      final dataList = response['data'] as List<dynamic>? ??
          (response is List ? response as List<dynamic> : []);
      _slots = dataList.whereType<Map<String, dynamic>>().toList();
      _safeNotify();
    } catch (e) {
      debugPrint('BookingProvider.fetchSlots error: $e');
    }
  }

  // ─── Fetch farmers (FCA role) ──────────────────

  Future<void> fetchFarmers() async {
    _loadingFarmers = true;
    _safeNotify();

    try {
      final response = await _apiClient.get(AppEndpoints.myFarmers);
      final dataList = response is List
          ? response as List<dynamic>
          : (response['data'] as List<dynamic>? ?? []);
      _farmers = dataList.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('BookingProvider.fetchFarmers error: $e');
    } finally {
      _loadingFarmers = false;
      _safeNotify();
    }
  }

  // ─── Create booking ───────────────────────────

  Future<bool> createBooking({
    required int tractorId,
    required String bookingDate,
    required String purpose,
    int? farmerId,
    String? startDate,
    String? endDate,
    String? startTime,
    String? endTime,
    double? farmAreaHectares,
    String? notes,
  }) async {
    try {
      await _apiClient.post(AppEndpoints.bookings, data: {
        'tractor_id': tractorId,
        'booking_date': bookingDate,
        'purpose': purpose,
        if (farmerId != null) 'farmer_id': farmerId,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (startTime != null) 'start_time': startTime,
        if (endTime != null) 'end_time': endTime,
        if (farmAreaHectares != null) 'farm_area_hectares': farmAreaHectares,
        if (notes != null) 'notes': notes,
      });
      await fetchBookings();
      return true;
    } catch (e) {
      debugPrint('BookingProvider.createBooking error: $e');
      return false;
    }
  }

  // ─── Cancel booking ───────────────────────────

  Future<bool> cancelBooking(int bookingId) async {
    try {
      await _apiClient.post('${AppEndpoints.bookings}/$bookingId/cancel');

      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        final old = _bookings[index];
        _bookings[index] = Booking(
          id: old.id,
          status: 'cancelled',
          bookingDate: old.bookingDate,
          startDate: old.startDate,
          endDate: old.endDate,
          purpose: old.purpose,
          farmAreaHectares: old.farmAreaHectares,
          notes: old.notes,
          startTime: old.startTime,
          endTime: old.endTime,
          tractorId: old.tractorId,
          tractorLabel: old.tractorLabel,
          tractorBrand: old.tractorBrand,
          tractorModel: old.tractorModel,
          bookedByName: old.bookedByName,
          approvedByName: old.approvedByName,
          farmerId: old.farmerId,
          farmerName: old.farmerName,
          createdAt: old.createdAt,
        );
        _safeNotify();
      }
      return true;
    } catch (e) {
      debugPrint('BookingProvider.cancelBooking error: $e');
      return false;
    }
  }

  // ─── Update booking ──────────────────────────

  Future<bool> updateBooking({
    required int bookingId,
    int? tractorId,
    String? bookingDate,
    String? startDate,
    String? endDate,
    String? startTime,
    String? endTime,
    String? purpose,
    double? farmAreaHectares,
    String? notes,
  }) async {
    try {
      await _apiClient.put('${AppEndpoints.bookings}/$bookingId', data: {
        if (tractorId != null) 'tractor_id': tractorId,
        if (bookingDate != null) 'booking_date': bookingDate,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (startTime != null) 'start_time': startTime,
        if (endTime != null) 'end_time': endTime,
        if (purpose != null) 'purpose': purpose,
        if (farmAreaHectares != null) 'farm_area_hectares': farmAreaHectares,
        if (notes != null) 'notes': notes,
      });
      await fetchBookings();
      return true;
    } catch (e) {
      debugPrint('BookingProvider.updateBooking error: $e');
      return false;
    }
  }

  // ─── Approve booking (FCA / Admin) ────────────

  Future<bool> approveBooking(int bookingId) async {
    try {
      await _apiClient.post('${AppEndpoints.bookings}/$bookingId/approve');
      await fetchBookings();
      return true;
    } catch (e) {
      debugPrint('BookingProvider.approveBooking error: $e');
      return false;
    }
  }

  // ─── Reject booking (FCA / Admin) ─────────────

  Future<bool> rejectBooking(int bookingId, String reason) async {
    try {
      await _apiClient.post(
        '${AppEndpoints.bookings}/$bookingId/reject',
        data: {'reason': reason},
      );
      await fetchBookings();
      return true;
    } catch (e) {
      debugPrint('BookingProvider.rejectBooking error: $e');
      return false;
    }
  }
}
