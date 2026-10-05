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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(() {
    navigationPort = navigation;
    addTearDown(() => navigationPort = null);
  });

  group('NavigationPort & Desktop UI Shell Tests', () {
    test('Desktop Navigation items expose desktop specific pages', () {
      final items = navigation.getItems(openLogs: true, hasProxies: true);
      expect(items.isNotEmpty, isTrue);

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

    testWidgets('DesktopDashboardView quick access chips unconditionally trigger page navigation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      globalState.container = container;

      container.read(currentPageLabelProvider.notifier).toPage(PageLabel.dashboard);

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
      final connectionsChip = find.widgetWithText(ActionChip, loc.connections);
      final requestsChip = find.widgetWithText(ActionChip, loc.requests);
      final backupChip = find.widgetWithText(ActionChip, loc.backupAndRestore);
      final subStoreChip = find.widgetWithText(ActionChip, loc.subStoreTitle);

      expect(connectionsChip, findsOneWidget);
      expect(requestsChip, findsOneWidget);
      expect(backupChip, findsOneWidget);
      expect(subStoreChip, findsOneWidget);

      // Unconditional tap & state transitions
      await tester.tap(connectionsChip);
      await tester.pump();
      expect(container.read(currentPageLabelProvider), PageLabel.connections);

      await tester.tap(requestsChip);
      await tester.pump();
      expect(container.read(currentPageLabelProvider), PageLabel.requests);

      await tester.tap(backupChip);
      await tester.pump();
      expect(container.read(currentPageLabelProvider), PageLabel.tools);

      container.read(currentPageLabelProvider.notifier).toPage(PageLabel.dashboard);
      await tester.pump();
      expect(container.read(currentPageLabelProvider), PageLabel.dashboard);

      await tester.tap(subStoreChip);
      await tester.pump();
      expect(container.read(currentPageLabelProvider), PageLabel.tools);
    });

    testWidgets('DesktopToolsView wide layout unconditionally renders master-detail and switches content', (
      tester,
    ) async {
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

      expect(find.byType(DesktopToolsView), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);

      // Default selected widget is BackupAndRestore
      expect(find.byType(BackupAndRestore), findsOneWidget);

      // Unconditional assertion: Config menu item must exist
      final configMenuItem = find.text(loc.basicConfig);
      expect(configMenuItem, findsOneWidget);

      // Tap to switch detail view
      await tester.tap(configMenuItem);
      await tester.pumpAndSettle();

      // ConfigView must now be rendered in the detail area
      expect(find.byType(ConfigView), findsOneWidget);
      expect(find.byType(BackupAndRestore), findsNothing);
    });
  });
}

Widget _wrapInScaffold(Widget child) => Scaffold(body: child);
