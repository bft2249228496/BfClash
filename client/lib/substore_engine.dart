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

    final nodes = <SubStoreNode>[];

    String decoded = trimmed;
    try {
      final sanitized = trimmed.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64.decode(sanitized);
      decoded = utf8.decode(bytes);
    } catch (_) {}

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

  SubStoreNode? _parseNodeUri(String uri) {
    try {
      final parsed = Uri.parse(uri);
      if (parsed.scheme == 'ss') {
        var server = parsed.host;
        var port = parsed.port;
        var name = parsed.fragment.isNotEmpty
            ? Uri.decodeComponent(parsed.fragment)
            : 'SS Node';

        final rawPayload = (parsed.userInfo.isNotEmpty && server.isEmpty)
            ? parsed.userInfo
            : server;

        if (rawPayload.isNotEmpty) {
          try {
            var padded = rawPayload;
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
          } catch (_) {}
        }

        return SubStoreNode(name: name, type: 'ss', server: server, port: port);
      }
    } catch (_) {}
    return null;
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
