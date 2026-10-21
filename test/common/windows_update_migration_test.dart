import 'dart:convert';
import 'dart:io';

import 'package:bfclash/common/windows_update.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/windows_update_1871.dart';

void main() {
  Map<String, dynamic> release(String version) => {
    'tag_name': 'v$version',
    'prerelease': true,
    'draft': false,
    'assets': [
      for (final suffix in ['-setup.exe', '.zip'])
        {
          'name': 'BfClash-$version-windows-amd64$suffix',
          'browser_download_url':
              'https://github.com/bft2249228496/BfClash/releases/download/v$version/BfClash-$version-windows-amd64$suffix',
          'size': 100,
          'digest': 'sha256:${'a' * 64}',
        },
    ],
  };

  Map<String, dynamic>? installedSelect(List<dynamic> releases) =>
      selectInstalled1871Release(
        releases,
        currentVersion: '1.0.0-beta.1871',
        currentRunId: '39455481933',
        architecture: 'AMD64',
      );

  test('shipped 1871 cannot discover the same-base 1891 repair', () {
    expect(installedSelect([release('1.0.0-beta.1891')]), isNull);
  });

  test('shipped 1871 discovers the 1.0.1 bridge and both update assets', () {
    final bridge = release('1.0.1-beta.1901');
    final selected = installedSelect([release('1.0.0-beta.1891'), bridge]);
    expect(selected, same(bridge));
    final installer = selectWindowsUpdateAsset(
      selected!,
      beta: true,
      architecture: 'AMD64',
    );
    final portable = selectWindowsPortableUpdateAsset(
      selected,
      beta: true,
      architecture: 'AMD64',
    );
    expect(installer, isNotNull);
    expect(portable?.packagedVersion, '1.0.1-beta.1901');
  });

  test('bridge discovers subsequent same-base builds using build numbers', () {
    final next = release('1.0.1-beta.1911');
    expect(
      selectWindowsBetaRelease(
        [release('1.0.0-beta.1891'), release('1.0.1-beta.1901'), next],
        currentVersion: '1.0.1-beta.1901',
        currentRunId: '39530000000',
        architecture: 'AMD64',
      ),
      same(next),
    );
    expect(
      selectWindowsBetaRelease(
        [release('1.0.1-beta.1901')],
        currentVersion: '1.0.1-beta.1901',
        currentRunId: '39530000000',
        architecture: 'AMD64',
      ),
      isNull,
    );
  });

  const releaseFile = String.fromEnvironment('WINDOWS_UPDATE_RELEASE_FILE');
  if (releaseFile.isNotEmpty) {
    test('published bridge is installable by the shipped 1871 selector', () {
      final published =
          jsonDecode(File(releaseFile).readAsStringSync())
              as Map<String, dynamic>;
      expect(published['draft'], isFalse);
      expect(published['prerelease'], isTrue);
      expect(installedSelect([published]), same(published));
      for (final current in ['1.0.0-beta.1871', '1.0.0-beta.1891']) {
        expect(
          selectWindowsBetaRelease(
            [published],
            currentVersion: current,
            currentRunId: '39455481933',
            architecture: 'AMD64',
          ),
          same(published),
        );
      }
      final installer = selectWindowsUpdateAsset(
        published,
        beta: true,
        architecture: 'AMD64',
      );
      final portable = selectWindowsPortableUpdateAsset(
        published,
        beta: true,
        architecture: 'AMD64',
      );
      expect(installer, isNotNull);
      expect(portable, isNotNull);
      expect(portable!.packagedVersion, published['tag_name'].substring(1));
      expect(
        selectWindowsBetaRelease(
          [published],
          currentVersion: portable.packagedVersion,
          currentRunId: '39530000000',
          architecture: 'AMD64',
        ),
        isNull,
      );
    });
  }
}
