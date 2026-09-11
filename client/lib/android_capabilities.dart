import 'dart:convert';
import 'dart:io';

enum SplitTunnelMode {
  whitelist, // 仅允许选中应用走代理
  blacklist, // 仅允许选中应用绕过代理
  all, // 全部应用走代理
}

class AndroidSystemCapabilities {
  final SplitTunnelMode splitTunnelMode;
  final Set<String> packageList;
  final bool autoStartOnBoot;
  final bool enableNotificationControls;
  final bool enableQuickTile;
  final int tunMtu;
  final String tunIpv4Address;
  final List<String> dnsServers;
  final int mixedPort;

  const AndroidSystemCapabilities({
    this.splitTunnelMode = SplitTunnelMode.all,
    this.packageList = const {},
    this.autoStartOnBoot = false,
    this.enableNotificationControls = true,
    this.enableQuickTile = true,
    this.tunMtu = 1500,
    this.tunIpv4Address = '172.19.0.1/30',
    this.dnsServers = const ['172.19.0.2', '1.1.1.1'],
    this.mixedPort = 7890,
  });

  Map<String, dynamic> toJson() => {
    'splitTunnelMode': splitTunnelMode.name,
    'packageList': packageList.toList(),
    'autoStartOnBoot': autoStartOnBoot,
    'enableNotificationControls': enableNotificationControls,
    'enableQuickTile': enableQuickTile,
    'tunMtu': tunMtu,
    'tunIpv4Address': tunIpv4Address,
    'dnsServers': dnsServers,
    'mixedPort': mixedPort,
  };

  factory AndroidSystemCapabilities.fromJson(Map<String, dynamic> json) =>
      AndroidSystemCapabilities(
        splitTunnelMode: SplitTunnelMode.values.firstWhere(
          (m) => m.name == json['splitTunnelMode'],
          orElse: () => SplitTunnelMode.all,
        ),
        packageList:
            (json['packageList'] as List?)?.map((e) => e.toString()).toSet() ??
            const {},
        autoStartOnBoot: json['autoStartOnBoot'] as bool? ?? false,
        enableNotificationControls:
            json['enableNotificationControls'] as bool? ?? true,
        enableQuickTile: json['enableQuickTile'] as bool? ?? true,
        tunMtu: (json['tunMtu'] as num?)?.toInt() ?? 1500,
        tunIpv4Address: json['tunIpv4Address'] as String? ?? '172.19.0.1/30',
        dnsServers:
            (json['dnsServers'] as List?)?.map((e) => e.toString()).toList() ??
            const ['172.19.0.2', '1.1.1.1'],
        mixedPort: (json['mixedPort'] as num?)?.toInt() ?? 7890,
      );

  Map<String, dynamic> toMihomoTunConfig() => {
    'tun': {
      'enable': true,
      'stack': 'mixed',
      'dns-hijack': ['any:53', 'tcp://any:53'],
      'auto-route': true,
      'auto-detect-interface': true,
      'mtu': tunMtu,
    },
    'dns': {
      'enable': true,
      'listen': '0.0.0.0:1053',
      'enhanced-mode': 'fake-ip',
      'fake-ip-range': '198.18.0.1/16',
      'nameserver': dnsServers,
    },
    'mixed-port': mixedPort,
  };
}

class SystemCapabilitiesManager {
  final File configFile;
  AndroidSystemCapabilities _capabilities = const AndroidSystemCapabilities();

  SystemCapabilitiesManager({required this.configFile});

  AndroidSystemCapabilities get capabilities => _capabilities;

  Future<void> load() async {
    if (await configFile.exists()) {
      try {
        final content = await configFile.readAsString();
        final jsonMap = json.decode(content);
        if (jsonMap is Map<String, dynamic>) {
          _capabilities = AndroidSystemCapabilities.fromJson(jsonMap);
        }
      } catch (_) {}
    }
  }

  Future<void> save(AndroidSystemCapabilities newCaps) async {
    _capabilities = newCaps;
    if (!await configFile.parent.exists()) {
      await configFile.parent.create(recursive: true);
    }
    await configFile.writeAsString(
      json.encode(_capabilities.toJson()),
      flush: true,
    );
  }
}
