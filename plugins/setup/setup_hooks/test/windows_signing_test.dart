import 'dart:io';
import 'dart:ffi';

import 'package:path/path.dart' as p;
import 'package:setup_hooks/src/build.dart';
import 'package:setup_hooks/src/error.dart';
import 'package:setup_hooks/src/target.dart';
import 'package:setup_hooks/src/util.dart';
import 'package:setup_hooks/src/windows_signing.dart';
import 'package:test/test.dart';

class _FixtureSigner implements WindowsSigningBackend {
  String profile = 'first';
  bool reject = false;
  final events = <String>[];

  @override
  List<String> get inputs => const [];
  @override
  Map<String, String> get identity => {'fixture-profile': profile};
  @override
  Future<void> sign(String file) async {
    events.add('sign:${p.basename(file).split('.').first}');
    if (reject) throw BuildException('fixture signing rejected');
    await File(
      file,
    ).writeAsString('\nfixture-overlay-$profile', mode: FileMode.append);
  }

  @override
  Future<void> verify(String file) async {
    events.add('verify:${p.basename(file)}');
    final bytes = await File(file).readAsBytes();
    expect(
      String.fromCharCodes(
        bytes.skip(bytes.length - '\nfixture-overlay-$profile'.length),
      ),
      '\nfixture-overlay-$profile',
    );
  }
}

void main() {
  test('requested signing cannot silently fall back without configuration', () {
    expect(
      () => WindowsBinarySigner.load(
        rootDir: '.',
        goos: 'windows',
        environment: {'BFCLASH_WINDOWS_SIGNING_REQUIRED': 'true'},
      ),
      throwsA(isA<BuildException>()),
    );
    expect(
      WindowsBinarySigner.load(rootDir: '.', goos: 'windows', environment: {}),
      isNull,
    );
    expect(
      WindowsBinarySigner.load(
        rootDir: '.',
        goos: 'android',
        environment: {'BFCLASH_WINDOWS_SIGNING_REQUIRED': 'true'},
      ),
      isNull,
    );
  });

  test('malformed signing requirement cannot produce unsigned output', () {
    for (final value in ['', 'TRUE', '1']) {
      expect(
        () => WindowsBinarySigner.load(
          rootDir: '.',
          goos: 'windows',
          environment: {'BFCLASH_WINDOWS_SIGNING_REQUIRED': value},
        ),
        throwsA(isA<BuildException>()),
      );
    }
  });

  test(
    'real fixture builders embed signed Core hash and cache signed bytes',
    () async {
      final root = Directory.systemTemp.createTempSync('bf-signing-order-');
      addTearDown(() => root.deleteSync(recursive: true));
      final coreDir = Directory(p.join(root.path, 'core'))..createSync();
      File(
        p.join(coreDir.path, 'go.mod'),
      ).writeAsStringSync('module fixture\n\ngo 1.26.0\n');
      File(
        p.join(coreDir.path, 'main.go'),
      ).writeAsStringSync('package main\nfunc main() {}\n');
      final helperDir = Directory(p.join(root.path, 'services', 'helper'))
        ..createSync(recursive: true);
      Directory(p.join(helperDir.path, 'src')).createSync();
      File(p.join(helperDir.path, 'Cargo.toml')).writeAsStringSync(
        '[package]\nname="helper"\nversion="0.1.0"\nedition="2021"\n',
      );
      File(p.join(helperDir.path, 'Cargo.lock')).writeAsStringSync(
        'version = 4\n\n[[package]]\nname = "helper"\nversion = "0.1.0"\n',
      );
      File(p.join(helperDir.path, 'src', 'main.rs')).writeAsStringSync(
        'fn main() { println!("{}", env!("CORE_SHA256")); }\n',
      );
      runCommand('cargo', [
        'generate-lockfile',
        '--offline',
      ], workingDirectory: helperDir.path);
      final target = Abi.current() == Abi.linuxArm64
          ? Target.linuxArm64
          : Target.linuxAmd64;
      final signer = _FixtureSigner();
      final request = BuildRequest(
        rootDir: root.path,
        target: target,
        signer: signer,
      );
      final core = p.join(root.path, 'libclash', 'linux', 'BfClashCore');
      final helper = p.join(
        root.path,
        'libclash',
        'linux',
        'BfClashHelperService',
      );
      expect((await buildPlatform(request)).rebuilt, isTrue);
      final firstHash = await calcSha256(core);
      expect(
        (await Process.run(helper, [])).stdout.toString().trim(),
        firstHash,
      );
      expect(signer.events, [
        'sign:BfClashCore',
        'verify:BfClashCore',
        'sign:BfClashHelperService',
        'verify:BfClashHelperService',
      ]);
      signer.events.clear();
      expect((await buildPlatform(request)).rebuilt, isFalse);
      expect(signer.events, [
        'verify:BfClashCore',
        'verify:BfClashHelperService',
      ]);
      signer.profile = 'replacement';
      expect((await buildPlatform(request)).rebuilt, isTrue);
      final replacementHash = await calcSha256(core);
      expect(replacementHash, isNot(firstHash));
      expect(
        (await Process.run(helper, [])).stdout.toString().trim(),
        replacementHash,
      );
      final previousHelper = await calcSha256(helper);
      signer.profile = 'rejected';
      signer.reject = true;
      await expectLater(buildPlatform(request), throwsA(isA<BuildException>()));
      expect(await calcSha256(core), replacementHash);
      expect(await calcSha256(helper), previousHelper);
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: !Platform.isLinux,
  );
}
