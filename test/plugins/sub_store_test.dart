import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/plugins/sub_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('$packageName/sub-store');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('decodes a running Android backend status', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return <String, Object?>{
            'phase': 'running',
            'endpoint': 'http://127.0.0.1:3001',
            'backendVersion': '2.39.8',
            'error': null,
          };
        });

    final status = await SubStoreService(channel: channel).status();

    expect(status.phase, SubStoreBackendPhase.running);
    expect(status.isRunning, isTrue);
    expect(status.endpoint, 'http://127.0.0.1:3001');
    expect(status.backendVersion, '2.39.8');
    expect(status.error, isNull);
  });

  test('forwards start and stop to the Android plugin', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          return <String, Object?>{
            'phase': call.method == 'start' ? 'starting' : 'stopped',
            'endpoint': 'http://127.0.0.1:3001',
            'backendVersion': '2.39.8',
          };
        });
    final service = SubStoreService(channel: channel);

    final starting = await service.start();
    final stopped = await service.stop();

    expect(methods, ['start', 'stop']);
    expect(starting.isBusy, isTrue);
    expect(stopped.phase, SubStoreBackendPhase.stopped);
  });

  test('treats unknown native phases as failed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return <String, Object?>{
            'phase': 'unexpected',
            'endpoint': '',
            'backendVersion': '',
          };
        });

    final status = await SubStoreService(channel: channel).status();

    expect(status.phase, SubStoreBackendPhase.failed);
  });
}
