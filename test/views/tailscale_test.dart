import 'dart:async';

import 'package:bfclash/core/core.dart';
import 'package:bfclash/core/interface.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/views/tailscale.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

class _TailnetCore extends CoreHandlerInterface {
  bool failStatus = false;
  int calls = 0;
  bool failAdbStop = false;

  @override
  Future<CoreLifecycleResult> start() async => const CoreLifecycleResult(
    revision: 1,
    outcome: CoreLifecycleOutcome.applied,
  );

  @override
  Future<CoreLifecycleResult> restart() => start();

  @override
  Future<CoreLifecycleResult> stop() => start();

  @override
  Future<CoreLifecycleResult> close() => start();

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    if (method == CoreMethod.startTailscaleADB ||
        method == CoreMethod.stopTailscaleADBPort) {
      return true as T;
    }
    if (method == CoreMethod.stopTailscaleADB) return (!failAdbStop) as T;
    if (method == CoreMethod.getTailscaleStatus) {
      calls++;
      if (failStatus) {
        throw const CoreMethodException(code: 'failed', message: 'failed');
      }
      return {
            'state': 'Running',
            'ips': ['100.64.0.1'],
            'peers': [
              {
                'hostname': 'nas',
                'ips': ['100.64.0.2'],
                'online': true,
              },
            ],
          }
          as T;
    }
    return null;
  }
}

class _FailingSetup extends SetupAction {
  _FailingSetup({this.restoreFails = false});

  final bool restoreFails;
  int calls = 0;

  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    calls++;
    return calls > 1 && !restoreFails;
  }
}

class _DelayedFailingSetup extends SetupAction {
  final pending = Completer<bool>();
  int calls = 0;

  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) {
    calls++;
    return calls == 1 ? pending.future : Future.value(true);
  }
}

void main() {
  testWidgets('ADB status follows discovery, forwarding and stop', (
    tester,
  ) async {
    const channel = MethodChannel('com.bfclash.client/adb-discovery');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => true);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    addTearDown(TailscaleAdbSession.instance.resetForTesting);
    final core = _TailnetCore();
    final container = ProviderContainer(
      overrides: [
        appSettingProvider.overrideWithBuild(
          (_, _) => const AppSettingProps(tailscaleEnabled: true),
        ),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          locale: Locale('en'),
          child: TailscaleView(androidForTesting: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    final start = find.widgetWithText(TextButton, 'Temporary ADB debugging');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start temporary debugging'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('On · Waiting for wireless debugging'),
      findsOneWidget,
    );
    expect(find.textContaining('nas ·'), findsOneWidget);
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('found', 45678),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Open ports: 45678'), findsOneWidget);
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('lost', 45678),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('On · Waiting for wireless debugging'),
      findsOneWidget,
    );
    final stop = find.text('Stop ADB forwarding');
    core.failAdbStop = true;
    await tester.ensureVisible(stop);
    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to confirm closure; try stopping again'),
      findsOneWidget,
    );
    expect(find.text('Off'), findsNothing);
    core.failAdbStop = false;
    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start temporary debugging'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 60));
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'ADB forwarding stays active when leaving and returning to TailscaleView',
    (tester) async {
      const channel = MethodChannel('com.bfclash.client/adb-discovery');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async => true);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      addTearDown(TailscaleAdbSession.instance.resetForTesting);
      final core = _TailnetCore();
      final container = ProviderContainer(
        overrides: [
          appSettingProvider.overrideWithBuild(
            (_, _) => const AppSettingProps(tailscaleEnabled: true),
          ),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('en'),
            child: TailscaleView(androidForTesting: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final start = find.widgetWithText(TextButton, 'Temporary ADB debugging');
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start temporary debugging'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('On · Waiting for wireless debugging'),
        findsOneWidget,
      );

      // Leave the page completely
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(TailscaleAdbSession.instance.isActive, isTrue);

      // Return to TailscaleView
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('en'),
            child: TailscaleView(androidForTesting: true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.textContaining('On · Waiting for wireless debugging'),
        findsOneWidget,
      );
      expect(find.textContaining('nas ·'), findsOneWidget);

      final stop = find.text('Stop ADB forwarding');
      await tester.ensureVisible(stop);
      await tester.tap(stop);
      await tester.pumpAndSettle();
      expect(find.text('Off'), findsOneWidget);
      expect(TailscaleAdbSession.instance.isActive, isFalse);
    },
  );
  testWidgets('failed enable restores settings after leaving the page', (
    tester,
  ) async {
    final setup = _DelayedFailingSetup();
    final container = ProviderContainer(
      overrides: [
        appSettingProvider.overrideWithBuild((_, _) => const AppSettingProps()),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        coreHandlerProvider.overrideWithValue(
          CoreController.scoped(_TailnetCore()),
        ),
        setupActionProvider.overrideWith(() => setup),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: TailscaleView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(container.read(appSettingProvider).tailscaleEnabled, isTrue);
    await tester.pumpWidget(const SizedBox());
    setup.pending.complete(false);
    await tester.pumpAndSettle();
    expect(container.read(appSettingProvider).tailscaleEnabled, isFalse);
    expect(setup.calls, 2);
  });
  testWidgets('disabled Tailscale does not start a node', (tester) async {
    final fake = _TailnetCore();
    final container = ProviderContainer(
      overrides: [
        appSettingProvider.overrideWithBuild((_, _) => const AppSettingProps()),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(fake)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: TailscaleView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Enable Tailscale to connect.'), findsOneWidget);
    expect(fake.calls, 0);
  });

  testWidgets('failed refresh clears stale connected state', (tester) async {
    final fake = _TailnetCore();
    final container = ProviderContainer(
      overrides: [
        appSettingProvider.overrideWithBuild(
          (_, _) => const AppSettingProps(tailscaleEnabled: true),
        ),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(fake)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: TailscaleView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('nas'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    fake.failStatus = true;
    await tester.tap(find.text('Refresh status'));
    await tester.pumpAndSettle();
    expect(find.text('nas'), findsNothing);
    expect(find.text('Connected'), findsNothing);
    expect(
      find.text('Unable to contact Tailscale. Check the core and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('failed enable restores the previous setting', (tester) async {
    final fake = _TailnetCore();
    final setup = _FailingSetup();
    final container = ProviderContainer(
      overrides: [
        appSettingProvider.overrideWithBuild((_, _) => const AppSettingProps()),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(fake)),
        setupActionProvider.overrideWith(() => setup),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: TailscaleView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(container.read(appSettingProvider).tailscaleEnabled, isFalse);
    expect(setup.calls, 2);
    expect(
      find.text(
        'Could not apply the Tailscale setting. Check the active profile.',
      ),
      findsOneWidget,
    );
    expect(fake.calls, 0);
  });

  testWidgets('failed profile restoration is reported explicitly', (
    tester,
  ) async {
    final fake = _TailnetCore();
    final setup = _FailingSetup(restoreFails: true);
    final container = ProviderContainer(
      overrides: [
        appSettingProvider.overrideWithBuild((_, _) => const AppSettingProps()),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(fake)),
        setupActionProvider.overrideWith(() => setup),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: TailscaleView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(container.read(appSettingProvider).tailscaleEnabled, isFalse);
    expect(
      find.text(
        'Could not restore the previous profile. Check your connection and reapply the profile.',
      ),
      findsOneWidget,
    );
  });
}
