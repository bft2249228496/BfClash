import 'dart:convert';
import 'dart:io';

import 'package:liquid_engine/liquid_engine.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

Future<String> renderSignedWindowsInstaller({
  required String rootDir,
  required String payloadDirectory,
  required String outputBaseName,
  required String version,
  required String arch,
  required bool beta,
}) async {
  if (arch != 'amd64' && arch != 'arm64') {
    throw ArgumentError.value(arch, 'arch');
  }
  final configFile = beta ? 'make_config.beta.yaml' : 'make_config.yaml';
  final config =
      loadYaml(
            File(
              p.join(rootDir, 'windows', 'packaging', 'exe', configFile),
            ).readAsStringSync(),
          )
          as Map;
  final context = Context.create();
  context.variables = {
    'APP_ID': config['app_id'],
    'APP_VERSION': version.split('+').first,
    'DISPLAY_NAME': config['display_name'],
    'PUBLISHER_NAME': config['publisher'],
    'PUBLISHER_URL': config['publisher_url'],
    'INSTALL_DIR_NAME': '{autopf}\\${config['app_name']}',
    'OUTPUT_BASE_FILENAME': outputBaseName,
    'SETUP_ICON_FILE': p.join(
      rootDir,
      'windows',
      'runner',
      'resources',
      'app_icon.ico',
    ),
    'PRIVILEGES_REQUIRED': config['privileges_required'],
    'ARCH': arch == 'arm64' ? 'arm64' : 'x64',
    'HELPER_SERVICE_EXECUTABLE_NAME': config['helper_service_executable_name'],
    'EXECUTABLE_NAME': config['executable_name'],
    'SOURCE_DIR': payloadDirectory,
    'CREATE_DESKTOP_ICON': false,
    'LOCALES': [
      {'lang': 'en'},
      {
        'lang': 'zh',
        'file':
            '"${p.join(rootDir, 'windows', 'packaging', 'exe', 'ChineseSimplified.isl')}"',
      },
    ],
  };
  final source = File(
    p.join(rootDir, 'windows', 'packaging', 'exe', 'inno_setup.iss'),
  ).readAsStringSync();
  final template = Template.parse(context, Source.fromString(source));
  final rendered = await template.render(context);
  if (rendered.contains('{{') || rendered.contains('{%')) {
    throw StateError('Unresolved installer template input');
  }
  return '\uFEFF$rendered';
}

Future<int> packageSignedWindows({
  required String rootDir,
  required String arch,
  required bool beta,
  required String targets,
  required List<String> flutterBuildArgs,
}) async {
  if (!Platform.isWindows) {
    throw StateError('Signed Windows packaging requires Windows');
  }
  final formats = targets.split(',').toSet();
  if (!formats.contains('exe') ||
      formats.any((format) => format != 'exe' && format != 'zip')) {
    throw StateError(
      'Signed Windows targets must include exe and optionally zip',
    );
  }
  final defines =
      jsonDecode(File(p.join(rootDir, 'env.json')).readAsStringSync()) as Map;
  final build = await Process.start(
    'flutter',
    [
      'build',
      'windows',
      '--release',
      for (final arg in flutterBuildArgs) '--$arg',
    ],
    workingDirectory: rootDir,
    runInShell: true,
    environment: {'APP_BETA': defines['APP_BETA'] as String},
  );
  await Future.wait([
    stdout.addStream(build.stdout),
    stderr.addStream(build.stderr),
  ]);
  final status = await build.exitCode;
  if (status != 0) return status;
  final document =
      loadYaml(File(p.join(rootDir, 'pubspec.yaml')).readAsStringSync()) as Map;
  final version = document['version'] as String;
  final label = 'BfClash-${version.split('+').first}-windows-$arch';
  final staging = await Directory(
    p.join(rootDir, 'dist'),
  ).create(recursive: true);
  final work = await staging.createTemp('signed-');
  final script = File(p.join(work.path, 'package.iss'));
  try {
    await script.writeAsString(
      await renderSignedWindowsInstaller(
        rootDir: rootDir,
        payloadDirectory: p.join(work.path, 'payload'),
        outputBaseName: '$label-setup',
        version: version,
        arch: arch,
        beta: beta,
      ),
    );
    final process = await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-File',
        p.join(rootDir, 'tool', 'package_signed_windows.ps1'),
        '-BuildDirectory',
        p.join(
          rootDir,
          'build',
          'windows',
          arch == 'arm64' ? 'arm64' : 'x64',
          'runner',
          'Release',
        ),
        '-WorkDirectory',
        work.path,
        '-InstallerScript',
        script.path,
        '-OutputBaseName',
        label,
        '-CoreName',
        beta ? 'BfClashCoreBeta.exe' : 'BfClashCore.exe',
        '-HelperName',
        beta ? 'BfClashHelperServiceBeta.exe' : 'BfClashHelperService.exe',
        '-ManifestPath',
        p.join(rootDir, 'libclash', 'windows', 'manifest.json'),
        if (formats.contains('zip')) '-CreateZip',
      ],
      workingDirectory: rootDir,
      runInShell: true,
    );
    await Future.wait([
      stdout.addStream(process.stdout),
      stderr.addStream(process.stderr),
    ]);
    return await process.exitCode;
  } finally {
    if (await work.exists()) await work.delete(recursive: true);
  }
}
