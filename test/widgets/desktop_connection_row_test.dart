import 'package:bfclash/features/connection/tracker_info_item.dart';
import 'package:bfclash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import '../helpers/test_app.dart';

void main() {
  for (final width in [600.0, 1200.0]) {
    testWidgets('connection actions and details survive at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final keywords = <String>[];
      var closed = false;
      final info = TrackerInfo(
        id: 'desktop-row',
        metadata: const Metadata(
          network: 'tcp',
          destinationIP: '192.0.2.1',
          destinationPort: '443',
          host: 'example.test',
          process: 'Browser.exe',
        ),
        upload: 2048,
        download: 16384,
        start: DateTime(2026, 10, 18),
        chains: ['Test proxy', 'DIRECT'],
        rule: 'Match',
        rulePayload: '',
      );
      await tester.pumpWidget(
        TestApp(
          wrapInProviderScope: true,
          includeNavigatorKey: false,
          locale: const Locale('en'),
          child: Scaffold(
            body: TrackerInfoItem(
              trackerInfo: info,
              detailTitle: 'Connection details',
              onClickKeyword: keywords.add,
              trailing: IconButton(
                icon: const Icon(Icons.block),
                onPressed: () => closed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (width >= 880) {
        expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
        expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      }
      await tester.tap(find.text('Test proxy'));
      await tester.pump();
      expect(keywords, ['Test proxy']);
      await tester.tap(find.byIcon(Icons.block));
      await tester.pump();
      expect(closed, isTrue);
      await tester.tap(find.textContaining('example.test').first);
      await tester.pumpAndSettle();
      expect(find.byType(TrackerInfoDetailView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
