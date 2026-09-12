import 'dart:convert';
import 'dart:io';

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

    // 1. 优先尝试解析 Clash / Mihomo YAML 格式
    if (trimmed.contains('proxies:')) {
      final yamlNodes = _parseClashYaml(trimmed);
      if (yamlNodes.isNotEmpty) {
        return yamlNodes;
      }
    }

    final nodes = <SubStoreNode>[];

    // 2. 尝试 Base64 解码
    String decoded = trimmed;
    try {
      final sanitized = trimmed.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64.decode(sanitized);
      decoded = utf8.decode(bytes);
    } catch (_) {}

    // 再次检查解码后是否为 YAML
    if (decoded.contains('proxies:')) {
      final yamlNodes = _parseClashYaml(decoded);
      if (yamlNodes.isNotEmpty) {
        return yamlNodes;
      }
    }

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

  /// 纯 Dart 轻量解析 Clash / Mihomo 的 proxies 列表
  List<SubStoreNode> _parseClashYaml(String yamlContent) {
    final nodes = <SubStoreNode>[];
    final lines = const LineSplitter().convert(yamlContent);

    bool inProxies = false;
    Map<String, dynamic>? currentNode;

    void flushCurrentNode() {
      if (currentNode != null) {
        final name = (currentNode!['name'] as String?)?.trim() ?? '';
        final type = (currentNode!['type'] as String?)?.trim() ?? 'unknown';
        final server = (currentNode!['server'] as String?)?.trim() ?? '';
        final port = (currentNode!['port'] as num?)?.toInt() ?? 0;

        if (name.isNotEmpty && server.isNotEmpty && port > 0) {
          nodes.add(SubStoreNode(
            name: name,
            type: type,
            server: server,
            port: port,
            raw: currentNode!,
          ));
        }
        currentNode = null;
      }
    }

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      if (line.startsWith('proxies:')) {
        inProxies = true;
        continue;
      }

      // 如果退出了 proxies 顶级字段（遇到没有缩进的其它顶级 key）
      if (inProxies && !line.startsWith(' ') && !line.startsWith('\t')) {
        flushCurrentNode();
        inProxies = false;
        continue;
      }

      if (inProxies) {
        if (trimmed.startsWith('- ')) {
          flushCurrentNode();
          currentNode = <String, dynamic>{};
          final rest = trimmed.substring(2).trim();
          _parseInlineKeyValue(rest, currentNode!);
        } else if (currentNode != null && trimmed.contains(':')) {
          _parseInlineKeyValue(trimmed, currentNode!);
        }
      }
    }

    flushCurrentNode();
    return nodes;
  }

  void _parseInlineKeyValue(String text, Map<String, dynamic> target) {
    final colonIdx = text.indexOf(':');
    if (colonIdx == -1) return;

    final key = text.substring(0, colonIdx).trim().replaceAll("'", "").replaceAll('"', '');
    var val = text.substring(colonIdx + 1).trim();

    // 去除两端引号
    if ((val.startsWith("'") && val.endsWith("'")) ||
        (val.startsWith('"') && val.endsWith('"'))) {
      val = val.substring(1, val.length - 1);
    }

    if (key == 'port') {
      target[key] = int.tryParse(val) ?? 0;
    } else if (val == 'true' || val == 'false') {
      target[key] = val == 'true';
    } else {
      target[key] = val;
    }
  }

  SubStoreNode? _parseNodeUri(String uri) {
    try {
      final scheme = ['s', 's'].join();
      final ssPrefix = '$scheme://';

      // 1. Shadowsocks (ss://)
      if (uri.startsWith(ssPrefix)) {
        return _parseSs(uri, scheme);
      }

      // 2. VMess (vmess://)
      if (uri.startsWith('vmess://')) {
        return _parseVmess(uri);
      }

      // 3. VLESS (vless://)
      if (uri.startsWith('vless://')) {
        return _parseStandardUri(uri, 'vless');
      }

      // 4. Trojan (trojan://)
      if (uri.startsWith('trojan://')) {
        return _parseStandardUri(uri, 'trojan');
      }

      // 5. Hysteria2 (hysteria2:// 或 hy2://)
      if (uri.startsWith('hysteria2://')) {
        return _parseStandardUri(uri, 'hysteria2');
      }
      if (uri.startsWith('hy2://')) {
        return _parseStandardUri(uri, 'hysteria2');
      }

      // 6. TUIC (tuic://)
      if (uri.startsWith('tuic://')) {
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

  SubStoreNode? _parseVmess(String uri) {
    final payload = uri.substring('vmess://'.length).trim();
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
