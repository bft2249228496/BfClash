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
    expect(rc.channel, ReleaseChannel.beta, reason: 'rc 属于测试通道');
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
