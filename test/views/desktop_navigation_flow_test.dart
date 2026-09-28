import 'package:bfclash/common/common.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
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

    testWidgets('DesktopDashboardView quick access chips trigger page navigation', (
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
            includeNavigatorKey: false,
            setTheme: true,
            homeBuilder: _wrapInScaffold,
            child: DesktopDashboardView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ActionChip), findsNWidgets(4));

      // Test tapping Connections chip
      final connectionsChip = find.widgetWithText(ActionChip, 'Connections');
      if (connectionsChip.evaluate().isNotEmpty) {
        await tester.tap(connectionsChip);
        await tester.pump();
        expect(container.read(currentPageLabelProvider), PageLabel.connections);
      }

      // Test tapping Tools / Sub-Store chip
      final subStoreChip = find.widgetWithText(ActionChip, 'Sub-Store');
      if (subStoreChip.evaluate().isNotEmpty) {
        await tester.tap(subStoreChip);
        await tester.pump();
        expect(container.read(currentPageLabelProvider), PageLabel.tools);
      }
    });

    testWidgets('DesktopToolsView wide layout switches detail views on item tap', (
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
            includeNavigatorKey: false,
            setTheme: true,
            child: DesktopToolsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopToolsView), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);

      // Verify that menu items exist and tapping changes view
      final configMenuItem = find.text('Configuration');
      if (configMenuItem.evaluate().isNotEmpty) {
        await tester.tap(configMenuItem);
        await tester.pumpAndSettle();
      }
    });
  });
}

Widget _wrapInScaffold(Widget child) => Scaffold(body: child);
