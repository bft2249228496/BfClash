import 'dart:io';

import 'package:test/test.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart', () {
    test('signing hook configuration changes with mode and file content', () {
      final root = Directory.systemTemp.createTempSync('bf_signing_defines_');
      addTearDown(() => root.deleteSync(recursive: true));
      Directory('${root.path}/tool').createSync();
      final script = File('${root.path}/tool/sign_windows_binary.ps1')
        ..writeAsStringSync('script');
      final tool = File('${root.path}/signtool.exe')..writeAsStringSync('tool');
      final dlib = File('${root.path}/client.dll')..writeAsStringSync('client');
      final metadata = File('${root.path}/metadata.json')
        ..writeAsStringSync('profile A');
      final env = <String, String>{
        'BFCLASH_WINDOWS_SIGNING_REQUIRED': 'true',
        'BFCLASH_SIGNTOOL': tool.path,
        'BFCLASH_SIGNING_DLIB': dlib.path,
        'BFCLASH_SIGNING_METADATA': metadata.path,
        'BFCLASH_SIGNER_SUBJECT': 'CN=Fixture',
      };
      expect(setup.createWindowsSigningDefines(root.path, {}), isEmpty);
      expect(
        () => setup.createWindowsSigningDefines(root.path, {
          'BFCLASH_WINDOWS_SIGNING_REQUIRED': 'TRUE',
        }),
        throwsStateError,
      );
      expect(
        () => setup.createWindowsSigningDefines(root.path, {
          'BFCLASH_WINDOWS_SIGNING_REQUIRED': 'true',
        }),
        throwsStateError,
      );
      final first = setup.createWindowsSigningDefines(root.path, env);
      metadata.writeAsStringSync('profile B');
      final second = setup.createWindowsSigningDefines(root.path, env);
      expect(second['input_3'], isNot(first['input_3']));
      script.writeAsStringSync('script changed');
      expect(
        setup.createWindowsSigningDefines(root.path, env)['input_0'],
        isNot(first['input_0']),
      );
    });
    test('Windows builds and retries get distinct app and file versions', () {
      expect(
        setup.createWindowsBuildVersion('0.2.27+55', runNumber: 27, beta: true),
        '0.2.27-beta.1271+1271',
      );
      expect(
        setup.createWindowsBuildVersion('0.2.27+55', runNumber: 28, beta: true),
        '0.2.27-beta.1281+1281',
      );
      expect(
        setup.createWindowsBuildVersion(
          '0.2.27+55',
          runNumber: 28,
          runAttempt: 2,
          beta: true,
        ),
        '0.2.27-beta.1282+1282',
      );
      expect(
        setup.createWindowsBuildVersion(
          '0.2.27+55',
          runNumber: 28,
          beta: false,
        ),
        '0.2.27+1281',
      );
    });
    test('rejects invalid or overflowing Windows build identities', () {
      expect(
        () =>
            setup.createWindowsBuildVersion('0.2.27', runNumber: 0, beta: true),
        throwsArgumentError,
      );
      expect(
        () => setup.createWindowsBuildVersion(
          '0.2.27',
          runNumber: 10000,
          beta: true,
        ),
        throwsArgumentError,
      );
    });

    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
    });

    test('accepts dev application environment', () {
      final results = setup.createSetupArgParser().parse([
        'android',
        '--env',
        'dev',
      ]);

      expect(results['env'], 'dev');
    });

    test('Flutter build environment does not depend on Core SHA256', () {
      expect(setup.createBuildEnvironment('dev'), {
        'APP_ENV': 'dev',
        'APP_BETA': 'true',
        'WINDOWS_CI_RUN_ID': Platform.environment['GITHUB_RUN_ID'] ?? '',
      });
    });

    test('omits verbose from flutter build args by default', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json', 'split-per-abi']);
    });

    test('adds verbose to flutter build args with -v', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: true,
      );

      expect(args, [
        'verbose',
        'dart-define-from-file=env.json',
        'split-per-abi',
      ]);
    });

    test('refuses to package while a native build hook is skipped', () {
      const pubspec = '''
hooks:
  user_defines:
    setup:
      build_assets: false
    rust_api:
      build_assets: true
''';

      expect(setup.packagesNotBuildingAssets(pubspec), ['setup']);
      expect(setup.packagesNotBuildingAssets('name: x\n'), isEmpty);
    });

    test('packages every Linux format on every architecture', () {
      expect(setup.createPackageTargets('linux', null), 'deb,appimage,rpm');
      expect(setup.createPackageTargets('linux', 'deb'), 'deb');
      expect(setup.createPackageTargets('macos', null), 'dmg');
    });

    test('downloads the appimagetool build matching the host', () {
      expect(setup.appImageToolArch('arm64'), 'aarch64');
      expect(setup.appImageToolArch('amd64'), 'x86_64');
    });
  });
}
