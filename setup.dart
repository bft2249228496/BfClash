import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'tool/windows_signed_package.dart';

const _allTargets = <String, String>{
  'android': 'apk',
  'linux': 'deb,appimage,rpm',
  'macos': 'dmg',
  'windows': 'exe,zip',
};

const _androidFlutterTarget = {
  'arm': 'android-arm',
  'arm64': 'android-arm64',
  'amd64': 'android-x64',
};

const _hostPlatform = {
  'linux': 'linux',
  'macos': 'macos',
  'windows': 'windows',
};

Future<void> main(List<String> args) async {
  final parser = createSetupArgParser();

  if (args.contains('--help') || args.contains('-h')) {
    _showHelp(parser);
    exit(0);
  }

  final results = parser.parse(args);
  final rest = results.rest;

  final hostOs = Platform.operatingSystem;
  final host = _hostPlatform[hostOs];
  if (host == null) {
    stderr.writeln('Unsupported host platform: $hostOs');
    exit(1);
  }

  final platform = rest.isNotEmpty ? rest.first : host;

  if (platform != host && platform != 'android') {
    stderr.writeln(
      'Cannot build "$platform" on $hostOs. Allowed: $host, android',
    );
    _showHelp(parser);
    exit(1);
  }

  final env = results['env'] as String;
  final rootDir = Directory.current.path;
  final skipped = packagesNotBuildingAssets(
    File(p.join(rootDir, 'pubspec.yaml')).readAsStringSync(),
  );
  if (skipped.isNotEmpty) {
    stderr.writeln(
      'pubspec.yaml sets hooks.user_defines.<package>.build_assets: false '
      'for ${skipped.join(', ')}; a package built this way would ship '
      'whatever is left in libclash/ and no Rust library. '
      'Restore "build_assets: true".',
    );
    exit(1);
  }
  final arch = _detectArch();
  final targets = createPackageTargets(platform, results['targets']);
  final androidArch = results['arch'] as String?;
  final verbose = results['verbose'] as bool;

  final pubspecFile = File(p.join(rootDir, 'pubspec.yaml'));
  final originalPubspec = await pubspecFile.readAsString();
  final runNumber = int.tryParse(
    Platform.environment['GITHUB_RUN_NUMBER'] ?? '',
  );
  var result = 1;
  var stampedVersion = false;
  try {
    if (platform == 'windows' && runNumber != null) {
      final document = loadYaml(originalPubspec) as YamlMap;
      final buildVersion = createWindowsBuildVersion(
        document['version'] as String,
        runNumber: runNumber,
        runAttempt: int.parse(
          Platform.environment['GITHUB_RUN_ATTEMPT'] ?? '1',
        ),
        beta: env != 'stable',
      );
      stampedVersion = true;
      await pubspecFile.writeAsString(
        originalPubspec.replaceFirst(
          RegExp(r'^version:.*$', multiLine: true),
          'version: $buildVersion',
        ),
      );
      stdout.writeln('Windows package version: $buildVersion');
    }
    if (platform == 'windows') {
      final signing = {
        ...createWindowsSigningDefines(rootDir, Platform.environment),
        'BFCLASH_BUILD_ENVIRONMENT': env,
      };
      final current = await pubspecFile.readAsString();
      final line = '      windows_signing: ${jsonEncode(signing)}';
      final pattern = RegExp(r'^      windows_signing:.*$', multiLine: true);
      stampedVersion = true;
      await pubspecFile.writeAsString(
        pattern.hasMatch(current)
            ? current.replaceFirst(pattern, line)
            : current.replaceFirst('    setup:\n', '    setup:\n$line\n'),
      );
    }
    result = await _package(
      platform,
      env,
      targets,
      rootDir,
      arch,
      androidArch: androidArch,
      verbose: verbose,
    );
  } finally {
    if (stampedVersion) await pubspecFile.writeAsString(originalPubspec);
  }
  exit(result);
}

/// Public signing configuration is a hook input, so mode/profile/tool changes
/// invalidate Flutter's outer hook cache as well as the Core/Helper cache.
Map<String, String> createWindowsSigningDefines(
  String rootDir,
  Map<String, String> environment,
) {
  final required = environment['BFCLASH_WINDOWS_SIGNING_REQUIRED'];
  if (required == null || required == 'false') return {};
  if (required != 'true') {
    throw StateError('BFCLASH_WINDOWS_SIGNING_REQUIRED must be true or false');
  }
  final result = <String, String>{'BFCLASH_WINDOWS_SIGNING_REQUIRED': 'true'};
  for (final key in [
    'BFCLASH_SIGNTOOL',
    'BFCLASH_SIGNING_DLIB',
    'BFCLASH_SIGNING_METADATA',
    'BFCLASH_SIGNER_SUBJECT',
  ]) {
    final value = environment[key];
    if (value == null || value.trim().isEmpty) {
      throw StateError('Missing signing configuration: $key');
    }
    result[key] = value;
  }
  final inputs = [
    p.join(rootDir, 'tool', 'sign_windows_binary.ps1'),
    result['BFCLASH_SIGNTOOL']!,
    result['BFCLASH_SIGNING_DLIB']!,
    result['BFCLASH_SIGNING_METADATA']!,
  ];
  for (var index = 0; index < inputs.length; index++) {
    result['input_$index'] = sha256
        .convert(File(inputs[index]).readAsBytesSync())
        .toString();
  }
  return result;
}

String createWindowsBuildVersion(
  String sourceVersion, {
  required int runNumber,
  int runAttempt = 1,
  required bool beta,
}) {
  final match = RegExp(r'^(\d+\.\d+\.\d+)').firstMatch(sourceVersion);
  if (match == null || runNumber < 1 || runAttempt < 1 || runAttempt > 9) {
    throw ArgumentError('Invalid Windows build identity');
  }
  final build = 1000 + runNumber * 10 + runAttempt;
  if (build > 65535) throw ArgumentError('Windows build number exceeds 65535');
  final base = match.group(1)!;
  return beta ? '$base-beta.$build+$build' : '$base+$build';
}

ArgParser createSetupArgParser() {
  return ArgParser()
    ..addOption(
      'env',
      defaultsTo: 'pre',
      allowed: ['dev', 'pre', 'stable'],
      help: 'Application environment',
    )
    ..addOption(
      'targets',
      valueHelp: 'exe,zip,dmg,apk,...',
      help: 'Package targets (default: all for platform)',
    )
    ..addOption(
      'arch',
      valueHelp: 'arm,arm64,amd64',
      allowed: ['arm', 'arm64', 'amd64'],
      help: 'Target architecture (Android only)',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose Flutter build output',
    );
}

List<String> createFlutterBuildArgs({
  required String platform,
  required bool verbose,
}) {
  final flutterBuildArgs = <String>[
    if (verbose) 'verbose',
    'dart-define-from-file=env.json',
  ];
  if (platform == 'android') {
    flutterBuildArgs.add('split-per-abi');
  }
  return flutterBuildArgs;
}

Map<String, String> createBuildEnvironment(String env) {
  return {
    'APP_ENV': env,
    'APP_BETA': env == 'pre' || env == 'dev' ? 'true' : 'false',
    'WINDOWS_CI_RUN_ID': Platform.environment['GITHUB_RUN_ID'] ?? '',
  };
}

/// Packages whose build hook `pubspec.yaml` turns into a no-op.
List<String> packagesNotBuildingAssets(String pubspec) {
  final document = loadYaml(pubspec);
  if (document is! Map) return const [];
  final defines = (document['hooks'] as Map?)?['user_defines'];
  if (defines is! Map) return const [];
  return [
    for (final MapEntry(:key, :value) in defines.entries)
      if (value is Map && value['build_assets'] == false) key.toString(),
  ]..sort();
}

String createPackageTargets(String platform, String? customTargets) {
  return customTargets ?? _allTargets[platform]!;
}

void _showHelp(ArgParser parser) {
  stderr.writeln('Usage: dart setup.dart [platform] [options]');
  stderr.writeln('Platform: current host platform (default) or android');
  stderr.writeln();
  stderr.writeln('Default package targets:');
  _allTargets.forEach((p, t) => stderr.writeln('  $p: $t'));
  stderr.writeln();
  stderr.writeln(parser.usage);
}

Future<int> _package(
  String platform,
  String env,
  String targets,
  String rootDir,
  String arch, {
  String? androidArch,
  required bool verbose,
}) async {
  final file = File(p.join(rootDir, 'env.json'));
  final buildEnvironment = createBuildEnvironment(env);
  if (platform == 'windows' &&
      Platform.environment['BFCLASH_WINDOWS_SIGNING_REQUIRED'] == 'true') {
    buildEnvironment['WINDOWS_SIGNER_SUBJECT'] =
        Platform.environment['BFCLASH_SIGNER_SUBJECT']!;
  }
  await file.writeAsString(jsonEncode(buildEnvironment));

  final flutterBuildArgs = createFlutterBuildArgs(
    platform: platform,
    verbose: verbose,
  );
  final descriptionArgs = <String>[];
  if (platform != 'android') {
    descriptionArgs.addAll(['--description', arch]);
  }

  final depExit = await _ensureDependencies(platform);
  if (depExit != 0) return depExit;

  if (platform == 'windows' &&
      Platform.environment['BFCLASH_WINDOWS_SIGNING_REQUIRED'] == 'true') {
    return packageSignedWindows(
      rootDir: rootDir,
      arch: arch,
      beta: createBuildEnvironment(env)['APP_BETA'] == 'true',
      targets: targets,
      flutterBuildArgs: flutterBuildArgs,
    );
  }

  final activateResult = await Process.run('dart', [
    'pub',
    'global',
    'activate',
    '-s',
    'git',
    'https://github.com/chen08209/flutter_distributor.git',
    '--git-ref',
    'v0.6.11-flclash.2',
    '--git-path',
    'packages/flutter_distributor',
  ]);
  if (activateResult.exitCode != 0) {
    stderr.write(activateResult.stderr);
    return activateResult.exitCode;
  }

  final process = await Process.start(
    'dart',
    [
      'pub',
      'global',
      'run',
      'flutter_distributor:main',
      'package',
      '--skip-clean',
      '--platform',
      platform,
      '--targets',
      targets,
      if (androidArch != null)
        '--build-target-platform=${_androidFlutterTarget[androidArch]!}',
      if (flutterBuildArgs.isNotEmpty)
        '--flutter-build-args=${flutterBuildArgs.join(',')}',
      ...descriptionArgs,
    ],
    includeParentEnvironment: true,
    environment: {'APP_BETA': createBuildEnvironment(env)['APP_BETA']!},
    runInShell: Platform.isWindows,
  );

  process.stdout.listen((data) {
    stdout.write(utf8.decode(data));
  });
  process.stderr.listen((data) {
    stderr.write(utf8.decode(data));
  });
  final exitCode = await process.exitCode;
  return exitCode;
}

String _detectArch() {
  if (Platform.isWindows) {
    final pa = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'AMD64';
    return pa.toUpperCase() == 'ARM64' ? 'arm64' : 'amd64';
  }
  final result = Process.runSync('uname', ['-m']);
  final machine = (result.stdout as String).trim();
  if (machine == 'aarch64') return 'arm64';
  if (machine == 'x86_64') return 'amd64';
  return machine;
}

Future<bool> _hasCommand(String cmd) async {
  final which = Platform.isWindows ? 'where' : 'command';
  final args = Platform.isWindows ? [cmd] : ['-v', cmd];
  final result = await Process.run(which, args);
  return result.exitCode == 0;
}

Future<int> _ensureDependencies(String platform) async {
  switch (platform) {
    case 'macos':
      return _ensureMacosDependencies();
    case 'linux':
      return _ensureLinuxDependencies();
    default:
      return 0;
  }
}

Future<int> _ensureMacosDependencies() async {
  if (await _hasCommand('appdmg')) {
    stdout.writeln('appdmg already installed, skipping.');
    return 0;
  }
  stdout.writeln('Installing appdmg (DMG creator)...');
  final result = await Process.run('npm', ['install', '-g', 'appdmg']);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
  }
  return result.exitCode;
}

Future<int> _ensureLinuxDependencies() async {
  const pkgGroups = <List<String>>[
    ['ninja-build', 'libgtk-3-dev'],
    ['libayatana-appindicator3-dev'],
    ['libsecret-1-dev'],
    ['locate'],
    ['rpm', 'patchelf'],
    ['libfuse2'],
  ];

  final missingGroups = <List<String>>[];
  for (final group in pkgGroups) {
    final missingPkgs = <String>[];
    for (final pkg in group) {
      if (!await _isDebianPackageInstalled(pkg)) {
        missingPkgs.add(pkg);
      }
    }
    if (missingPkgs.isNotEmpty) {
      missingGroups.add(missingPkgs);
    }
  }

  if (missingGroups.isEmpty) {
    stdout.writeln('All Linux build dependencies already installed, skipping.');
  } else {
    stdout.writeln('Updating apt package lists...');
    final updateExit = await _runLinuxDependencyCommand([
      'apt-get',
      'update',
      '-y',
    ]);
    if (updateExit != 0) {
      stderr.writeln(
        'apt-get update exited with $updateExit; continuing and verifying '
        'dependency installation directly.',
      );
    }

    for (final missingPkgs in missingGroups) {
      stdout.writeln(
        'Installing Linux build dependencies: ${missingPkgs.join(', ')}...',
      );
      final installExit = await _installLinuxPackages(missingPkgs);
      if (installExit != 0) return installExit;
    }
  }

  const appimagetool = '/usr/local/bin/appimagetool';
  if (File(appimagetool).existsSync()) {
    stdout.writeln('appimagetool already installed, skipping.');
    return 0;
  }
  stdout.writeln('Downloading appimagetool...');
  final downloadName =
      'appimagetool-${appImageToolArch(_detectArch())}.AppImage';
  final dlResult = await Process.run('wget', [
    '-O',
    appimagetool,
    'https://github.com/AppImage/AppImageKit/releases/download/continuous/$downloadName',
  ]);
  if (dlResult.exitCode != 0) {
    stderr.write(dlResult.stderr);
    return dlResult.exitCode;
  }
  await Process.run('chmod', ['+x', appimagetool]);
  return 0;
}

String appImageToolArch(String arch) {
  return arch == 'arm64' ? 'aarch64' : 'x86_64';
}

/// Ubuntu 24.04 ships libfuse2 under its time64 name, which `dpkg -s libfuse2` cannot see.
const _debianPackageAliases = <String, List<String>>{
  'libfuse2': ['libfuse2t64'],
};

Future<bool> _isDebianPackageInstalled(String pkg) async {
  for (final name in [pkg, ...?_debianPackageAliases[pkg]]) {
    final result = await Process.run('dpkg', ['-s', name]);
    if (result.exitCode == 0 &&
        (result.stdout as String).contains('Status: install ok installed')) {
      return true;
    }
  }
  return false;
}

Future<bool> _areDebianPackagesInstalled(List<String> pkgs) async {
  for (final pkg in pkgs) {
    if (!await _isDebianPackageInstalled(pkg)) {
      return false;
    }
  }
  return true;
}

Future<int> _installLinuxPackages(List<String> pkgs) async {
  final exitCode = await _runLinuxDependencyCommand([
    'apt-get',
    'install',
    '-y',
    ...pkgs,
  ]);
  if (exitCode == 0) return 0;

  if (await _areDebianPackagesInstalled(pkgs)) {
    stderr.writeln(
      'apt-get install exited with $exitCode, but all requested packages are '
      'installed; continuing.',
    );
    return 0;
  }

  return exitCode;
}

Future<int> _runLinuxDependencyCommand(List<String> command) async {
  final sudoCommand = [
    'env',
    'DEBIAN_FRONTEND=noninteractive',
    'NEEDRESTART_MODE=a',
    ...command,
  ];
  stdout.writeln('exec: sudo ${sudoCommand.join(' ')}');
  final result = await Process.start('sudo', sudoCommand);
  result.stdout.listen((data) {
    stdout.write(utf8.decode(data));
  });
  result.stderr.listen((data) {
    stderr.write(utf8.decode(data));
  });
  final exitCode = await result.exitCode;
  if (exitCode != 0) {
    stderr.writeln('Linux dependency command failed with exit code $exitCode.');
  }
  return exitCode;
}
