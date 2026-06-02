import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/frontend/modules/tps/screens/tps_create_fca_screen.dart';
import 'package:tanodmobile/frontend/modules/tps/screens/tps_offline_fca_draft_screen.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/models/domain/fca_tractor_option.dart';
import 'package:tanodmobile/models/domain/location_option.dart';
import 'package:tanodmobile/models/domain/tps_user_option.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

void main() {
  testWidgets('Offline Revisit draft screen uses the shared 7-tab FCA form', (
    WidgetTester tester,
  ) async {
    final tpsProvider = _FakeOfflineRevisitTpsProvider();

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tpsProvider.dispose();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<TpsProvider>.value(
        value: tpsProvider,
        child: const MaterialApp(home: TpsOfflineFcaDraftScreen()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byType(TpsCreateFcaScreen), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(7));
    expect(find.text('7 tabs'), findsOneWidget);
    expect(find.text('Offline draft'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Damage'), findsOneWidget);
    expect(find.text('Save Draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeOfflineRevisitTpsProvider extends TpsProvider {
  _FakeOfflineRevisitTpsProvider()
    : super(
        apiClient: ApiClient(Dio()),
        dio: Dio(),
        hiveService: _FakeHiveService(),
      );

  @override
  Future<List<LocationOption>> fetchFcaProvinces() async {
    return const [LocationOption(code: '03', name: 'Central Luzon')];
  }

  @override
  Future<List<LocationOption>> fetchFcaCities({
    required String provinceCode,
  }) async {
    return const [LocationOption(code: '0349', name: 'Talavera')];
  }

  @override
  Future<List<LocationOption>> fetchFcaBarangays({
    required String cityMunicipalityCode,
  }) async {
    return const [LocationOption(code: '034925001', name: 'Sampaloc')];
  }

  @override
  Future<List<FcaTractorOption>> fetchFcaTractorOptions({
    String search = '',
  }) async {
    return const [
      FcaTractorOption(
        id: 1,
        noPlate: 'TR-001',
        brand: 'Kubota',
        model: 'L5018',
        gpsImei: '123456789012345',
      ),
    ];
  }

  @override
  Future<List<TpsUserOption>> fetchTpsUserOptions({String search = ''}) async {
    return const [
      TpsUserOption(id: 7, name: 'TPS Recorder', email: 'recorder@example.com'),
    ];
  }
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
