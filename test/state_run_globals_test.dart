import 'dart:async';

import 'package:bfclash/bootstrap.dart';
import 'package:bfclash/common/common.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/providers/action.dart';
import 'package:bfclash/providers/app.dart';
import 'package:bfclash/providers/config.dart';
import 'package:bfclash/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod/riverpod.dart';

final _packageInfo = PackageInfo(
  appName: 'BfClash',
  packageName: 'com.bfclash.client',
  version: '1.2.3',
  buildNumber: '1',
);

class _StartupSetupAction extends SetupAction {
  final authorization = Completer<AuthorizeCode>();
  int calls = 0;

  @override
  Future<AuthorizeCode> authorizeCore() {
    calls++;
    return authorization.future;
  }
}

class _StartupCoreAction extends CoreAction {
  final authorizationAtStart = <TunAuthorizationState>[];

  @override
  Future<void> startCore() async {
    authorizationAtStart.add(ref.read(authorizedTunEnableProvider));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUpAll(() {
    globalState.packageInfo = _packageInfo;
  });

  setUp(() {
    container = ProviderContainer();
    globalState.container = container;
  });

  tearDown(() {
    container.dispose();
    globalState.isAttach = false;
  });

  void setGlobalUa(String value) {
    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(globalUa: value));
  }

  group('user agent', () {
    test('falls back to the package user agent when none is configured', () {
      setGlobalUa('');

      expect(globalState.ua, _packageInfo.ua);
      expect(globalState.ua, contains('BfClash/v1.2.3'));
    });

    test('prefers the configured global user agent', () {
      setGlobalUa('custom-agent/1.0');

      expect(globalState.ua, 'custom-agent/1.0');
    });

    test('treats a blank configured user agent as unset', () {
      setGlobalUa('   ');

      expect(globalState.ua, _packageInfo.ua);
    });
  });

  group('attach', () {
    test('an already attached app never re-runs startup', () async {
      globalState.isAttach = true;

      await bootstrap.attach();

      expect(globalState.isAttach, isTrue);
      expect(
        container.read(initProvider),
        isFalse,
        reason: 'startup must not have run a second time',
      );
    });
  });

  group('Windows Core startup', () {
    late _StartupSetupAction setup;
    late _StartupCoreAction core;

    setUp(() {
      container.dispose();
      setup = _StartupSetupAction();
      core = _StartupCoreAction();
      container = ProviderContainer(
        overrides: [
          setupActionProvider.overrideWith(() => setup),
          coreActionProvider.overrideWith(() => core),
        ],
      );
      globalState.container = container;
    });

    test(
      'waits for TUN authorization before launching the first Core',
      () async {
        container
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(enable: true));
        final startup = bootstrap.startCoreForStartup(prepareWindowsTun: true);
        await pumpEventQueue();
        expect(setup.calls, 1);
        expect(core.authorizationAtStart, isEmpty);

        setup.authorization.complete(AuthorizeCode.success);
        await startup;
        expect(core.authorizationAtStart, [TunAuthorizationState.authorized]);
        expect(await setup.requestAdmin(true), isTrue);
        expect(setup.calls, 1);
      },
    );

    test(
      'starts the fallback Core when TUN authorization is unavailable',
      () async {
        container
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(enable: true));
        setup.authorization.complete(AuthorizeCode.error);
        await bootstrap.startCoreForStartup(prepareWindowsTun: true);
        expect(core.authorizationAtStart, [TunAuthorizationState.unauthorized]);
      },
    );

    test('skips TUN preparation when it is disabled', () async {
      container
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith.tun(enable: false));
      await bootstrap.startCoreForStartup(prepareWindowsTun: true);
      expect(setup.calls, 0);
      expect(core.authorizationAtStart, [TunAuthorizationState.none]);
    });
  });

  group('canCrashCoreFor', () {
    test('allows a forced Core crash in debug and on the dev channel', () {
      expect(
        GlobalState.canCrashCoreFor(isDebug: true, appEnv: 'stable'),
        isTrue,
      );
      expect(
        GlobalState.canCrashCoreFor(isDebug: false, appEnv: 'dev'),
        isTrue,
      );
    });

    test('never allows a forced Core crash in a release build', () {
      expect(
        GlobalState.canCrashCoreFor(isDebug: false, appEnv: 'stable'),
        isFalse,
      );
      expect(
        GlobalState.canCrashCoreFor(isDebug: false, appEnv: 'pre'),
        isFalse,
      );
    });
  });
}
