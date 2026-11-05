import 'package:bfclash/core/core.dart';
import 'package:bfclash/core/interface.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/views/tailscale.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

class _TailnetCore extends CoreHandlerInterface {
  bool failStatus = false;
  int calls = 0;

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

void main() {
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
