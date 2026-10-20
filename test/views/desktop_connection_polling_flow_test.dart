import 'package:bfclash/common/common.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/pages/home.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/views/connection/connections.dart';
import 'package:bfclash/views/navigation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  for (final size in [const Size(840, 592), const Size(1400, 1000)]) {
    testWidgets(
      'desktop shell search keeps polling through focus and page changes at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        navigationPort = navigation;
        addTearDown(() => navigationPort = null);
        var revision = 0;
        var reads = 0;
        var received = 0;
        var failRead = false;
        Future<List<TrackerInfo>> reader() async {
          reads++;
          if (failRead) throw StateError('private reader failure');
          return [
            TrackerInfo(
              id: 'owned-session',
              download: received,
              start: DateTime.utc(2026),
              metadata: Metadata(
                network: 'tcp',
                host: 'owned-$revision.test',
                destinationPort: '58757',
              ),
              chains: const ['DIRECT'],
              rule: 'MATCH',
              rulePayload: '',
            ),
          ];
        }

        final container = ProviderContainer(
          overrides: [
            navigationItemsStateProvider.overrideWithValue(
              NavigationItemsState(
                value: [
                  NavigationItem(
                    icon: const Icon(Icons.space_dashboard),
                    label: PageLabel.dashboard,
                    builder: (_) => const Text('fixture dashboard'),
                  ),
                  NavigationItem(
                    icon: const Icon(Icons.ballot),
                    label: PageLabel.connections,
                    modes: const [
                      NavigationItemMode.desktop,
                      NavigationItemMode.more,
                    ],
                    builder: (_) => ConnectionsView(connectionsReader: reader),
                  ),
                ],
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        globalState.container = container;
        container.read(viewSizeProvider.notifier).value = size;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const TestApp(locale: Locale('en'), child: HomePage()),
          ),
        );
        await tester.pumpAndSettle();
        Finder railIcon(IconData icon) => find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byIcon(icon),
        );
        await tester.tap(railIcon(Icons.ballot));
        await tester.pumpAndSettle();
        expect(container.read(currentPageLabelProvider), PageLabel.connections);
        expect(find.textContaining('owned-0.test'), findsWidgets);
        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'owned-');
        received = 8192;
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.textContaining('owned-0.test'), findsWidgets);
        expect(find.textContaining('8KB'), findsWidgets);
        revision = 1;
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.textContaining('owned-0.test'), findsNothing);
        expect(find.textContaining('owned-1.test'), findsWidgets);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        final inactiveReads = reads;
        revision = 2;
        await tester.pump(const Duration(seconds: 2));
        expect(reads, inactiveReads);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('owned-2.test'), findsWidgets);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'owned-',
        );

        await tester.tap(railIcon(Icons.space_dashboard));
        await tester.pumpAndSettle();
        final hiddenReads = reads;
        revision = 3;
        await tester.pump(const Duration(seconds: 2));
        expect(reads, hiddenReads);
        await tester.tap(railIcon(Icons.ballot));
        await tester.pumpAndSettle();
        expect(find.textContaining('owned-3.test'), findsWidgets);
        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'owned-');
        failRead = true;
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.byType(MaterialBanner), findsOneWidget);
        expect(find.textContaining('owned-3.test'), findsWidgets);
        expect(find.textContaining('private reader failure'), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'owned-',
        );
        failRead = false;
        revision = 4;
        await tester.tap(find.byTooltip('Retry'));
        await tester.pumpAndSettle();
        expect(find.byType(MaterialBanner), findsNothing);
        expect(find.textContaining('owned-3.test'), findsNothing);
        expect(find.textContaining('owned-4.test'), findsWidgets);
        for (var tick = 0; tick < 10; tick++) {
          received += 8192;
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('${(received / 1024).toInt()}KB'),
            findsWidgets,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
      },
    );
  }
}
