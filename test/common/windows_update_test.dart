import 'package:bfclash/common/windows_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> release(
    String tag, {
    String arch = 'amd64',
    bool beta = true,
    bool installer = true,
    bool draft = false,
  }) => {
    'tag_name': tag,
    'prerelease': beta,
    'draft': draft,
    'assets': [
      if (installer)
        {
          'name': 'BfClash-0.2.27-windows-$arch-beta-setup.exe',
          'browser_download_url':
              'https://github.com/example/release/setup.exe',
        },
    ],
  };

  Map<String, dynamic>? select(
    List<dynamic> releases, {
    String run = '100',
    String arch = 'AMD64',
  }) => selectWindowsBetaRelease(
    releases,
    currentVersion: '0.2.27+55',
    currentRunId: run,
    architecture: arch,
  );

  test(
    'same base version uses numeric CI identity rather than package build',
    () {
      final next = release('v0.2.27-windows-ci.101');
      expect(
        select([
          release('v0.2.27-windows-ci.99'),
          release('v0.2.27-windows-ci.100'),
          next,
        ]),
        same(next),
      );
    },
  );

  test('selects latest compatible installer from unordered mixed releases', () {
    final next = release('v0.2.27-windows-ci.120');
    expect(
      select([
        next,
        release('v0.2.27-beta.200'),
        release('v0.2.27-windows-ci.130', arch: 'arm64'),
        release('v0.2.27-windows-ci.140', installer: false),
        release('v0.2.27-windows-ci.150', draft: true),
        release('v0.2.27-windows-ci.160', beta: false),
        release('v0.2.26-windows-ci.999'),
        release('v0.2.27-windows-ci.110'),
      ]),
      same(next),
    );
  });

  test('new base version wins even if CI numbering is lower', () {
    final next = release('v0.2.28-windows-ci.1');
    expect(select([release('v0.2.27-windows-ci.200'), next]), same(next));
  });

  test('unknown build identity reports failure rather than no update', () {
    final releases = [release('v0.2.27-windows-ci.200')];
    for (final run in ['', 'unknown', '0', '-1']) {
      expect(
        () => select(releases, run: run),
        throwsA(isA<WindowsUpdateIdentityException>()),
      );
    }
    expect(select([]), isNull);
  });

  test('unsupported architecture reports failure rather than no update', () {
    expect(
      () => select([release('v0.2.27-windows-ci.200')], arch: 'x86'),
      throwsA(isA<WindowsUpdateIdentityException>()),
    );
  });

  test('ARM64 cannot receive the AMD64 installer', () {
    final next = release('v0.2.27-windows-ci.101', arch: 'arm64');
    expect(
      select([release('v0.2.27-windows-ci.102'), next], arch: 'ARM64'),
      same(next),
    );
  });
}
