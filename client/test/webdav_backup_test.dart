import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/webdav_backup.dart';

void main() {
  late HttpServer mockServer;
  late WebDavBackupManager manager;

  setUp(() async {
    mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    manager = WebDavBackupManager(
      config: WebDavConfig(
        serverUrl: 'http://${mockServer.address.host}:${mockServer.port}',
        username: 'user',
        password: 'pwd',
      ),
    );

    mockServer.listen((HttpRequest req) async {
      if (req.method == 'PROPFIND') {
        req.response.statusCode = HttpStatus.multiStatus;
        await req.response.close();
      } else if (req.method == 'PUT') {
        req.response.statusCode = HttpStatus.created;
        await req.response.close();
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
  });

  tearDown(() async {
    await mockServer.close(force: true);
  });

  group('WebDavBackupManager', () {
    test('PROPFIND 连通性测试', () async {
      final ok = await manager.testConnection();
      expect(ok, isTrue);
    });

    test('上传备份文件', () async {
      final ok = await manager.uploadBackup('test_backup.yaml', 'port: 7890');
      expect(ok, isTrue);
    });
  });
}
