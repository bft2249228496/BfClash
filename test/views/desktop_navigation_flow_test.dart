import 'package:bfclash/common/common.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/l10n/l10n.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/views/backup_and_restore.dart';
import 'package:bfclash/views/config/config.dart';
import 'package:bfclash/views/desktop_dashboard.dart';
import 'package:bfclash/views/desktop_tools.dart';
import 'package:bfclash/views/navigation.dart';
import 'package:bfclash/views/sub_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/fixed_network_detection.dart';

void main() {
  setUp(() {
    navigationPort = navigation;
    addTearDown(() => navigationPort = null);
  });

  group('NavigationPort & Desktop UI Shell Tests', () {
    test(
      'desktop keeps IP checks enabled without the mobile dashboard card',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(appSettingProvider, (_, _) {});
        container
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(dashboardWidgets: []));
        container.listen(checkIpProvider, (_, _) {});
        final before = container.read(checkIpProvider);
        expect(before.containsDetection, isTrue);
        container.read(checkIpNumProvider.notifier).add();
        expect(
          container.read(checkIpProvider).checkIpNum,
          before.checkIpNum + 1,
        );
      },
    );

    test('Desktop Navigation items expose desktop specific pages', () {
      final items = navigation.getItems(openLogs: true, hasProxies: true);
      expect(items.isNotEmpty, isTrue);
      final desktopLabels = items
          .where((item) => item.modes.contains(NavigationItemMode.desktop))
          .map((item) => item.label);
      expect(
        desktopLabels,
        containsAll([
          PageLabel.dashboard,
          PageLabel.proxies,
          PageLabel.profiles,
          PageLabel.requests,
          PageLabel.connections,
          PageLabel.logs,
          PageLabel.tools,
        ]),
      );

      final dashboardItem = items.firstWhere(
        (item) => item.label == PageLabel.dashboard,
      );
      final toolsItem = items.firstWhere(
        (item) => item.label == PageLabel.tools,
      );
      final profilesItem = items.firstWhere(
        (item) => item.label == PageLabel.profiles,
      );
      final proxiesItem = items.firstWhere(
        (item) => item.label == PageLabel.proxies,
      );

      expect(dashboardItem, isNotNull);
      expect(toolsItem, isNotNull);
      expect(profilesItem, isNotNull);
      expect(proxiesItem, isNotNull);

      expect(dashboardItem.modes.contains(NavigationItemMode.desktop), isTrue);
      expect(toolsItem.modes.contains(NavigationItemMode.desktop), isTrue);
      expect(profilesItem.modes.contains(NavigationItemMode.desktop), isTrue);
      expect(proxiesItem.modes.contains(NavigationItemMode.desktop), isTrue);
    });

    for (final width in [900.0, 1400.0]) {
      testWidgets('desktop shows exit IP and refreshes at width $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = FixedNetworkDetection();
        final container = ProviderContainer(
          overrides: [
            networkDetectionProvider.overrideWith(() => fixture),
            localIpProvider.overrideWithBuild((_, _) => '192.168.31.22'),
          ],
        );
        addTearDown(container.dispose);
        globalState.container = container;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const TestApp(
              locale: Locale('en'),
              includeNavigatorKey: false,
              homeBuilder: _wrapInScaffold,
              child: DesktopDashboardView(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final address = find.text('192.0.2.42');
        expect(address, findsOneWidget);
        await tester.ensureVisible(address);
        await tester.tap(address);
        await tester.pump();
        expect(fixture.checks, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('connected idle core does not imply a running proxy', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          networkDetectionProvider.overrideWith(FixedNetworkDetection.new),
          localIpProvider.overrideWithBuild((_, _) => '192.168.31.22'),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('en'),
            includeNavigatorKey: false,
            setTheme: true,
            homeBuilder: _wrapInScaffold,
            child: DesktopDashboardView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Hero card state plus the header status capsule.
      expect(find.text('Proxy stopped'), findsWidgets);
      expect(find.text('Proxy running'), findsNothing);
      container.read(runTimeProvider.notifier).value = 65000;
      await tester.pump();
      expect(find.text('Proxy running'), findsWidgets);
      expect(find.text('00:01:05'), findsOneWidget);
      expect(find.textContaining('1970'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'DesktopDashboardView quick access chips unconditionally trigger page navigation',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            networkDetectionProvider.overrideWith(FixedNetworkDetection.new),
            localIpProvider.overrideWithBuild((_, _) => '192.168.31.22'),
          ],
        );
        addTearDown(container.dispose);
        globalState.container = container;

        container
            .read(currentPageLabelProvider.notifier)
            .toPage(PageLabel.dashboard);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const TestApp(
              locale: Locale('en'),
              includeNavigatorKey: false,
              setTheme: true,
              homeBuilder: _wrapInScaffold,
              child: DesktopDashboardView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final loc = await AppLocalizations.load(const Locale('en'));

        // Unconditional assertions on quick access action chips
        final connectionsChip = find.widgetWithText(
          ActionChip,
          loc.connections,
        );
        final requestsChip = find.widgetWithText(ActionChip, loc.requests);
        final backupChip = find.widgetWithText(
          ActionChip,
          loc.backupAndRestore,
        );
        final subStoreChip = find.widgetWithText(ActionChip, loc.subStoreTitle);

        expect(connectionsChip, findsOneWidget);
        expect(requestsChip, findsOneWidget);
        expect(backupChip, findsOneWidget);
        expect(subStoreChip, findsOneWidget);

        // Unconditional tap & state transitions
        await tester.ensureVisible(connectionsChip);
        await tester.pumpAndSettle();
        await tester.tap(connectionsChip);
        await tester.pump();
        expect(container.read(currentPageLabelProvider), PageLabel.connections);

        await tester.ensureVisible(requestsChip);
        await tester.pumpAndSettle();
        await tester.tap(requestsChip);
        await tester.pump();
        expect(container.read(currentPageLabelProvider), PageLabel.requests);

        await tester.ensureVisible(backupChip);
        await tester.pumpAndSettle();
        await tester.tap(backupChip);
        await tester.pumpAndSettle();
        expect(find.byType(BackupAndRestore), findsOneWidget);
        Navigator.of(tester.element(find.byType(BackupAndRestore))).pop();
        await tester.pumpAndSettle();

        container
            .read(currentPageLabelProvider.notifier)
            .toPage(PageLabel.dashboard);
        await tester.pump();
        expect(container.read(currentPageLabelProvider), PageLabel.dashboard);

        await tester.ensureVisible(subStoreChip);
        await tester.pumpAndSettle();
        await tester.tap(subStoreChip);
        await tester.pumpAndSettle();
        expect(find.byType(SubStoreView), findsOneWidget);
        Navigator.of(tester.element(find.byType(SubStoreView))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(DesktopDashboardView), findsOneWidget);
      },
    );

    testWidgets(
      'tools overview preserves settings and opens configuration routes',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        globalState.container = container;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const TestApp(
              locale: Locale('en'),
              includeNavigatorKey: false,
              setTheme: true,
              child: DesktopToolsView(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final loc = await AppLocalizations.load(const Locale('en'));
        expect(find.byType(BackupAndRestore), findsNothing);
        expect(find.text(loc.checkUpdate), findsWidgets);
        expect(find.text(loc.backupAndRestore), findsWidgets);
        expect(find.text(loc.subStoreTitle), findsWidgets);
        final config = find.text(loc.basicConfig);
        await tester.scrollUntilVisible(
          config,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(config);
        await tester.pumpAndSettle();
        expect(find.byType(ConfigView), findsOneWidget);
        Navigator.of(tester.element(find.byType(ConfigView))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(DesktopToolsView), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Widget _wrapInScaffold(Widget child) => Scaffold(body: child);
