import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/frontend/shared/providers/tractor_provider.dart';
import 'package:tanodmobile/models/domain/tractor_location.dart';

void main() {
  test('normalizes canonical and legacy live states', () {
    expect(TractorLiveStatus.fromApi('OFFLINE'), TractorLiveStatus.offline);

    const parkedLegacy = TractorLocation(
      id: 1,
      noPlate: 'LEGACY-PARKED',
      brand: 'Kubota',
      model: 'L4708',
      isOnline: true,
      lat: 15,
      lng: 120,
      speed: 18,
      accStatus: false,
    );
    expect(parkedLegacy.resolvedLiveStatus, TractorLiveStatus.parked);

    const staleMovementLegacy = TractorLocation(
      id: 2,
      noPlate: 'LEGACY-IDLING',
      brand: 'Kubota',
      model: 'L4708',
      isOnline: true,
      lat: 15,
      lng: 120,
      speed: 18,
      accStatus: true,
      gpsMinutesAgo: 66,
    );
    expect(staleMovementLegacy.resolvedLiveStatus, TractorLiveStatus.idling);
  });

  test('uses canonical idling status instead of stale speed', () async {
    var liveListRequests = 0;
    final provider = TractorProvider(
      apiClient: ApiClient(
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.path == '/tractors') {
                  handler.resolve(
                    Response<dynamic>(
                      requestOptions: options,
                      statusCode: 200,
                      data: {
                        'data': [
                          {
                            'id': 99,
                            'imei': '869066060243400',
                            'no_plate': 'GOLDEN HARVEST',
                            'brand': 'Kubota',
                            'model': 'L4708',
                            'device': {'id': 740, 'imei': '869066060243400'},
                          },
                        ],
                        'last_page': 1,
                      },
                    ),
                  );
                  return;
                }

                if (options.path == '/devices/live-locations') {
                  liveListRequests += 1;
                  handler.resolve(
                    Response<dynamic>(
                      requestOptions: options,
                      statusCode: 200,
                      data: {
                        'success': liveListRequests == 1,
                        if (liveListRequests > 1)
                          'message':
                              'Live locations are temporarily unavailable.',
                        'locations': [
                          {
                            'device_id': 740,
                            'imei': '869066060243400',
                            'lat': 15.062024,
                            'lng': 120.765529,
                            'speed': 18,
                            'direction': 231,
                            'status': 1,
                            'live_status': 'idling',
                            'acc_status': 1,
                            'heartbeat_at': '2026-07-22 03:27:15',
                            'heartbeat_at_iso': '2026-07-22T03:27:15+00:00',
                            'gps_time': '2026-07-22T02:03:09+00:00',
                            'gps_minutes_ago': 66,
                          },
                        ],
                      },
                    ),
                  );
                  return;
                }

                if (options.path == '/devices/follow/740') {
                  handler.resolve(
                    Response<dynamic>(
                      requestOptions: options,
                      statusCode: 200,
                      data: {
                        'success': true,
                        'location': {
                          'device_id': 740,
                          'imei': '869066060243400',
                          'lat': 15.062024,
                          'lng': 120.765529,
                          'speed': 18,
                          'direction': 231,
                          'status': 1,
                          'live_status': 'idling',
                          'acc_status': 1,
                          'heartbeat_at': '2026-07-22 03:28:15',
                          'heartbeat_at_iso': '2026-07-22T03:28:15+00:00',
                          'gps_time': '2026-07-22T02:03:09+00:00',
                          'gps_minutes_ago': 67,
                        },
                      },
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
          ),
      ),
    );

    await provider.fetch();

    expect(provider.tractors, hasLength(1));
    final tractor = provider.tractors.single;
    expect(tractor.resolvedLiveStatus, TractorLiveStatus.idling);
    expect(tractor.statusLabel, 'Idling');
    expect(tractor.isMoving, isFalse);
    expect(tractor.isIdling, isTrue);
    expect(tractor.speed, 18);
    expect(tractor.gpsMinutesAgo, 66);
    expect(provider.movingCount, 0);
    expect(provider.idlingCount, 1);

    provider.focusTractor(99);
    await provider.fetch();

    final followedTractor = provider.tractors.single;
    expect(followedTractor.resolvedLiveStatus, TractorLiveStatus.idling);
    expect(followedTractor.isMoving, isFalse);
    expect(followedTractor.gpsMinutesAgo, 67);

    provider.clearFocus();
    await provider.fetch();

    expect(
      provider.tractors.single.resolvedLiveStatus,
      TractorLiveStatus.idling,
    );
    expect(provider.error, 'Failed to load tractors');
  });
}
