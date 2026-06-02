import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/fca_survey_section.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

void main() {
  group('TpsProvider FCA locations', () {
    test('fetchFcaCities parses map-shaped location payloads', () async {
      final provider = _buildProvider(
        responses: {
          AppEndpoints.tpsFcaLocationCities: {
            'data': {
              '0': {'code': '034932', 'name': 'ZARAGOZA'},
              '1': {'code': '034933', 'name': 'CITY OF TEST'},
            },
          },
        },
      );

      final cities = await provider.fetchFcaCities(provinceCode: '0349');

      expect(cities, hasLength(2));
      expect(cities[0].code, '034932');
      expect(cities[0].name, 'ZARAGOZA');
      expect(cities[1].code, '034933');
      expect(cities[1].name, 'CITY OF TEST');
    });

    test('fetchFcaBarangays parses map-shaped location payloads', () async {
      final provider = _buildProvider(
        responses: {
          AppEndpoints.tpsFcaLocationBarangays: {
            'data': {
              '0': {'code': '034932001', 'name': 'Batitang'},
              '1': {'code': '034932003', 'name': 'Carmen'},
            },
          },
        },
      );

      final barangays = await provider.fetchFcaBarangays(
        cityMunicipalityCode: '034932',
      );

      expect(barangays, hasLength(2));
      expect(barangays[0].code, '034932001');
      expect(barangays[0].name, 'Batitang');
      expect(barangays[1].code, '034932003');
      expect(barangays[1].name, 'Carmen');
    });
  });

  group('FcaSurveySection restore', () {
    testWidgets('restores sparse initial answers without throwing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildSurveyHarness(
          initialAnswers: const [
            {
              'question_number': 1,
              'entry_order': 0,
              'answer_text': 'Sa bukid tuwing umaga',
            },
            {
              'question_number': 3,
              'entry_order': 0,
              'answer_text': 'Minsang mahirap paandarin',
            },
          ],
          initialHasPmsSchedule: true,
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Sa bukid tuwing umaga'), findsOneWidget);
      expect(find.text('Minsang mahirap paandarin'), findsOneWidget);
    });

    testWidgets('updates restored answers without throwing on sparse groups', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildSurveyHarness(
          initialAnswers: const [
            {
              'question_number': 1,
              'entry_order': 0,
              'answer_text': 'Original answer',
            },
          ],
          initialHasPmsSchedule: true,
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _buildSurveyHarness(
          initialAnswers: const [
            {
              'question_number': 2,
              'entry_order': 0,
              'answer_text': 'Updated answer',
            },
          ],
          initialHasPmsSchedule: false,
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Updated answer'), findsOneWidget);
      expect(find.text('Original answer'), findsNothing);
    });
  });
}

TpsProvider _buildProvider({
  required Map<String, Map<String, dynamic>> responses,
}) {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final response = responses[options.path];
          if (response != null) {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: response,
                statusCode: 200,
              ),
            );
            return;
          }

          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Unexpected path: ${options.path}',
            ),
          );
        },
      ),
    );

  return TpsProvider(
    apiClient: ApiClient(dio),
    dio: dio,
    hiveService: _FakeHiveService(),
  );
}

class _FakeHiveService extends HiveService {
  final Map<String, String> _preferences = <String, String>{};

  @override
  String? getPreference(String key) {
    return _preferences[key];
  }

  @override
  Future<void> savePreference(String key, String value) async {
    _preferences[key] = value;
  }

  @override
  Future<void> removePreference(String key) async {
    _preferences.remove(key);
  }
}

Widget _buildSurveyHarness({
  required List<Map<String, dynamic>> initialAnswers,
  required bool? initialHasPmsSchedule,
}) {
  return MaterialApp(
    home: Scaffold(
      body: FcaSurveySection(
        initialAnswers: initialAnswers,
        initialHasPmsSchedule: initialHasPmsSchedule,
      ),
    ),
  );
}
