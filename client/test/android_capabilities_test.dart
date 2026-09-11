import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/android_capabilities.dart';

void main() {
  late Directory tempDir;
  late File configFile;
  late SystemCapabilitiesManager manager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('android_caps_');
    configFile = File('${tempDir.path}/system_caps.json');
    manager = SystemCapabilitiesManager(configFile: configFile);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AndroidSystemCapabilities', () {
    test('默认参数与 TUN 配置生成', () {
      const caps = AndroidSystemCapabilities(
        splitTunnelMode: SplitTunnelMode.blacklist,
        packageList: {'com.android.chrome', 'com.tencent.mm'},
        mixedPort: 7895,
      );

      final mihomoTun = caps.toMihomoTunConfig();
      expect(mihomoTun['mixed-port'], equals(7895));
      expect(mihomoTun['tun']['enable'], isTrue);
      expect(mihomoTun['tun']['mtu'], equals(1500));
      expect(mihomoTun['dns']['enhanced-mode'], equals('fake-ip'));
    });

    test('系统能力设置持久化与重新读取', () async {
      const newCaps = AndroidSystemCapabilities(
        splitTunnelMode: SplitTunnelMode.whitelist,
        packageList: {'com.example.app'},
        autoStartOnBoot: true,
        enableQuickTile: true,
        mixedPort: 10808,
      );

      await manager.save(newCaps);
      expect(await configFile.exists(), isTrue);

      final reloadedManager = SystemCapabilitiesManager(configFile: configFile);
      await reloadedManager.load();
      expect(
        reloadedManager.capabilities.splitTunnelMode,
        equals(SplitTunnelMode.whitelist),
      );
      expect(
        reloadedManager.capabilities.packageList,
        contains('com.example.app'),
      );
      expect(reloadedManager.capabilities.autoStartOnBoot, isTrue);
      expect(reloadedManager.capabilities.mixedPort, equals(10808));
    });
  });
}
