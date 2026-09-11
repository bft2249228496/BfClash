import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/kernel_controller.dart';

void main() {
  late HttpServer mockServer;
  late KernelManager manager;

  setUp(() async {
    mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    manager = KernelManager(
      apiBaseUrl: 'http://${mockServer.address.host}:${mockServer.port}',
      secret: 'test_token',
    );

    mockServer.listen((HttpRequest request) async {
      if (request.uri.path == '/proxies' && request.method == 'GET') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            json.encode({
              'proxies': {
                'GLOBAL': {
                  'name': 'GLOBAL',
                  'type': 'Selector',
                  'now': 'DIRECT',
                  'all': ['DIRECT', 'Proxy'],
                },
                'DIRECT': {
                  'name': 'DIRECT',
                  'type': 'Direct',
                  'history': [
                    {'delay': 25},
                  ],
                },
              },
            }),
          );
        await request.response.close();
      } else if (request.uri.path.startsWith('/proxies/') &&
          request.method == 'PUT') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });
  });

  tearDown(() async {
    await mockServer.close(force: true);
  });

  group('KernelManager 代理组与节点控制', () {
    test('正确获取代理组并解析', () async {
      final groups = await manager.getProxyGroups();
      expect(groups.containsKey('GLOBAL'), isTrue);
      final global = groups['GLOBAL']!;
      expect(global.name, equals('GLOBAL'));
      expect(global.type, equals('Selector'));
      expect(global.current, equals('DIRECT'));
      expect(global.all, containsAll(['DIRECT', 'Proxy']));
    });

    test('切换节点请求', () async {
      final ok = await manager.selectProxy('GLOBAL', 'Proxy');
      expect(ok, isTrue);
    });

    test('流量快照格式化速度计算', () {
      const snap1 = TrafficSnapshot(up: 512, down: 2048);
      expect(snap1.formattedUp, equals('512 B/s'));
      expect(snap1.formattedDown, equals('2.0 KB/s'));

      const snap2 = TrafficSnapshot(up: 1048576 * 5, down: 1048576 * 12);
      expect(snap2.formattedUp, equals('5.0 MB/s'));
      expect(snap2.formattedDown, equals('12.0 MB/s'));
    });
  });
}
