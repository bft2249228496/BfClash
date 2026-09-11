import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ProxyNode {
  final String name;
  final String type;
  final int delay; // ms, 0 means not tested or timeout

  const ProxyNode({required this.name, required this.type, this.delay = 0});

  factory ProxyNode.fromJson(Map<String, dynamic> json) => ProxyNode(
    name: json['name'] as String? ?? '未命名',
    type: json['type'] as String? ?? 'Direct',
    delay: (json['history'] as List?)?.lastOrNull?['delay'] as int? ?? 0,
  );
}

class ProxyGroup {
  final String name;
  final String type;
  final String current;
  final List<String> all;

  const ProxyGroup({
    required this.name,
    required this.type,
    required this.current,
    required this.all,
  });

  factory ProxyGroup.fromJson(String name, Map<String, dynamic> json) =>
      ProxyGroup(
        name: name,
        type: json['type'] as String? ?? 'Selector',
        current: json['now'] as String? ?? '',
        all: (json['all'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class TrafficSnapshot {
  final int up; // bytes/s
  final int down; // bytes/s

  const TrafficSnapshot({this.up = 0, this.down = 0});

  String get formattedUp => _formatSpeed(up);
  String get formattedDown => _formatSpeed(down);

  static String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}

class KernelManager {
  final String apiBaseUrl;
  final String? secret;
  HttpClient? _client;

  KernelManager({this.apiBaseUrl = 'http://127.0.0.1:9090', this.secret});

  HttpClient get client => _client ??= HttpClient();

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (secret != null && secret!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $secret';
    }
    return headers;
  }

  Future<Map<String, ProxyGroup>> getProxyGroups() async {
    try {
      final request = await client.getUrl(Uri.parse('$apiBaseUrl/proxies'));
      _headers.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = json.decode(body) as Map<String, dynamic>;
        final proxies = data['proxies'] as Map<String, dynamic>? ?? {};
        final groups = <String, ProxyGroup>{};
        proxies.forEach((k, v) {
          if (v is Map<String, dynamic> &&
              (v['type'] == 'Selector' ||
                  v['type'] == 'URLTest' ||
                  v['type'] == 'Fallback')) {
            groups[k] = ProxyGroup.fromJson(k, v);
          }
        });
        return groups;
      }
    } catch (_) {}
    return {};
  }

  Future<bool> selectProxy(String groupName, String selectedProxy) async {
    try {
      final uri = Uri.parse(
        '$apiBaseUrl/proxies/${Uri.encodeComponent(groupName)}',
      );
      final request = await client.putUrl(uri);
      _headers.forEach((k, v) => request.headers.set(k, v));
      request.write(json.encode({'name': selectedProxy}));
      final response = await request.close();
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<int> delayTest(
    String proxyName, {
    String testUrl = 'http://cp.cloudflare.com/generate_204',
    int timeoutMs = 5000,
  }) async {
    try {
      final uri = Uri.parse(
        '$apiBaseUrl/proxies/${Uri.encodeComponent(proxyName)}/delay?url=${Uri.encodeComponent(testUrl)}&timeout=$timeoutMs',
      );
      final request = await client.getUrl(uri);
      _headers.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = json.decode(body) as Map<String, dynamic>;
        return data['delay'] as int? ?? 0;
      }
    } catch (_) {}
    return 0;
  }
}
