import 'package:bfclash/common/windows_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> release(
    String tag, {
    String arch = 'amd64',
    bool beta = true,
    bool installer = true,
    bool draft = false,
  }) {
    final version = tag.replaceFirst(RegExp(r'^[vV]'), '');
    // 历史产物名是 `BfClash-<版本>-windows-<架构>-beta-setup.exe`，
    // 新格式是 `BfClash-<版本>-windows-<架构>-setup.exe`，两者都必须能被识别。
    final assetName = version.contains('windows-ci')
        ? 'BfClash-${version.split('-').first}-windows-$arch-beta-setup.exe'
        : 'BfClash-$version-windows-$arch-setup.exe';
    return {
      'tag_name': tag,
      'prerelease': beta,
      'draft': draft,
      'assets': [
        if (installer)
          {
            'name': assetName,
            'browser_download_url':
                'https://github.com/example/release/setup.exe',
          },
      ],
    };
  }

  Map<String, dynamic>? select(
    List<dynamic> releases, {
    String run = '100',
    String arch = 'AMD64',
    String version = '1.0.1-beta.100',
  }) => selectWindowsBetaRelease(
    releases,
    currentVersion: version,
    currentRunId: run,
    architecture: arch,
  );

  test('同版本号时按构建号取更高者', () {
    final next = release('v1.0.1-beta.101');
    expect(
      select([release('v1.0.1-beta.99'), release('v1.0.1-beta.100'), next]),
      same(next),
    );
  });

  test('乱序混合列表里挑出最新可用安装包', () {
    final next = release('v1.0.2-beta.120');
    expect(
      select([
        next,
        release('v1.0.2-beta.110'),
        release('v1.0.1-beta.999'), // 基础版本更低，构建号更大也不能赢
        release('v1.0.2-beta.130', arch: 'arm64'),
        release('v1.0.2-beta.140', installer: false),
        release('v1.0.2-beta.150', draft: true),
        release('v1.0.2-beta.160', beta: false),
        release('v0.2.27-windows-ci.999'), // 历史 tag 格式仍须被识别
      ]),
      same(next),
    );
  });

  test('更高的基础版本优先于构建号', () {
    final next = release('v1.1.0-beta.1');
    expect(select([release('v1.0.1-beta.200'), next]), same(next));
  });

  test('历史 windows-ci tag 与新版 beta tag 可同时解析', () {
    final legacy = release('v1.0.1-windows-ci.101');
    expect(select([release('v1.0.1-windows-ci.99'), legacy]), same(legacy));
    expect(
      select([
        release('v1.0.1-windows-ci.101'),
        release('v1.0.1-beta.102'),
      ])?['tag_name'],
      'v1.0.1-beta.102',
    );
  });

  test('构建身份缺失时报错而不是当作无更新', () {
    final releases = [release('v1.0.1-beta.200')];
    for (final run in ['', 'unknown', '0', '-1']) {
      expect(
        () => select(releases, run: run),
        throwsA(isA<WindowsUpdateIdentityException>()),
      );
    }
    expect(select([]), isNull);
  });

  test('不支持的架构报错而不是当作无更新', () {
    expect(
      () => select([release('v1.0.1-beta.200')], arch: 'x86'),
      throwsA(isA<WindowsUpdateIdentityException>()),
    );
  });

  test('ARM64 拿不到 AMD64 的安装包', () {
    final next = release('v1.0.2-beta.101', arch: 'arm64');
    expect(
      select([release('v1.0.2-beta.102'), next], arch: 'ARM64'),
      same(next),
    );
  });

  test('1.x beta 安装包能发现更新的 beta 构建', () {
    // 真实安装态：版本号 1.0.0-beta.1871，烤进包里的是 GitHub run id。
    // 构建号 1881 必须能和 1871 比较，而不是和 39 亿的 run id 比较。
    final next = release('v1.0.0-beta.1881');
    expect(
      select(
        [release('v1.0.0-beta.1871'), next],
        version: '1.0.0-beta.1871',
        run: '39455481933',
      ),
      same(next),
    );
  });

  test('1.x beta 不会把自身当作更新', () {
    expect(
      select(
        [release('v1.0.0-beta.1871')],
        version: '1.0.0-beta.1871',
        run: '39455481933',
      ),
      isNull,
    );
  });

  test('0.x 历史安装仍按 run id 比较', () {
    // 0.x 时代 tag 里是 github run id，不能拿 build 号去比；
    // 比当前 run id 小的历史构建不算更新。
    expect(
      select(
        [release('v0.2.27-windows-ci.39360628444')],
        version: '0.2.27-beta.1861',
        run: '39391134050',
      ),
      isNull,
    );
    final newer = release('v0.2.27-windows-ci.39400000000');
    expect(
      select(
        [release('v0.2.27-windows-ci.39391134050'), newer],
        version: '0.2.27-beta.1861',
        run: '39391134050',
      ),
      same(newer),
    );
  });
}
