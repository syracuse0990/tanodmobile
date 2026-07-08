import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/models/domain/ticket_report.dart';

class ReportProvider extends ChangeNotifier {
  ReportProvider({required ApiClient apiClient, Dio? dio})
    : _apiClient = apiClient,
      _dio = dio;

  final ApiClient _apiClient;
  final Dio? _dio;

  List<ReportSection> _sections = [];
  bool _loading = false;
  String? _error;

  // Ticket Reports
  List<TicketReport> _ticketReports = [];
  bool _ticketReportsLoading = false;
  String? _ticketReportsError;
  int _ticketReportsPage = 1;
  int _ticketReportsLastPage = 1;

  TicketReport? _selectedTicketReport;
  bool _ticketReportLoading = false;
  bool _ticketReportSaving = false;

  List<ReportSection> get sections => _sections;
  bool get loading => _loading;
  String? get error => _error;

  List<TicketReport> get ticketReports => _ticketReports;
  bool get ticketReportsLoading => _ticketReportsLoading;
  String? get ticketReportsError => _ticketReportsError;
  bool get hasMoreTicketReports => _ticketReportsPage < _ticketReportsLastPage;

  TicketReport? get selectedTicketReport => _selectedTicketReport;
  bool get ticketReportLoading => _ticketReportLoading;
  bool get ticketReportSaving => _ticketReportSaving;

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

  Future<void> fetchReports() async {
    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final response = await _apiClient.get(AppEndpoints.reports);
      final dataList = response['data'] as List<dynamic>? ?? [];
      _sections = dataList
          .whereType<Map<String, dynamic>>()
          .map(ReportSection.fromJson)
          .toList(growable: false);
      _error = null;
    } catch (e) {
      _error = 'Failed to load reports';
      debugPrint('ReportProvider.fetchReports error: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  // ─── Ticket Reports ───────────────────────────

  Future<void> fetchTicketReports({bool refresh = false}) async {
    if (refresh) {
      _ticketReportsPage = 1;
      _ticketReportsLastPage = 1;
      _ticketReports = [];
    }

    _ticketReportsLoading = true;
    _ticketReportsError = null;
    _safeNotify();

    try {
      final response = await _apiClient.get(
        AppEndpoints.tpsTicketReports,
        queryParameters: {
          'per_page': '20',
          'page': _ticketReportsPage.toString(),
        },
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      final reports = dataList
          .whereType<Map<String, dynamic>>()
          .map(TicketReport.fromJson)
          .toList();

      if (refresh) {
        _ticketReports = reports;
      } else {
        _ticketReports = [..._ticketReports, ...reports];
      }

      _ticketReportsPage = (response['current_page'] as num?)?.toInt() ?? 1;
      _ticketReportsLastPage = (response['last_page'] as num?)?.toInt() ?? 1;
    } catch (e) {
      _ticketReportsError = 'Failed to load ticket reports';
      debugPrint('ReportProvider.fetchTicketReports error: $e');
    } finally {
      _ticketReportsLoading = false;
      _safeNotify();
    }
  }

  Future<void> fetchMoreTicketReports() async {
    if (!hasMoreTicketReports || _ticketReportsLoading) return;
    _ticketReportsPage++;
    await fetchTicketReports();
  }

  Future<void> fetchTicketReportDetail(int reportId) async {
    _ticketReportLoading = true;
    _selectedTicketReport = null;
    _safeNotify();

    try {
      final response = await _apiClient.get(AppEndpoints.tpsTicketReport(reportId));
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        _selectedTicketReport = TicketReport.fromJson(data);
      }
    } catch (e) {
      debugPrint('ReportProvider.fetchTicketReportDetail error: $e');
    } finally {
      _ticketReportLoading = false;
      _safeNotify();
    }
  }

  Future<bool> updateTicketReport(int reportId, Map<String, dynamic> data) async {
    _ticketReportSaving = true;
    _safeNotify();

    try {
      final response = await _apiClient.put(
        AppEndpoints.tpsTicketReport(reportId),
        data: data,
      );

      final responseData = response['data'] as Map<String, dynamic>?;
      if (responseData != null) {
        _selectedTicketReport = TicketReport.fromJson(responseData);
      }
      return true;
    } catch (e) {
      debugPrint('ReportProvider.updateTicketReport error: $e');
      return false;
    } finally {
      _ticketReportSaving = false;
      _safeNotify();
    }
  }

  Future<String?> downloadTicketReportPdf(int reportId) async {
    try {
      final response = await _dio?.get(
        AppEndpoints.tpsTicketReportPdf(reportId),
        options: Options(responseType: ResponseType.bytes),
      );
      if (response?.data != null) {
        return response?.data;
      }
      return null;
    } catch (e) {
      debugPrint('ReportProvider.downloadTicketReportPdf error: $e');
      return null;
    }
  }
}

class ReportSection {
  const ReportSection({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final String icon;
  final List<ReportRow> rows;

  factory ReportSection.fromJson(Map<String, dynamic> json) {
    final rowList = json['rows'] as List<dynamic>? ?? [];
    return ReportSection(
      title: json['title']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      rows: rowList
          .whereType<Map<String, dynamic>>()
          .map(ReportRow.fromJson)
          .toList(growable: false),
    );
  }
}

class ReportRow {
  const ReportRow({required this.label, required this.value});

  final String label;
  final String value;

  factory ReportRow.fromJson(Map<String, dynamic> json) {
    return ReportRow(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '0',
    );
  }
}
