import 'package:bfclash/common/update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> release(String tag, {bool apk = true}) => {
    'tag_name': tag,
    'assets': [
      {
        'name': apk
            ? 'BfClash-0.3.0-android-arm64-v8a.apk'
            : 'BfClash-1.0.0-windows-amd64-setup.exe',
      },
    ],
  };

  test('测试通道（beta / rc）只接受 Beta 包名', () {
    for (final tag in ['v0.3.1-beta.1', 'v0.3.0-rc.1']) {
      expect(
        isAndroidReleaseCompatible(release(tag), 'com.bfclash.client.beta'),
        isTrue,
        reason: tag,
      );
      expect(
        isAndroidReleaseCompatible(release(tag), 'com.bfclash.client'),
        isFalse,
        reason: '$tag 不得被正式包接收',
      );
      expect(
        isAndroidReleaseCompatible(release(tag), 'com.lansway.client.beta'),
        isTrue,
        reason: '$tag 需兼容遗留 Beta 包名',
      );
    }
  });

  test('正式通道只接受无 stage 后缀的 tag', () {
    expect(
      isAndroidReleaseCompatible(release('v0.3.0'), 'com.bfclash.client'),
      isTrue,
    );
    expect(
      isAndroidReleaseCompatible(release('v0.3.0'), 'com.bfclash.client.beta'),
      isFalse,
    );
    expect(
      isAndroidReleaseCompatible(release('v0.3.0'), 'unknown.app'),
      isFalse,
    );
  });

  test('不合规的历史 / 自造 tag 一律拒绝', () {
    const rejected = [
      'v0.2.27-windows-ci.39391134050',
      'v0.9.1-pre.4',
      'v0.3.0-new',
      'v0.3.0-fix',
      '0.3.0',
      '',
    ];
    for (final tag in rejected) {
      expect(
        isAndroidReleaseCompatible(release(tag), 'com.bfclash.client'),
        isFalse,
        reason: tag,
      );
    }
  });

  test('Windows 主线（1.x）对 Android 永不可见', () {
    expect(
      isAndroidReleaseCompatible(release('v1.0.0'), 'com.bfclash.client'),
      isFalse,
    );
  });

  test('没有 apk 资产的 release 不可见', () {
    expect(
      isAndroidReleaseCompatible(
        release('v0.3.0', apk: false),
        'com.bfclash.client',
      ),
      isFalse,
    );
  });
}
