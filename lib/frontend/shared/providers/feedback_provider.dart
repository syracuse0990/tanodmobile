import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/models/domain/farmer_feedback.dart';

class FeedbackProvider extends ChangeNotifier {
  FeedbackProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  List<FarmerFeedbackItem> _feedbacks = [];
  List<FeedbackTractorOption> _tractorOptions = [];
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  List<FarmerFeedbackItem> get feedbacks => _feedbacks;
  List<FeedbackTractorOption> get tractorOptions => _tractorOptions;
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

  Future<void> fetchFeedbacks() async {
    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final response = await _apiClient.get(
        AppEndpoints.feedbacks,
        queryParameters: {'per_page': '50'},
      );

      final dataList = response['data'] as List<dynamic>? ?? [];
      _feedbacks = dataList
          .whereType<Map<String, dynamic>>()
          .map(FarmerFeedbackItem.fromJson)
          .toList(growable: false);
      _error = null;
    } catch (e) {
      _error = 'Failed to load feedbacks';
      debugPrint('FeedbackProvider.fetchFeedbacks error: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> fetchTractorOptions() async {
    try {
      final response =
          await _apiClient.get(AppEndpoints.feedbackTractors);
      final dataList = response['data'] as List<dynamic>? ?? [];
      _tractorOptions = dataList
          .whereType<Map<String, dynamic>>()
          .map(FeedbackTractorOption.fromJson)
          .toList(growable: false);
      _safeNotify();
    } catch (e) {
      debugPrint('FeedbackProvider.fetchTractorOptions error: $e');
    }
  }

  Future<bool> submitFeedback({
    required int tractorId,
    required int rating,
    required String feedback,
    String? category,
  }) async {
    _submitting = true;
    _error = null;
    _safeNotify();

    try {
      final data = <String, dynamic>{
        'tractor_id': tractorId,
        'rating': rating,
        'feedback': feedback,
      };
      if (category != null && category.isNotEmpty) {
        data['category'] = category;
      }

      await _apiClient.post(AppEndpoints.feedbacks, data: data);

      _submitting = false;
      _safeNotify();
      return true;
    } catch (e) {
      _error = 'Failed to submit feedback';
      debugPrint('FeedbackProvider.submitFeedback error: $e');
      _submitting = false;
      _safeNotify();
      return false;
    }
  }
}
