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
    final lowerTrimmed = trimmed.toLowerCase();
    if (lowerTrimmed.contains('proxies:') || lowerTrimmed.contains('proxy:')) {
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
    final lowerDecoded = decoded.toLowerCase();
    if (lowerDecoded.contains('proxies:') || lowerDecoded.contains('proxy:')) {
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

  /// 纯 Dart 鲁棒解析 Clash / Mihomo 的 proxies 列表（同时支持 flow-style 行内 JSON 映射和 block-style 缩进映射）
  List<SubStoreNode> _parseClashYaml(String yamlContent) {
    final nodes = <SubStoreNode>[];
    final lines = const LineSplitter().convert(yamlContent);

    bool inProxies = false;
    Map<String, dynamic>? currentBlockNode;

    void flushBlockNode() {
      if (currentBlockNode != null) {
        _addNodeIfValid(currentBlockNode!, nodes);
        currentBlockNode = null;
      }
    }

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final lowerTrimmed = trimmed.toLowerCase();
      if (lowerTrimmed.startsWith('proxies:') || lowerTrimmed.startsWith('proxy:')) {
        flushBlockNode();
        inProxies = true;
        continue;
      }

      // 如果退出了 proxies 顶级字段（遇到没有缩进的其它顶级 key）
      if (inProxies && !line.startsWith(' ') && !line.startsWith('\t')) {
        flushBlockNode();
        inProxies = false;
        continue;
      }

      if (inProxies) {
        // Pattern 1: Flow-style YAML 节点:
        // - {name: ..., type: ..., server: ..., port: ...}
        if (trimmed.startsWith('-') && trimmed.contains('{') && trimmed.endsWith('}')) {
          flushBlockNode();
          final map = _parseFlowStyleMap(trimmed);
          if (map != null) {
            _addNodeIfValid(map, nodes);
          }
          continue;
        }

        // Pattern 2: Block style YAML 节点:
        // - name: "HK 01"
        //   type: ss
        //   server: 1.1.1.1
        //   port: 8388
        if (trimmed.startsWith('- ')) {
          flushBlockNode();
          currentBlockNode = <String, dynamic>{};
          final rest = trimmed.substring(2).trim();
          _parseKeyValue(rest, currentBlockNode!);
        } else if (currentBlockNode != null && trimmed.contains(':')) {
          _parseKeyValue(trimmed, currentBlockNode!);
        }
      }
    }

    flushBlockNode();
    return nodes;
  }

  void _addNodeIfValid(Map<String, dynamic> raw, List<SubStoreNode> list) {
    final name = (raw['name'] as String?)?.trim() ?? '';
    final type = (raw['type'] as String?)?.trim() ?? 'unknown';
    final server = (raw['server'] as String?)?.trim() ?? '';
    final port = (raw['port'] as num?)?.toInt() ?? 0;

    if (name.isNotEmpty && server.isNotEmpty && port > 0) {
      list.add(SubStoreNode(
        name: name,
        type: type,
        server: server,
        port: port,
        raw: raw,
      ));
    }
  }

  Map<String, dynamic>? _parseFlowStyleMap(String line) {
    var s = line.trim();
    if (s.startsWith('-')) {
      s = s.substring(1).trim();
    }
    if (s.startsWith('{') && s.endsWith('}')) {
      s = s.substring(1, s.length - 1).trim();
    } else {
      return null;
    }

    final target = <String, dynamic>{};
    final parts = _splitByTopLevelComma(s);
    for (var part in parts) {
      _parseKeyValue(part, target);
    }
    return target;
  }

  List<String> _splitByTopLevelComma(String s) {
    final result = <String>[];
    var sb = StringBuffer();
    bool inSingle = false;
    bool inDouble = false;
    int braceDepth = 0;
    int bracketDepth = 0;

    for (int i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == "'" && !inDouble) {
        inSingle = !inSingle;
        sb.write(c);
      } else if (c == '"' && !inSingle) {
        inDouble = !inDouble;
        sb.write(c);
      } else if (!inSingle && !inDouble) {
        if (c == '{') braceDepth++;
        if (c == '}') braceDepth--;
        if (c == '[') bracketDepth++;
        if (c == ']') bracketDepth--;

        if (c == ',' && braceDepth == 0 && bracketDepth == 0) {
          result.add(sb.toString().trim());
          sb.clear();
        } else {
          sb.write(c);
        }
      } else {
        sb.write(c);
      }
    }
    if (sb.isNotEmpty) {
      result.add(sb.toString().trim());
    }
    return result;
  }

  void _parseKeyValue(String text, Map<String, dynamic> target) {
    final colonIdx = text.indexOf(':');
    if (colonIdx == -1) return;

    var key = text.substring(0, colonIdx).trim();
    if ((key.startsWith("'") && key.endsWith("'")) ||
        (key.startsWith('"') && key.endsWith('"'))) {
      key = key.substring(1, key.length - 1);
    }

    var val = text.substring(colonIdx + 1).trim();
    if ((val.startsWith("'") && val.endsWith("'")) ||
        (val.startsWith('"') && val.endsWith('"'))) {
      val = val.substring(1, val.length - 1);
    }

    if (key == 'port' || key == 'alterId') {
      target[key] = int.tryParse(val) ?? 0;
    } else if (val == 'true' || val == 'false') {
      target[key] = val == 'true';
    } else {
      target[key] = val;
    }
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
