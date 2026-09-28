import 'package:bfclash/common/common.dart';
import 'package:bfclash/core/controller.dart';
import 'package:bfclash/core/interface.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/l10n/l10n.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/views/connection/connections.dart';
import 'package:bfclash/views/desktop_dashboard.dart';
import 'package:bfclash/views/profiles/add.dart';
import 'package:bfclash/views/proxies/card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

class _FakeCoreHandler implements CoreHandlerInterface {
  final List<ChangeProxyParams> changeProxyCalls = [];
  final List<String> closeConnectionCalls = [];
  int closeConnectionsCount = 0;

  @override
  Future<String> changeProxy(ChangeProxyParams changeProxyParams) async {
    changeProxyCalls.add(changeProxyParams);
    return '';
  }

  @override
  Future<bool> closeConnection(String id) async {
    closeConnectionCalls.add(id);
    return true;
  }

  @override
  Future<bool> closeConnections() async {
    closeConnectionsCount++;
    return true;
  }

  @override
  Future<List<TrackerInfo>> getConnections() async {
    return [
      TrackerInfo(
        id: 'conn-win-101',
        metadata: const Metadata(
          network: 'tcp',
          destinationIP: '1.1.1.1',
          destinationPort: '443',
          host: 'one.one.one.one',
          process: 'BfClash.exe',
        ),
        upload: 2048,
        download: 16384,
        start: DateTime.now().subtract(const Duration(seconds: 45)),
        chains: ['Proxy-HK', 'DIRECT'],
        rule: 'Match',
        rulePayload: '',
      ),
    ];
  }

  @override
  Future<ProxiesData> getProxies() async {
    return const ProxiesData(
      proxies: {
        'HK-01': {'name': 'HK-01', 'type': 'ss'},
        'Auto': {'name': 'Auto', 'type': 'Selector'},
      },
      all: ['HK-01', 'Auto'],
    );
  }

  @override
  Future<String> validateConfig(String path) async => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeCoreHandler fakeCore;
  late CoreController testCoreController;

  setUp(() {
    fakeCore = _FakeCoreHandler();
    testCoreController = CoreController.test(fakeCore);
  });

  tearDown(() {
    CoreController.resetInstance();
  });

  group('Windows Desktop Shared Core Interaction Tests', () {
    testWidgets('Proxy card tap invokes changeProxyDebounce and core changeProxy on desktop', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(testCoreController),
          selectedProxyNameProvider('PROXY').overrideWith((ref) => 'Auto'),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;

      const testProxy = Proxy(
        name: 'HK-01',
        type: 'ss',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('en'),
            includeNavigatorKey: false,
            setTheme: true,
            child: Scaffold(
              body: ProxyCard(
                groupName: 'PROXY',
                testUrl: null,
                proxy: testProxy,
                groupType: GroupType.Selector,
                type: ProxyCardType.expand,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byType(ProxyCard);
      expect(cardFinder, findsOneWidget);

      await tester.tap(cardFinder);
      // Advance debouncer and inner timers cleanly
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(seconds: 1));

      expect(fakeCore.changeProxyCalls.length, 1);
      expect(fakeCore.changeProxyCalls.first.groupName, 'PROXY');
      expect(fakeCore.changeProxyCalls.first.proxyName, 'HK-01');

      // Unmount card to clear any animation timer
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('ConnectionsView renders on desktop and close all connections triggers core interface', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(testCoreController),
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
            setTheme: true,
            child: ConnectionsView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(commonDuration);
      await tester.pump(commonDuration);

      expect(find.byType(ConnectionsView), findsOneWidget);
      expect(find.textContaining('one.one.one.one'), findsWidgets);

      final closeAllButton = find.byIcon(Icons.delete_sweep_outlined);
      expect(closeAllButton, findsOneWidget);

      await tester.tap(closeAllButton);
      await tester.pump();

      expect(fakeCore.closeConnectionsCount, 1);

      // Cleanly teardown to cancel polling timer
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('AddProfileView on desktop provides URL and file import paths without Android dependency', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(testCoreController),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            locale: const Locale('en'),
            includeNavigatorKey: false,
            setTheme: true,
            child: Scaffold(
              body: Builder(
                builder: (context) => AddProfileView(context: context),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final loc = await AppLocalizations.load(const Locale('en'));

      expect(find.text(loc.file), findsOneWidget);
      expect(find.text(loc.url), findsOneWidget);
      expect(find.text(loc.qrcode), findsOneWidget);
    });

    testWidgets('Desktop dashboard outbound mode radio selector changes mode cleanly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(testCoreController),
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
            setTheme: true,
            child: DesktopDashboardView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final directRadio = find.text('Direct');
      expect(directRadio, findsOneWidget);

      await tester.tap(directRadio);
      await tester.pumpAndSettle();

      expect(container.read(patchClashConfigProvider).mode, Mode.direct);
    });
  });
}
