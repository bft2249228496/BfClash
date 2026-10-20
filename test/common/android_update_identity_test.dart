import 'package:bfclash/common/package.dart';
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

  test('beta 通道只接受 Beta 包名', () {
    for (final tag in ['v0.3.1-beta.1', 'v0.2.29-beta.3']) {
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

  test('rc 用正式包名：正式版必须能覆盖安装它', () {
    for (final tag in ['v0.3.0-rc.1', 'v0.3.1-rc.2']) {
      expect(
        isAndroidReleaseCompatible(release(tag), 'com.bfclash.client'),
        isTrue,
        reason: '$tag 必须落在正式包名上，否则正式版装不上去',
      );
      expect(
        isAndroidReleaseCompatible(release(tag), 'com.lansway.client.beta'),
        isFalse,
        reason: '$tag 不是测试通道构建',
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

  test('未安装渠道对应的包名不接受任何通道的更新', () {
    for (final tag in ['v0.3.0', 'v0.3.1-beta.1', 'v0.3.0-rc.1']) {
      expect(
        isAndroidReleaseCompatible(release(tag), 'com.example.other'),
        isFalse,
        reason: tag,
      );
    }
  });

  /// 把「通道可见性 + 安装身份 + 版本比较」三关串起来验证，
  /// 这正是 checkForUpdate 判定一次更新是否可见的完整路径。
  bool visible(String tag, String installedVersion, String packageName) {
    final parsed = ReleaseTag.tryParse(tag);
    if (parsed == null) return false;
    return acceptedChannelsFor(
          channelOfVersion(installedVersion),
        ).contains(parsed.channel) &&
        isAndroidReleaseCompatible(release(tag), packageName) &&
        compareVersions(parsed.version, installedVersion) > 0;
  }

  test('rc 能升级到同号正式版', () {
    expect(
      visible('v0.3.1', '0.3.1-rc.1', 'com.bfclash.client'),
      isTrue,
      reason: 'rc 的终点就是同号正式版，否则候选版是死胡同',
    );
    expect(
      visible('v0.3.2-rc.1', '0.3.1-rc.1', 'com.bfclash.client'),
      isTrue,
      reason: 'rc 也能收到更新的 rc',
    );
    expect(
      visible('v0.3.0-rc.2', '0.3.1-rc.1', 'com.bfclash.client'),
      isFalse,
      reason: '更旧的 rc 不该当成更新',
    );
    expect(
      visible('v0.3.1-beta.1', '0.3.1-rc.1', 'com.bfclash.client'),
      isFalse,
      reason: 'rc 用户不该被拉回 beta 通道',
    );
  });

  test('正式版与 beta 用户都收不到 rc', () {
    expect(visible('v0.3.2-rc.1', '0.3.1', 'com.bfclash.client'), isFalse);
    expect(
      visible('v0.3.2-rc.1', '0.3.1-beta.1', 'com.lansway.client.beta'),
      isFalse,
    );
  });
}
