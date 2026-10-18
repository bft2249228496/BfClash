import 'dart:async';
import 'dart:io';

import 'package:bfclash/l10n/l10n.dart';
import 'package:bfclash/plugins/sub_store.dart';
import 'package:bfclash/views/sub_store_backend_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class StubProcess extends Fake implements Process {
  final ended = Completer<int>();
  bool confirmExit = true;
  int kills = 0;

  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => ended.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    kills++;
    if (confirmExit && !ended.isCompleted) ended.complete(0);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => AppLocalizations.load(const Locale('en')));

  test(
    'status cannot adopt an unowned service on the configured port',
    () async {
      var checks = 0;
      final manager = DesktopSubStoreManager.testing(
        launch: () async => StubProcess(),
        checkHealth: () async {
          checks++;
          return true;
        },
      );
      expect((await manager.getStatus()).phase, SubStoreBackendPhase.stopped);
      expect(checks, 0);
    },
  );

  test(
    'occupied port is rejected without launching or adopting its service',
    () async {
      final foreign = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      var launches = 0;
      var checks = 0;
      final manager = DesktopSubStoreManager.testing(
        endpoint: 'http://127.0.0.1:${foreign.port}',
        launch: () async {
          launches++;
          return StubProcess();
        },
        checkHealth: () async {
          checks++;
          return true;
        },
      );
      try {
        expect((await manager.start()).phase, SubStoreBackendPhase.failed);
        expect(launches, 0);
        expect(checks, 0);
        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          foreign.port,
        );
        client.destroy();
      } finally {
        await foreign.close();
      }
    },
  );

  test('stop during launch waits for and terminates the new child', () async {
    final child = StubProcess();
    final entered = Completer<void>();
    final release = Completer<void>();
    final manager = DesktopSubStoreManager.testing(
      launch: () async {
        entered.complete();
        await release.future;
        return child;
      },
      checkHealth: () async => true,
    );
    final starting = manager.start();
    await entered.future;
    var stopped = false;
    final stopping = manager.stop().then((value) {
      stopped = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isFalse);
    release.complete();
    await starting;
    expect((await stopping).phase, SubStoreBackendPhase.stopped);
    expect(child.kills, 1);
    expect(child.ended.isCompleted, isTrue);
  });

  test('concurrent starts create one owned process', () async {
    final child = StubProcess();
    var launches = 0;
    final manager = DesktopSubStoreManager.testing(
      launch: () async {
        launches++;
        return child;
      },
      checkHealth: () async => true,
    );
    final results = await Future.wait([manager.start(), manager.start()]);
    expect(results.every((value) => value.isRunning), isTrue);
    expect(launches, 1);
    await manager.stop();
  });

  test(
    'failed readiness confirms child exit before reporting failure',
    () async {
      final child = StubProcess();
      final manager = DesktopSubStoreManager.testing(
        launch: () async => child,
        checkHealth: () async => false,
      );
      expect((await manager.start()).phase, SubStoreBackendPhase.failed);
      expect(child.ended.isCompleted, isTrue);
      expect(child.kills, 1);
    },
  );

  test(
    'an exited child cannot be replaced by a foreign health response',
    () async {
      final child = StubProcess()..ended.complete(1);
      var checks = 0;
      final manager = DesktopSubStoreManager.testing(
        launch: () async => child,
        checkHealth: () async {
          checks++;
          return true;
        },
      );
      expect((await manager.start()).phase, SubStoreBackendPhase.failed);
      expect(checks, 0);
    },
  );

  test('loss of health does not remain running', () async {
    final child = StubProcess();
    var healthy = true;
    final manager = DesktopSubStoreManager.testing(
      launch: () async => child,
      checkHealth: () async => healthy,
    );
    expect((await manager.start()).isRunning, isTrue);
    healthy = false;
    expect((await manager.getStatus()).phase, SubStoreBackendPhase.failed);
    await manager.stop();
  });

  test('launch failure does not prevent a subsequent start and stop', () async {
    final child = StubProcess();
    var launches = 0;
    final manager = DesktopSubStoreManager.testing(
      launch: () async {
        if (launches++ == 0) throw const ProcessException('node', []);
        return child;
      },
      checkHealth: () async => true,
    );
    expect((await manager.start()).phase, SubStoreBackendPhase.failed);
    expect((await manager.start()).isRunning, isTrue);
    expect((await manager.stop()).phase, SubStoreBackendPhase.stopped);
  });

  test(
    'unconfirmed exit remains owned and prevents a duplicate launch',
    () async {
      final child = StubProcess()..confirmExit = false;
      var launches = 0;
      final manager = DesktopSubStoreManager.testing(
        launch: () async {
          launches++;
          return child;
        },
        checkHealth: () async => true,
      );
      expect((await manager.start()).isRunning, isTrue);
      expect((await manager.stop()).phase, SubStoreBackendPhase.failed);
      expect((await manager.start()).phase, SubStoreBackendPhase.failed);
      expect(launches, 1);
      child.ended.complete(0);
      await manager.stop();
    },
  );
}
