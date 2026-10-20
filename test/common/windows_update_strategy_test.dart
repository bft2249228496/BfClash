import 'package:bfclash/common/windows_update.dart';
import 'package:bfclash/common/windows_update_policy.dart';
import 'package:flutter_test/flutter_test.dart';

const digest =
    'sha256:86121d47e5ef74f41be547714fe81e96f07cc286a66f14f81aa195c7b9733f4a';

Map<String, dynamic> release({
  String version = '0.2.27-beta.1811',
  String arch = 'amd64',
  bool beta = true,
  bool draft = false,
  bool zip = true,
  bool setup = true,
  String zipDigest = digest,
  String zipHost = 'github.com',
}) => {
  'tag_name': 'v0.2.27-windows-ci.39282292143',
  'prerelease': beta,
  'draft': draft,
  'assets': [
    if (setup)
      {
        'name': 'BfClash-$version-windows-$arch-setup.exe',
        'browser_download_url':
            'https://github.com/example/releases/download/v1/setup.exe',
        'size': 61502298,
        'digest': digest,
      },
    if (zip)
      {
        'name': 'BfClash-$version-windows-$arch.zip',
        'browser_download_url':
            'https://$zipHost/example/releases/download/v1/BfClash.zip',
        'size': 99800763,
        'digest': zipDigest,
      },
  ],
};

void main() {
  group('portable asset selection', () {
    test('picks the versioned zip next to the installer', () {
      final asset = selectWindowsPortableUpdateAsset(
        release(),
        beta: true,
        architecture: 'AMD64',
      );
      expect(asset, isNotNull);
      expect(asset!.size, 99800763);
      expect(asset.url, endsWith('BfClash.zip'));
      expect(asset.packagedVersion, '0.2.27-beta.1811');
    });

    test('installer selection still returns the setup executable', () {
      final asset = selectWindowsUpdateAsset(
        release(),
        beta: true,
        architecture: 'AMD64',
      );
      expect(asset, isNotNull);
      expect(asset!.url, endsWith('setup.exe'));
      expect(asset.packagedVersion, '0.2.27-beta.1811');
    });

    test('portable archive is unavailable without a matching zip', () {
      expect(
        selectWindowsPortableUpdateAsset(
          release(zip: false),
          beta: true,
          architecture: 'AMD64',
        ),
        isNull,
      );
      expect(
        selectWindowsPortableUpdateAsset(
          release(),
          beta: false,
          architecture: 'AMD64',
        ),
        isNull,
      );
      expect(
        selectWindowsPortableUpdateAsset(
          release(),
          beta: true,
          architecture: 'ARM64',
        ),
        isNull,
      );
      expect(
        selectWindowsPortableUpdateAsset(
          release(draft: true),
          beta: true,
          architecture: 'AMD64',
        ),
        isNull,
      );
    });

    test('portable archive must be a verified github download', () {
      expect(
        selectWindowsPortableUpdateAsset(
          release(zipDigest: ''),
          beta: true,
          architecture: 'AMD64',
        ),
        isNull,
      );
      expect(
        selectWindowsPortableUpdateAsset(
          release(zipHost: 'example.com'),
          beta: true,
          architecture: 'AMD64',
        ),
        isNull,
      );
    });

    test('a stable release only accepts the unversioned zip', () {
      expect(
        selectWindowsPortableUpdateAsset(
          release(version: '0.2.27', beta: false),
          beta: false,
          architecture: 'AMD64',
        )?.packagedVersion,
        '0.2.27',
      );
      expect(
        selectWindowsPortableUpdateAsset(
          release(version: '0.2.27-beta.1811', beta: false),
          beta: false,
          architecture: 'AMD64',
        ),
        isNull,
      );
    });
  });

  group('update strategy', () {
    test('installer is used while application control is inactive', () {
      for (final state in [null, 0, 2]) {
        expect(
          windowsUpdateStrategy(policyStateReader: () => state),
          WindowsUpdateStrategy.installer,
        );
      }
    });

    test('portable overwrite is used when control is enforced or unknown', () {
      expect(
        windowsUpdateStrategy(policyStateReader: () => 1),
        WindowsUpdateStrategy.portableOverwrite,
      );
      expect(
        windowsUpdateStrategy(policyStateReader: () => 7),
        WindowsUpdateStrategy.portableOverwrite,
      );
      expect(
        windowsUpdateStrategy(policyStateReader: () => throw StateError('x')),
        WindowsUpdateStrategy.portableOverwrite,
      );
    });

    test('fixed strategy short-circuits the registry probe', () {
      expect(
        windowsUpdateStrategy(
          policyStateReader: () => throw StateError('must not read'),
          fixedPortable: false,
        ),
        WindowsUpdateStrategy.installer,
      );
      expect(
        windowsUpdateStrategy(
          policyStateReader: () => throw StateError('must not read'),
          fixedPortable: true,
        ),
        WindowsUpdateStrategy.portableOverwrite,
      );
    });
  });
}
