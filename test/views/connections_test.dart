import 'dart:async';

import 'package:bfclash/common/common.dart';
import 'package:bfclash/core/controller.dart';
import 'package:bfclash/core/interface.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/database.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/views/connection/connections.dart';
import 'package:bfclash/widgets/null_status.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

TrackerInfo _tracker({
  required String id,
  String host = 'example.com',
  String process = 'curl',
  List<String> chains = const ['Proxy'],
  int upload = 0,
  int download = 0,
  DateTime? start,
}) {
  return TrackerInfo(
    id: id,
    upload: upload,
    download: download,
    start: start ?? DateTime.utc(2026),
    metadata: Metadata(
      network: 'tcp',
      host: host,
      destinationIP: '1.1.1.1',
      destinationPort: '443',
      process: process,
    ),
    chains: chains,
    rule: 'DOMAIN',
    rulePayload: host,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCoreHandlerInterface core;
  late ProviderContainer container;

  setUpAll(() {
    core = MockCoreHandlerInterface();
    CoreController.resetInstance();
    CoreController.test(core);
  });

  tearDownAll(CoreController.resetInstance);

  setUp(() {
    reset(core);
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
  });

  tearDown(() => container.dispose());

  Future<void> pumpConnections(
    WidgetTester tester, {
    Future<List<TrackerInfo>> Function()? reader,
  }) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(child: ConnectionsView(connectionsReader: reader)),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> teardownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('shows the empty state when core reports no connections', (
    tester,
  ) async {
    when(core.getConnections).thenAnswer((_) async => const <TrackerInfo>[]);

    await pumpConnections(tester);

    expect(find.byType(NullStatus), findsOneWidget);
    expect(tester.takeException(), null);

    await teardownView(tester);
  });

  testWidgets('renders one row per reported connection', (tester) async {
    when(core.getConnections).thenAnswer(
      (_) async => [
        _tracker(id: 'a', host: 'alpha.test'),
        _tracker(id: 'b', host: 'beta.test'),
      ],
    );

    await pumpConnections(tester);
    await tester.pump(commonDuration);
    await tester.pump(commonDuration);

    expect(find.byType(NullStatus), findsNothing);
    expect(find.textContaining('alpha.test'), findsWidgets);
    expect(find.textContaining('beta.test'), findsWidgets);
    expect(tester.takeException(), null);

    await teardownView(tester);
  });

  testWidgets('orders rows by total traffic, then newest first', (
    tester,
  ) async {
    when(core.getConnections).thenAnswer(
      (_) async => [
        _tracker(id: 'a', host: 'alpha.test', download: 100),
        _tracker(id: 'b', host: 'beta.test', upload: 300, download: 300),
        _tracker(
          id: 'c',
          host: 'gamma.test',
          download: 100,
          start: DateTime.utc(2026, 2),
        ),
      ],
    );

    await pumpConnections(tester);

    double topOf(String host) =>
        tester.getTopLeft(find.textContaining(host).first).dy;
    expect(topOf('beta.test'), lessThan(topOf('gamma.test')));
    expect(topOf('gamma.test'), lessThan(topOf('alpha.test')));
    expect(tester.takeException(), null);

    await teardownView(tester);
  });

  testWidgets('keeps the empty state when core throws', (tester) async {
    when(core.getConnections).thenThrow(StateError('core down'));

    await pumpConnections(tester);

    expect(find.byType(NullStatus), findsOneWidget);
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(
      find.text('Unable to refresh connections. The list may be out of date.'),
      findsOneWidget,
    );
    expect(tester.takeException(), null);

    await teardownView(tester);
  });

  testWidgets('search keeps polling and resumes with fresh connections', (
    tester,
  ) async {
    var snapshot = [_tracker(id: 'old', host: 'owned-old.test')];
    when(core.getConnections).thenAnswer((_) async => snapshot);
    await pumpConnections(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'owned-');
    await tester.pump();
    expect(find.textContaining('owned-old.test'), findsWidgets);

    snapshot = [_tracker(id: 'new', host: 'owned-new.test')];
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('owned-old.test'), findsNothing);
    expect(find.textContaining('owned-new.test'), findsWidgets);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    snapshot = [_tracker(id: 'resumed', host: 'owned-resumed.test')];
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('owned-resumed.test'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('owned-new.test'), findsNothing);
    expect(find.textContaining('owned-resumed.test'), findsWidgets);
    expect(tester.takeException(), isNull);
    await teardownView(tester);
  });

  testWidgets(
    'failed refresh labels retained rows and retry shares an in-flight read',
    (tester) async {
      var fails = false;
      var reads = 0;
      Completer<List<TrackerInfo>>? pending;
      when(core.getConnections).thenAnswer((_) async {
        reads++;
        if (pending != null) return pending.future;
        if (fails) throw StateError('private poll failure');
        return [_tracker(id: 'old', host: 'owned-old.test')];
      });
      await pumpConnections(tester);
      await tester.pumpAndSettle();
      fails = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.textContaining('owned-old.test'), findsWidgets);
      expect(find.textContaining('private poll failure'), findsNothing);

      pending = Completer<List<TrackerInfo>>();
      final beforeRetry = reads;
      await tester.tap(find.byTooltip('Retry'));
      await tester.pump();
      expect(reads, beforeRetry + 1);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == 'Retry',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(reads, beforeRetry + 1);
      fails = false;
      pending.complete([_tracker(id: 'new', host: 'owned-new.test')]);
      await tester.pumpAndSettle();
      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.textContaining('owned-old.test'), findsNothing);
      expect(find.textContaining('owned-new.test'), findsWidgets);
      verifyNever(core.closeConnections);
      verifyNever(() => core.closeConnection(any()));
      await teardownView(tester);
    },
  );

  testWidgets(
    'failed retry restores its button and disposal ignores a late read',
    (tester) async {
      Completer<List<TrackerInfo>>? pending;
      when(core.getConnections).thenAnswer((_) async {
        if (pending != null) return pending.future;
        throw StateError('read failure');
      });
      await pumpConnections(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == 'Retry',
              ),
            )
            .onPressed,
        isNotNull,
      );
      pending = Completer<List<TrackerInfo>>();
      await tester.tap(find.byTooltip('Retry'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.completeError(StateError('late read failure'));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('read failure fits a narrow Chinese screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(core.getConnections).thenThrow(StateError('read failure'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          locale: Locale('zh', 'CN'),
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(360, 600),
              textScaler: TextScaler.linear(1.3),
            ),
            child: ConnectionsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.byTooltip('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await teardownView(tester);
  });

  testWidgets('a synchronously failing reader can be retried', (tester) async {
    var reads = 0;
    Future<List<TrackerInfo>> reader() {
      reads++;
      if (reads == 1) throw StateError('synchronous read failure');
      return Future.value([_tracker(id: 'fresh', host: 'owned-fresh.test')]);
    }

    await pumpConnections(tester, reader: reader);
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsOneWidget);
    await tester.tap(find.byTooltip('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.textContaining('owned-fresh.test'), findsWidgets);
    await teardownView(tester);
  });

  testWidgets(
    'toolbar refresh reads a fresh snapshot without closing connections',
    (tester) async {
      var snapshot = [_tracker(id: 'old', host: 'owned-old.test')];
      when(core.getConnections).thenAnswer((_) async => snapshot);
      await pumpConnections(tester);
      await tester.pumpAndSettle();
      snapshot = [_tracker(id: 'fresh', host: 'owned-fresh.test')];
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.textContaining('owned-old.test'), findsNothing);
      expect(find.textContaining('owned-fresh.test'), findsWidgets);
      expect(find.byType(MaterialBanner), findsNothing);
      verifyNever(core.closeConnections);
      verifyNever(() => core.closeConnection(any()));
      await teardownView(tester);
    },
  );

  testWidgets('stops polling once the view is disposed', (tester) async {
    when(core.getConnections).thenAnswer((_) async => const <TrackerInfo>[]);

    await pumpConnections(tester);
    await teardownView(tester);
    clearInteractions(core);

    await tester.pump(const Duration(seconds: 3));

    verifyNever(core.getConnections);
  });
}
