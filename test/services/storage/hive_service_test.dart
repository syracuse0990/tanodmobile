import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tanodmobile/core/constants/hive_boxes.dart';
import 'package:tanodmobile/models/local/app_session.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'tanodmobile_hive_service_test_',
    );

    Hive.init(tempDirectory.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AppSessionAdapter());
    }

    await Hive.openBox<AppSession>(HiveBoxes.session);
    await Hive.openBox<String>(HiveBoxes.preferences);
  });

  tearDown(() async {
    await Hive.close();

    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('stores current and offline sessions as detached copies', () async {
    final hiveService = HiveService();
    final session = AppSession(
      token: 'token',
      userId: 7,
      name: 'TPS User',
      email: 'tps@example.com',
      roles: const ['tps'],
      savedAt: DateTime(2026, 6, 1),
    );

    await hiveService.saveSession(session);
    await hiveService.saveOfflineTpsSession(session);

    final currentSession = hiveService.getSession();
    final offlineSession = hiveService.getOfflineTpsSession();

    expect(currentSession, isNotNull);
    expect(offlineSession, isNotNull);
    expect(currentSession!.key, HiveBoxes.sessionKey);
    expect(offlineSession!.key, HiveBoxes.offlineTpsSessionKey);
    expect(identical(currentSession, offlineSession), isFalse);
    expect(currentSession.token, session.token);
    expect(offlineSession.token, session.token);
  });
}
