import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/update_checker.dart';

void main() {
  group('UpdateManager 版本号比较逻辑', () {
    test('比较常见版本号', () {
      expect(UpdateManager.compareVersions('v0.1.4', 'v0.1.3'), greaterThan(0));
      expect(UpdateManager.compareVersions('v0.1.3', 'v0.1.4'), lessThan(0));
      expect(UpdateManager.compareVersions('v0.1.3', 'v0.1.3'), equals(0));
      expect(UpdateManager.compareVersions('v1.0.0', 'v0.9.9'), greaterThan(0));
      expect(UpdateManager.compareVersions('0.2.0', 'v0.1.9'), greaterThan(0));
    });

    test('解析 Release JSON 结构', () {
      final sampleJson = {
        'tag_name': 'v0.1.4',
        'name': 'Release v0.1.4',
        'body': '新增自动在线检查更新功能',
        'published_at': '2026-09-12T03:00:00Z',
        'html_url':
            'https://github.com/bft2249228496/clash-self/releases/tag/v0.1.4',
        'assets': [
          {
            'name': 'app-debug.apk',
            'browser_download_url': 'https://github.com/bft2249228496/clash-self/releases/download/v0.1.4/app-debug.apk',
          },
        ],
      };

      final release = ReleaseInfo.fromJson(sampleJson);
      expect(release.tagName, equals('v0.1.4'));
      expect(release.name, equals('Release v0.1.4'));
      expect(release.body, contains('新增自动在线检查更新'));
      expect(release.apkDownloadUrl, contains('app-debug.apk'));
    });
  });
}
