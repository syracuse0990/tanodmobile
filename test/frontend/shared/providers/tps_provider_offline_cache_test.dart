import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/core/constants/hive_boxes.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/models/local/offline_distribution_draft.dart';
import 'package:tanodmobile/models/local/offline_fca_draft.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

void main() {
  test('syncOfflineDistributions stores all paged records in Hive', () async {
    final hiveService = _FakeHiveService();
    final provider = _buildProvider(
      hiveService: hiveService,
      responses: {
        '${AppEndpoints.tpsDistributions}?page=1&per_page=100': {
          'data': [
            {
              'id': 1,
              'status': 'distributed',
              'area': 'North 1',
              'tractor': {'no_plate': 'ABC-123'},
              'distributed_to_user': {'name': 'Farmer One'},
            },
          ],
          'meta': {'current_page': 1, 'last_page': 2},
        },
        '${AppEndpoints.tpsDistributions}?page=2&per_page=100': {
          'data': [
            {
              'id': 2,
              'status': 'returned',
              'area': 'North 2',
              'tractor': {'no_plate': 'XYZ-789'},
              'distributed_to_user': {'name': 'Farmer Two'},
            },
          ],
          'meta': {'current_page': 2, 'last_page': 2},
        },
      },
    );

    final count = await provider.syncOfflineDistributions();

    expect(count, 2);

    final cached =
        jsonDecode(
              hiveService.getPreference(HiveBoxes.tpsOfflineDistributionsKey)!,
            )
            as List<dynamic>;
    expect(cached, hasLength(2));
  });

  test('fetchFcas falls back to cached Hive data when API fails', () async {
    final hiveService = _FakeHiveService()
      ..seed(
        HiveBoxes.tpsOfflineFcasKey,
        jsonEncode([
          {
            'id': 7,
            'name': 'San Isidro FCA',
            'organization_name': 'San Isidro',
            'first_name': 'Tomas',
            'last_name': 'Dela Cruz',
            'province': 'Nueva Ecija',
            'city_town': 'Talavera',
            'barangay': 'Sampaloc',
          },
        ]),
      );
    final provider = _buildProvider(
      hiveService: hiveService,
      responses: const {},
    );

    await provider.fetchFcas();

    expect(provider.fcas, hasLength(1));
    expect(provider.fcas.first.name, 'San Isidro FCA');
  });

  test(
    'fetchFca location options cache API results for offline reuse',
    () async {
      final hiveService = _FakeHiveService();
      final onlineProvider = _buildProvider(
        hiveService: hiveService,
        responses: {
          AppEndpoints.tpsFcaLocationProvinces: {
            'data': [
              {'code': '03', 'name': 'Central Luzon'},
            ],
          },
          '${AppEndpoints.tpsFcaLocationCities}?province_code=03': {
            'data': {
              '0349': {'code': '0349', 'name': 'Talavera'},
            },
          },
          '${AppEndpoints.tpsFcaLocationBarangays}?city_municipality_code=0349':
              {
                'data': {
                  '034925001': {'code': '034925001', 'name': 'Sampaloc'},
                },
              },
        },
      );

      final provinces = await onlineProvider.fetchFcaProvinces();
      final cities = await onlineProvider.fetchFcaCities(provinceCode: '03');
      final barangays = await onlineProvider.fetchFcaBarangays(
        cityMunicipalityCode: '0349',
      );

      expect(provinces.single.name, 'Central Luzon');
      expect(cities.single.name, 'Talavera');
      expect(barangays.single.name, 'Sampaloc');
      expect(
        hiveService.getPreference(HiveBoxes.tpsFcaProvinceOptionsCacheKey),
        isNotNull,
      );
      expect(
        hiveService.getPreference('${HiveBoxes.tpsFcaCitiesCachePrefix}03'),
        isNotNull,
      );
      expect(
        hiveService.getPreference(
          '${HiveBoxes.tpsFcaBarangaysCachePrefix}0349',
        ),
        isNotNull,
      );

      final offlineProvider = _buildProvider(
        hiveService: hiveService,
        responses: const {},
      );

      final cachedProvinces = await offlineProvider.fetchFcaProvinces();
      final cachedCities = await offlineProvider.fetchFcaCities(
        provinceCode: '03',
      );
      final cachedBarangays = await offlineProvider.fetchFcaBarangays(
        cityMunicipalityCode: '0349',
      );

      expect(cachedProvinces.single.name, 'Central Luzon');
      expect(cachedCities.single.code, '0349');
      expect(cachedBarangays.single.name, 'Sampaloc');
    },
  );

  test(
    'syncOfflineFcaLocationCache walks and caches all location levels',
    () async {
      final hiveService = _FakeHiveService();
      final provider = _buildProvider(
        hiveService: hiveService,
        responses: {
          AppEndpoints.tpsFcaLocationProvinces: {
            'data': [
              {'code': '03', 'name': 'Central Luzon'},
              {'code': '04', 'name': 'Calabarzon'},
            ],
          },
          '${AppEndpoints.tpsFcaLocationCities}?province_code=03': {
            'data': [
              {'code': '0349', 'name': 'Talavera'},
            ],
          },
          '${AppEndpoints.tpsFcaLocationCities}?province_code=04': {
            'data': [
              {'code': '0456', 'name': 'Lucena City'},
            ],
          },
          '${AppEndpoints.tpsFcaLocationBarangays}?city_municipality_code=0349':
              {
                'data': [
                  {'code': '034925001', 'name': 'Sampaloc'},
                ],
              },
          '${AppEndpoints.tpsFcaLocationBarangays}?city_municipality_code=0456':
              {
                'data': [
                  {'code': '045610001', 'name': 'Ibabang Dupay'},
                ],
              },
        },
      );

      await provider.syncOfflineFcaLocationCache();

      expect(
        hiveService.getPreference(HiveBoxes.tpsFcaProvinceOptionsCacheKey),
        isNotNull,
      );
      expect(
        hiveService.getPreference('${HiveBoxes.tpsFcaCitiesCachePrefix}03'),
        isNotNull,
      );
      expect(
        hiveService.getPreference('${HiveBoxes.tpsFcaCitiesCachePrefix}04'),
        isNotNull,
      );
      expect(
        hiveService.getPreference(
          '${HiveBoxes.tpsFcaBarangaysCachePrefix}0349',
        ),
        isNotNull,
      );
      expect(
        hiveService.getPreference(
          '${HiveBoxes.tpsFcaBarangaysCachePrefix}0456',
        ),
        isNotNull,
      );
    },
  );

  test(
    'syncOfflineReferenceData clears saved record caches and stores reference sync timestamp',
    () async {
      final hiveService = _FakeHiveService()
        ..seed(
          HiveBoxes.tpsOfflineDistributionsKey,
          jsonEncode([
            {'id': 1},
          ]),
        )
        ..seed(
          HiveBoxes.tpsOfflineFcasKey,
          jsonEncode([
            {'id': 2},
          ]),
        )
        ..seed(
          HiveBoxes.tpsOfflineDistributionsSyncedAtKey,
          DateTime(2026, 6, 1, 8).toIso8601String(),
        )
        ..seed(
          HiveBoxes.tpsOfflineFcasSyncedAtKey,
          DateTime(2026, 6, 1, 9).toIso8601String(),
        );
      final provider = _buildProvider(
        hiveService: hiveService,
        responses: {
          AppEndpoints.tpsFcaLocationProvinces: {
            'data': [
              {'code': '03', 'name': 'Central Luzon'},
            ],
          },
          '${AppEndpoints.tpsFcaLocationCities}?province_code=03': {
            'data': [
              {'code': '0349', 'name': 'Talavera'},
            ],
          },
          '${AppEndpoints.tpsFcaLocationBarangays}?city_municipality_code=0349':
              {
                'data': [
                  {'code': '034925001', 'name': 'Sampaloc'},
                ],
              },
          '${AppEndpoints.tpsTractors}?page=1&per_page=200': {
            'data': [
              {
                'id': 11,
                'no_plate': 'TR-11',
                'brand': 'Kubota',
                'model': 'L5018',
                'imei': '123456789012345',
              },
            ],
            'meta': {'current_page': 1, 'last_page': 1},
          },
          AppEndpoints.tpsUsers: {
            'data': [
              {
                'id': 5,
                'name': 'TPS One',
                'email': 'tps1@example.com',
                'phone': '09171234567',
              },
            ],
          },
        },
      );

      await provider.syncOfflineReferenceData();

      expect(
        hiveService.getPreference(HiveBoxes.tpsOfflineDistributionsKey),
        isNull,
      );
      expect(hiveService.getPreference(HiveBoxes.tpsOfflineFcasKey), isNull);
      expect(
        hiveService.getPreference(HiveBoxes.tpsOfflineDistributionsSyncedAtKey),
        isNull,
      );
      expect(
        hiveService.getPreference(HiveBoxes.tpsOfflineFcasSyncedAtKey),
        isNull,
      );
      expect(
        hiveService.getPreference(HiveBoxes.tpsOfflineReferenceDataSyncedAtKey),
        isNotNull,
      );
      expect(
        hiveService.getPreference(HiveBoxes.tpsFcaTractorOptionsCacheKey),
        isNotNull,
      );
      expect(
        hiveService.getPreference(HiveBoxes.tpsTpsUserOptionsCacheKey),
        isNotNull,
      );
      expect(provider.offlineReferenceDataSyncedAt, isNotNull);
      expect(provider.distributions, isEmpty);
      expect(provider.fcas, isEmpty);
    },
  );

  test(
    'loadOfflineWorkspaceSnapshot reads cached lists and draft metadata',
    () async {
      final hiveService = _FakeHiveService()
        ..seed(
          HiveBoxes.tpsOfflineDistributionsKey,
          jsonEncode([
            {
              'id': 3,
              'status': 'distributed',
              'area': 'Zone 3',
              'tractor': {'no_plate': 'TR-3'},
              'distributed_to_user': {'name': 'Farmer Three'},
            },
          ]),
        )
        ..seed(
          HiveBoxes.tpsOfflineFcasKey,
          jsonEncode([
            {
              'id': 9,
              'name': 'Offline FCA',
              'organization_name': 'Offline Coop',
            },
          ]),
        )
        ..seed(
          HiveBoxes.tpsOfflineDistributionDraftsKey,
          jsonEncode([
            {
              'id': 'draft-1',
              'recipient_name': 'Draft Farmer',
              'tractor_label': 'TR-9',
              'distribution_date': DateTime(2026, 6, 1).toIso8601String(),
              'created_at': DateTime(2026, 6, 1).toIso8601String(),
              'updated_at': DateTime(2026, 6, 1, 9).toIso8601String(),
            },
          ]),
        )
        ..seed(
          HiveBoxes.tpsOfflineFcaDraftsKey,
          jsonEncode([
            {
              'id': 'fca-draft-1',
              'organization_name': 'Draft Cooperative',
              'contact_name': 'Pedro Santos',
              'phone': '09171234567',
              'province_code': '03',
              'province': 'Nueva Ecija',
              'city_municipality_code': '0349',
              'city_town': 'Talavera',
              'barangay_code': '034925001',
              'barangay': 'Sampaloc',
              'created_at': DateTime(2026, 6, 1).toIso8601String(),
              'updated_at': DateTime(2026, 6, 1, 10).toIso8601String(),
            },
          ]),
        )
        ..seed(
          HiveBoxes.tpsOfflineDistributionsSyncedAtKey,
          DateTime(2026, 6, 1, 8).toIso8601String(),
        )
        ..seed(
          HiveBoxes.tpsOfflineFcasSyncedAtKey,
          DateTime(2026, 6, 1, 7).toIso8601String(),
        )
        ..seed(
          HiveBoxes.tpsOfflineReferenceDataSyncedAtKey,
          DateTime(2026, 6, 1, 10).toIso8601String(),
        )
        ..seed(
          HiveBoxes.tpsFcaProvinceOptionsCacheKey,
          jsonEncode([
            {'code': '03', 'name': 'Central Luzon'},
            {'code': '04', 'name': 'Calabarzon'},
          ]),
        )
        ..seed(
          '${HiveBoxes.tpsFcaCitiesCachePrefix}03',
          jsonEncode([
            {'code': '0349', 'name': 'Talavera'},
          ]),
        )
        ..seed(
          '${HiveBoxes.tpsFcaCitiesCachePrefix}04',
          jsonEncode([
            {'code': '0456', 'name': 'Lucena City'},
          ]),
        )
        ..seed(
          '${HiveBoxes.tpsFcaBarangaysCachePrefix}0349',
          jsonEncode([
            {'code': '034925001', 'name': 'Sampaloc'},
            {'code': '034925002', 'name': 'Maestrang Kikay'},
          ]),
        )
        ..seed(
          '${HiveBoxes.tpsFcaBarangaysCachePrefix}0456',
          jsonEncode([
            {'code': '045610001', 'name': 'Ibabang Dupay'},
          ]),
        );
      final provider = _buildProvider(
        hiveService: hiveService,
        responses: const {},
      );

      await provider.loadOfflineWorkspaceSnapshot();

      expect(provider.distributions, hasLength(1));
      expect(provider.fcas, hasLength(1));
      expect(provider.offlineDistributionDrafts, hasLength(1));
      expect(provider.offlineFcaDrafts, hasLength(1));
      expect(
        provider.offlineDistributionDrafts.first.recipientName,
        'Draft Farmer',
      );
      expect(
        provider.offlineFcaDrafts.first.organizationName,
        'Draft Cooperative',
      );
      expect(provider.offlineFcaDrafts.first.provinceCode, '03');
      expect(provider.offlineFcaDrafts.first.cityMunicipalityCode, '0349');
      expect(provider.offlineFcaDrafts.first.barangayCode, '034925001');
      expect(provider.offlineDistributionsSyncedAt, DateTime(2026, 6, 1, 8));
      expect(provider.offlineFcasSyncedAt, DateTime(2026, 6, 1, 7));
      expect(provider.offlineReferenceDataSyncedAt, DateTime(2026, 6, 1, 10));
      expect(provider.offlineLocationCacheSummary.provinceCount, 2);
      expect(provider.offlineLocationCacheSummary.cityCount, 2);
      expect(provider.offlineLocationCacheSummary.barangayCount, 3);
      expect(
        provider.offlineLocationCacheSummary.provinces.first.name,
        'Calabarzon',
      );
      expect(
        provider.offlineLocationCacheSummary.provinces.last.cities.first.name,
        'Talavera',
      );
    },
  );

  test(
    'save and delete offline distribution draft persists local drafts',
    () async {
      final hiveService = _FakeHiveService();
      final provider = _buildProvider(
        hiveService: hiveService,
        responses: const {},
      );
      final draft = OfflineDistributionDraft(
        id: 'draft-2',
        recipientName: 'Maria Cruz',
        tractorLabel: 'TR-22',
        distributionDate: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1, 8),
        updatedAt: DateTime(2026, 6, 1, 8),
        area: 'Zone 2',
        notes: 'For morning delivery',
      );

      await provider.saveOfflineDistributionDraft(draft);
      await provider.loadOfflineDistributionDrafts();

      expect(provider.offlineDistributionDrafts, hasLength(1));
      expect(
        provider.offlineDistributionDrafts.first.recipientName,
        'Maria Cruz',
      );

      await provider.deleteOfflineDistributionDraft(draft.id);
      await provider.loadOfflineDistributionDrafts();

      expect(provider.offlineDistributionDrafts, isEmpty);
    },
  );

  test('save and delete offline FCA draft persists local drafts', () async {
    final hiveService = _FakeHiveService();
    final provider = _buildProvider(
      hiveService: hiveService,
      responses: const {},
    );
    final draft = OfflineFcaDraft.fromSnapshot(
      id: 'fca-draft-2',
      createdAt: DateTime(2026, 6, 1, 8),
      updatedAt: DateTime(2026, 6, 1, 8),
      notes: 'Follow up after validation',
      snapshot: {
        'organization_name': 'San Jose Cooperative',
        'first_name': 'Ana',
        'last_name': 'Reyes',
        'phone': '09181234567',
        'email': 'ana@example.com',
        'province_code': '03',
        'province_name': 'Nueva Ecija',
        'city_municipality_code': '0347',
        'city_name': 'Guimba',
        'barangay_code': '034725001',
        'barangay_name': 'Bunol',
        'date_received': '2026-06-01',
        'active_tab_index': 6,
        'tractor_details': {
          'tractor_model': 'Kubota L5018',
          'serial_number': 'SN-001',
        },
        'damage_records': [
          {
            'entry_order': 0,
            'unit': 'Tractor',
            'nature_of_problem': 'Damaged step board',
          },
        ],
      },
    );

    await provider.saveOfflineFcaDraft(draft);
    await provider.loadOfflineFcaDrafts();

    expect(provider.offlineFcaDrafts, hasLength(1));
    expect(
      provider.offlineFcaDrafts.first.organizationName,
      'San Jose Cooperative',
    );
    expect(provider.offlineFcaDrafts.first.provinceCode, '03');
    expect(provider.offlineFcaDrafts.first.cityMunicipalityCode, '0347');
    expect(provider.offlineFcaDrafts.first.barangayCode, '034725001');
    expect(
      provider.offlineFcaDrafts.first.payload['tractor_details'],
      isA<Map<String, dynamic>>(),
    );
    expect(
      (provider.offlineFcaDrafts.first.payload['damage_records'] as List)
          .single['unit'],
      'Tractor',
    );

    await provider.deleteOfflineFcaDraft(draft.id);
    await provider.loadOfflineFcaDrafts();

    expect(provider.offlineFcaDrafts, isEmpty);
  });
}

TpsProvider _buildProvider({
  required _FakeHiveService hiveService,
  required Map<String, Map<String, dynamic>> responses,
}) {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final key = _requestKey(options);
          final response = responses[key];
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
              error: 'Unexpected path: $key',
            ),
          );
        },
      ),
    );

  return TpsProvider(
    apiClient: ApiClient(dio),
    dio: dio,
    hiveService: hiveService,
  );
}

String _requestKey(RequestOptions options) {
  final path = options.path;
  final query = options.queryParameters.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));

  if (query.isEmpty) {
    return path;
  }

  final encodedQuery = query
      .map((entry) => '${entry.key}=${entry.value}')
      .join('&');

  return '$path?$encodedQuery';
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

  _FakeHiveService seed(String key, String value) {
    _preferences[key] = value;
    return this;
  }
}
