import 'dart:convert';
import 'dart:io';

class WebDavConfig {
  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;

  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.remotePath = '/lansway_backup',
  });

  String get authHeader =>
      'Basic ${base64.encode(utf8.encode('$username:$password'))}';
}

class WebDavBackupManager {
  final WebDavConfig config;
  HttpClient? _client;

  WebDavBackupManager({required this.config});

  HttpClient get client => _client ??= HttpClient();

  Future<bool> testConnection() async {
    try {
      final uri = Uri.parse(config.serverUrl);
      final req = await client.openUrl('PROPFIND', uri);
      req.headers.set('Authorization', config.authHeader);
      req.headers.set('Depth', '0');
      final res = await req.close();
      return res.statusCode == 200 ||
          res.statusCode == 207 ||
          res.statusCode == 405;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadBackup(String filename, String content) async {
    try {
      final base = config.serverUrl.endsWith('/')
          ? config.serverUrl.substring(0, config.serverUrl.length - 1)
          : config.serverUrl;
      final uri = Uri.parse('$base${config.remotePath}/$filename');
      final req = await client.putUrl(uri);
      req.headers.set('Authorization', config.authHeader);
      req.headers.set('Content-Type', 'text/yaml; charset=utf-8');
      req.write(content);
      final res = await req.close();
      return res.statusCode == 200 ||
          res.statusCode == 201 ||
          res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
