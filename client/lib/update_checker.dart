import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class ReleaseInfo {
  final String tagName;
  final String name;
  final String body;
  final String apkDownloadUrl;
  final String htmlUrl;
  final DateTime publishedAt;

  const ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.apkDownloadUrl,
    required this.htmlUrl,
    required this.publishedAt,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    String apkUrl = '';
    if (json['assets'] is List) {
      for (var asset in json['assets']) {
        if (asset is Map<String, dynamic>) {
          final assetName = asset['name'] as String? ?? '';
          if (assetName.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String? ?? '';
            break;
          }
        }
      }
    }
    return ReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? (json['tag_name'] as String? ?? ''),
      body: json['body'] as String? ?? '',
      apkDownloadUrl: apkUrl,
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(json['published_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class UpdateManager {
  static const String currentVersion = 'v0.1.6';
  static const String repo = 'bft2249228496/clash-self';
  static const MethodChannel _installChannel = MethodChannel(
    'com.lansway.client/app_installer',
  );

  /// 检查是否有新版本
  static Future<ReleaseInfo?> checkUpdate({String repoName = repo}) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final url = 'https://api.github.com/repos/$repoName/releases/latest';
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'Lansway-App-Updater');
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final jsonMap = json.decode(body) as Map<String, dynamic>;
        final release = ReleaseInfo.fromJson(jsonMap);
        if (compareVersions(release.tagName, currentVersion) > 0) {
          return release;
        }
      }
    } catch (_) {
      // 忽略网络错误，静默处理
    } finally {
      client.close();
    }
    return null;
  }

  /// 比较两个版本号，例如 v0.1.4 与 v0.1.3
  /// tag1 > tag2 返回正数，tag1 == tag2 返回 0，tag1 < tag2 返回负数
  static int compareVersions(String v1, String v2) {
    final clean1 = v1.replaceAll(RegExp(r'[^0-9.]'), '');
    final clean2 = v2.replaceAll(RegExp(r'[^0-9.]'), '');
    final parts1 = clean1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = clean2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = parts1.length > parts2.length
        ? parts1.length
        : parts2.length;
    for (int i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) {
        return p1.compareTo(p2);
      }
    }
    return 0;
  }

  /// 下载 APK 到本地临时目录，并上报下载进度 (0.0 ~ 1.0)
  static Future<File> downloadApk(
    String downloadUrl, {
    void Function(double progress, int received, int total)? onProgress,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(downloadUrl));
      request.headers.set('User-Agent', 'Lansway-App-Updater');
      final response = await request.close();

      if (response.statusCode != 200 && response.statusCode != 302) {
        throw HttpException('下载失败，HTTP 状态码: ${response.statusCode}');
      }

      // 如果遇到重定向
      HttpClientResponse finalResponse = response;
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = response.headers.value('location');
        if (redirectUrl != null) {
          final redirectReq = await client.getUrl(Uri.parse(redirectUrl));
          finalResponse = await redirectReq.close();
        }
      }

      final contentLength = finalResponse.contentLength;
      final tempDir = Directory.systemTemp;
      final targetFile = File('${tempDir.path}/lansway_update.apk');
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      final sink = targetFile.openWrite();
      int received = 0;

      await for (var chunk in finalResponse) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress(received / contentLength, received, contentLength);
        }
      }
      await sink.close();
      return targetFile;
    } finally {
      client.close();
    }
  }

  /// 调用 Android 系统安装器安装 APK
  static Future<bool> installApk(String filePath) async {
    try {
      final result = await _installChannel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
