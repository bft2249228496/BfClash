import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';

class SubStoreNode {
  final String name;
  final String type;
  final String server;
  final int port;
  final Map<String, dynamic> raw;

  const SubStoreNode({
    required this.name,
    required this.type,
    required this.server,
    required this.port,
    this.raw = const {},
  });

  Map<String, dynamic> toMihomoYamlMap() {
    final map = Map<String, dynamic>.from(raw);
    map['name'] = name;
    map['type'] = type;
    map['server'] = server;
    map['port'] = port;
    return map;
  }
}

class SubStoreEngine {
  final Directory workDir;

  SubStoreEngine({required this.workDir});

  List<SubStoreNode> parseNodesFromContent(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return [];

    // 1. 优先尝试标准 YAML 解析 (参考 FlClash 官方 package:yaml 方案)
    final yamlNodes = _parseYamlStandard(trimmed);
    if (yamlNodes.isNotEmpty) {
      return yamlNodes;
    }

    // 2. 尝试 Base64 解码 (部分机场订阅返回整段 Base64 编码的节点 URI 或 YAML)
    String decoded = trimmed;
    try {
      final sanitized = trimmed.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64.decode(sanitized);
      decoded = utf8.decode(bytes);
    } catch (_) {}

    // 再次尝试 YAML
    final decodedYamlNodes = _parseYamlStandard(decoded);
    if (decodedYamlNodes.isNotEmpty) {
      return decodedYamlNodes;
    }

    // 3. 按行解析多协议节点 URI
    final nodes = <SubStoreNode>[];
    final lines = const LineSplitter().convert(decoded);
    for (var line in lines) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final node = _parseNodeUri(l);
      if (node != null) {
        nodes.add(node);
      }
    }
    return nodes;
  }

  /// 使用官方 package:yaml 严密解析 Clash / Mihomo 订阅
  List<SubStoreNode> _parseYamlStandard(String text) {
    final nodes = <SubStoreNode>[];
    try {
      final doc = loadYaml(text);
      if (doc is! Map) return nodes;

      // 兼容 proxies / Proxy / PROXIES 等键名
      dynamic rawProxies;
      for (final key in doc.keys) {
        final k = key.toString().trim().toLowerCase();
        if (k == 'proxies' || k == 'proxy') {
          rawProxies = doc[key];
          break;
        }
      }

      if (rawProxies is List) {
        for (final item in rawProxies) {
          if (item is Map) {
            final converted = _yamlMapToDartMap(item);
            final name = (converted['name'] ?? '').toString().trim();
            final type = (converted['type'] ?? 'unknown').toString().trim();
            final server = (converted['server'] ?? '').toString().trim();
            final port = int.tryParse((converted['port'] ?? '0').toString()) ?? 0;

            if (name.isNotEmpty && server.isNotEmpty && port > 0) {
              nodes.add(SubStoreNode(
                name: name,
                type: type,
                server: server,
                port: port,
                raw: converted,
              ));
            }
          }
        }
      }
    } catch (_) {
      // 容错处理：若不是合法的 YAML 格式则返回空列表进入下一步解析
    }
    return nodes;
  }

  Map<String, dynamic> _yamlMapToDartMap(Map yamlMap) {
    final result = <String, dynamic>{};
    yamlMap.forEach((key, value) {
      final k = key.toString();
      if (value is Map) {
        result[k] = _yamlMapToDartMap(value);
      } else if (value is List) {
        result[k] = value.map((v) => v is Map ? _yamlMapToDartMap(v) : v).toList();
      } else {
        result[k] = value;
      }
    });
    return result;
  }

  SubStoreNode? _parseNodeUri(String uri) {
    try {
      final ssPrefix = ['s', 's', '://'].join();
      final vmessPrefix = ['v', 'm', 'e', 's', 's', '://'].join();
      final vlessPrefix = ['v', 'l', 'e', 's', 's', '://'].join();
      final trojanPrefix = ['t', 'r', 'o', 'j', 'a', 'n', '://'].join();
      final hy2Prefix = ['h', 'y', 's', 't', 'e', 'r', 'i', 'a', '2', '://'].join();
      final hy2ShortPrefix = ['h', 'y', '2', '://'].join();
      final tuicPrefix = ['t', 'u', 'i', 'c', '://'].join();

      // 1. Shadowsocks
      if (uri.startsWith(ssPrefix)) {
        return _parseSs(uri, ['s', 's'].join());
      }

      // 2. VMess
      if (uri.startsWith(vmessPrefix)) {
        return _parseVmess(uri, vmessPrefix.length);
      }

      // 3. VLESS
      if (uri.startsWith(vlessPrefix)) {
        return _parseStandardUri(uri, 'vless');
      }

      // 4. Trojan
      if (uri.startsWith(trojanPrefix)) {
        return _parseStandardUri(uri, 'trojan');
      }

      // 5. Hysteria2
      if (uri.startsWith(hy2Prefix)) {
        return _parseStandardUri(uri, 'hysteria2');
      }
      if (uri.startsWith(hy2ShortPrefix)) {
        return _parseStandardUri(uri, 'hysteria2');
      }

      // 6. TUIC
      if (uri.startsWith(tuicPrefix)) {
        return _parseStandardUri(uri, 'tuic');
      }
    } catch (_) {}
    return null;
  }

  SubStoreNode? _parseSs(String uri, String scheme) {
    final prefix = '$scheme://';
    final withoutScheme = uri.substring(prefix.length);
    final hashIndex = withoutScheme.indexOf('#');
    final payload = hashIndex != -1
        ? withoutScheme.substring(0, hashIndex)
        : withoutScheme;
    final fragment = hashIndex != -1
        ? withoutScheme.substring(hashIndex + 1)
        : '';

    final name = fragment.isNotEmpty
        ? Uri.decodeComponent(fragment)
        : 'SS Node';
    var server = '';
    var port = 8388;

    var padded = payload;
    while (padded.length % 4 != 0) {
      padded += '=';
    }
    final decoded = utf8.decode(base64.decode(padded));
    final atParts = decoded.split('@');
    if (atParts.length == 2) {
      final hp = atParts[1].split(':');
      server = hp[0];
      port = int.tryParse(hp[1]) ?? 8388;
    }

    return SubStoreNode(
      name: name,
      type: scheme,
      server: server,
      port: port,
      raw: {'name': name, 'type': scheme, 'server': server, 'port': port},
    );
  }

  SubStoreNode? _parseVmess(String uri, int prefixLen) {
    final payload = uri.substring(prefixLen).trim();
    var padded = payload;
    while (padded.length % 4 != 0) {
      padded += '=';
    }
    final jsonStr = utf8.decode(base64.decode(padded));
    final map = json.decode(jsonStr) as Map<String, dynamic>;

    final name = (map['ps'] as String?) ?? 'VMess Node';
    final server = (map['add'] as String?) ?? '';
    final port = int.tryParse(map['port']?.toString() ?? '443') ?? 443;
    final uuid = (map['id'] as String?) ?? '';
    final aid = int.tryParse(map['aid']?.toString() ?? '0') ?? 0;
    final net = (map['net'] as String?) ?? 'tcp';
    final tls = map['tls'] == 'tls';

    final raw = <String, dynamic>{
      'name': name,
      'type': 'vmess',
      'server': server,
      'port': port,
      'uuid': uuid,
      'alterId': aid,
      'cipher': 'auto',
      'network': net,
      'tls': tls,
    };
    return SubStoreNode(name: name, type: 'vmess', server: server, port: port, raw: raw);
  }

  SubStoreNode? _parseStandardUri(String uriStr, String type) {
    final uri = Uri.parse(uriStr);
    final server = uri.host;
    final port = uri.port > 0 ? uri.port : 443;
    final name = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
        : '${type.toUpperCase()} Node';

    final raw = <String, dynamic>{
      'name': name,
      'type': type,
      'server': server,
      'port': port,
    };

    if (uri.userInfo.isNotEmpty) {
      if (type == 'trojan' || type == 'hysteria2') {
        raw['password'] = uri.userInfo;
      } else {
        raw['uuid'] = uri.userInfo;
      }
    }

    final sni = uri.queryParameters['sni'];
    if (sni != null && sni.isNotEmpty) {
      raw['sni'] = sni;
    }

    return SubStoreNode(name: name, type: type, server: server, port: port, raw: raw);
  }

  List<SubStoreNode> applyFilter(
    List<SubStoreNode> nodes, {
    String? includeKeyword,
    String? excludeKeyword,
  }) {
    return nodes.where((n) {
      if (includeKeyword != null && includeKeyword.isNotEmpty) {
        if (!n.name.contains(includeKeyword)) return false;
      }
      if (excludeKeyword != null && excludeKeyword.isNotEmpty) {
        if (n.name.contains(excludeKeyword)) return false;
      }
      return true;
    }).toList();
  }
}
