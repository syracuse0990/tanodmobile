import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';

class ReportProvider extends ChangeNotifier {
  ReportProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  List<ReportSection> _sections = [];
  bool _loading = false;
  String? _error;

  List<ReportSection> get sections => _sections;
  bool get loading => _loading;
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
