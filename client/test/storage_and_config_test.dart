import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/storage_and_config.dart';

void main() {
  late Directory tempDir;
  late StorageAndConfigManager manager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lansway_test_');
    manager = StorageAndConfigManager(baseDir: tempDir);
    await manager.initializeDirectories();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('配置校验器', () {
    test('拒绝空配置', () {
      final res = manager.validateYamlConfig('   ');
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('为空'));
    });

    test('拒绝含有泄漏标记的配置', () {
      final res = manager.validateYamlConfig(
        'proxies:\n  - name: leaked_token\n',
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('敏感'));
    });

    test('缺少代理组时校验失败', () {
      final res = manager.validateYamlConfig('port: 7890\nsocks-port: 7891\n');
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('缺少 proxies'));
    });

    test('合法配置校验成功并解析统计', () {
      const validYaml = '''
port: 7890
proxies:
  - name: "node-1"
    type: ss
    server: 1.2.3.4
    port: 8388
  - name: "node-2"
    type: ss
    server: 1.2.3.5
    port: 8388
rules:
  - MATCH,DIRECT
''';
      final res = manager.validateYamlConfig(validYaml);
      expect(res.isValid, isTrue);
      expect(res.proxyCount, equals(2));
      expect(res.ruleCount, equals(1));
    });
  });

  group('原子写入与失败回退', () {
    test('原子写入成功', () async {
      const yaml = 'proxies:\n  - name: test\n';
      final ok = await manager.saveActiveConfigAtomic(yaml);
      expect(ok, isTrue);
      expect(await manager.activeConfigFile.exists(), isTrue);
      expect(await manager.activeConfigFile.readAsString(), equals(yaml));
    });

    test('校验不通过时阻止写入并不覆盖旧版本', () async {
      const goodYaml = 'proxies:\n  - name: good\n';
      await manager.saveActiveConfigAtomic(goodYaml);

      expect(
        () async => await manager.saveActiveConfigAtomic('invalid content'),
        throwsFormatException,
      );

      // 旧配置依旧保持
      expect(await manager.activeConfigFile.readAsString(), equals(goodYaml));
    });
  });

  group('凭据脱敏与沙箱存储', () {
    test('安全存取凭据', () async {
      await manager.saveEncryptedCredential('webdav_password', 'p@ssw0rd123');
      final retrieved = await manager.getDecryptedCredential('webdav_password');
      expect(retrieved, equals('p@ssw0rd123'));

      // 文件中不能明文暴露密码
      final rawFile = await manager.credentialsFile.readAsString();
      expect(rawFile.contains('p@ssw0rd123'), isFalse);
    });

    test('未存入的 key 返回 null', () async {
      final none = await manager.getDecryptedCredential('non_existent');
      expect(none, isNull);
    });
  });
}
