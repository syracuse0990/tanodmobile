import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/offline_location_cache_card.dart';
import 'package:tanodmobile/models/local/offline_location_cache_summary.dart';

void main() {
  testWidgets('shows downloaded province and city breakdown', (
    WidgetTester tester,
  ) async {
    const summary = OfflineLocationCacheSummary(
      provinces: [
        OfflineLocationProvinceSummary(
          code: '03',
          name: 'Central Luzon',
          cities: [
            OfflineLocationCitySummary(
              code: '0349',
              name: 'Talavera',
              barangays: ['Sampaloc', 'Maestrang Kikay'],
            ),
            OfflineLocationCitySummary(
              code: '0347',
              name: 'Guimba',
              barangays: ['Bunol'],
            ),
          ],
        ),
      ],
      cityCount: 2,
      barangayCount: 3,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OfflineLocationCacheCard(
            summary: summary,
            showProvinceBreakdown: true,
          ),
        ),
      ),
    );

    expect(find.text('Downloaded location data'), findsOneWidget);
    expect(find.text('1 province'), findsOneWidget);
    expect(find.text('2 cities'), findsOneWidget);
    expect(find.text('3 barangays'), findsOneWidget);
    expect(find.text('Central Luzon'), findsOneWidget);

    await tester.tap(find.text('Central Luzon'));
    await tester.pumpAndSettle();

    expect(find.text('Talavera (2 barangays)'), findsOneWidget);
    expect(find.text('Guimba (1 barangay)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
