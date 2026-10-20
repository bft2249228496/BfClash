import 'package:bfclash/common/package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('解析合规 tag', () {
    final stable = ReleaseTag.tryParse('v0.3.0')!;
    expect(stable.version, '0.3.0');
    expect(stable.major, androidReleaseMajor);
    expect(stable.channel, ReleaseChannel.stable);

    final beta = ReleaseTag.tryParse('v1.0.1-beta.1861')!;
    expect(beta.version, '1.0.1-beta.1861');
    expect(beta.major, windowsReleaseMajor);
    expect(beta.channel, ReleaseChannel.beta);
    expect(beta.info.preReleaseNum, 1861);

    final rc = ReleaseTag.tryParse('v0.3.0-rc.2')!;
    expect(rc.channel, ReleaseChannel.rc, reason: 'rc 是正式版候选，不是 beta');
    expect(rc.isBeta, isFalse);
  });

  test('设备通道由已安装版本号判定', () {
    expect(channelOfVersion('0.3.0'), ReleaseChannel.stable);
    expect(channelOfVersion('0.2.29-rc.3'), ReleaseChannel.rc);
    expect(channelOfVersion('0.2.29-beta.3'), ReleaseChannel.beta);
    expect(channelOfVersion('0.3.1-rc.1'), ReleaseChannel.rc);
  });

  test('rc 能收到正式版，beta 只收 beta', () {
    expect(
      acceptedChannelsFor(ReleaseChannel.rc),
      contains(ReleaseChannel.stable),
      reason: 'rc 的终点就是同号正式版，必须能升级过去',
    );
    expect(acceptedChannelsFor(ReleaseChannel.rc), contains(ReleaseChannel.rc));
    expect(
      acceptedChannelsFor(ReleaseChannel.beta),
      unorderedEquals([ReleaseChannel.beta]),
      reason: '测试通道不接收正式版，避免测试构建被静默替换',
    );
    expect(
      acceptedChannelsFor(ReleaseChannel.stable),
      unorderedEquals([ReleaseChannel.stable]),
      reason: '正式版不接收任何预发布构建',
    );
  });

  test('大小写 v 前缀都可解析', () {
    expect(ReleaseTag.tryParse('V0.3.0')?.version, '0.3.0');
  });

  test('拒绝所有历史与自造格式', () {
    const rejected = [
      'v0.2.27-windows-ci.39391134050',
      'v0.9.1-pre.4',
      'v0.3.0-new',
      'v0.3.0-alpha.1',
      'v0.3.0-beta1',
      '0.3.0',
      'v0.3',
      'v0.3.0.1',
      'release-0.3.0',
      '',
    ];
    for (final tag in rejected) {
      expect(ReleaseTag.tryParse(tag), isNull, reason: tag);
    }
  });

  test('预发布版本号永远小于同号正式版', () {
    expect(compareVersions('0.3.0', '0.3.0-rc.3'), greaterThan(0));
    expect(compareVersions('0.3.0-beta.2', '0.3.0-beta.10'), lessThan(0));
    expect(compareVersions('1.0.0', '0.3.9'), greaterThan(0));
  });
}
