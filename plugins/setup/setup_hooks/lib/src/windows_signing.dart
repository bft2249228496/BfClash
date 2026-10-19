import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'error.dart';
import 'util.dart';

abstract interface class WindowsSigningBackend {
  List<String> get inputs;
  Map<String, String> get identity;
  Future<void> sign(String file);
  Future<void> verify(String file);
}

class WindowsBinarySigner implements WindowsSigningBackend {
  WindowsBinarySigner._(
    this.script,
    this.inputs,
    this.identity,
    this.environment,
  );

  final String script;
  final Map<String, String> environment;
  @override
  final List<String> inputs;
  @override
  final Map<String, String> identity;

  static WindowsBinarySigner? load({
    required String rootDir,
    required String goos,
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    if (goos != 'windows') return null;
    final requested = env['BFCLASH_WINDOWS_SIGNING_REQUIRED'];
    if (requested == null || requested == 'false') return null;
    if (requested != 'true') {
      throw BuildException(
        'BFCLASH_WINDOWS_SIGNING_REQUIRED must be true or false',
      );
    }
    const required = [
      'BFCLASH_SIGNTOOL',
      'BFCLASH_SIGNING_DLIB',
      'BFCLASH_SIGNING_METADATA',
      'BFCLASH_SIGNER_SUBJECT',
    ];
    for (final name in required) {
      if (env[name]?.trim().isNotEmpty != true) {
        throw BuildException(
          'Required signing configuration is missing: $name',
        );
      }
    }
    final script = p.join(rootDir, 'tool', 'sign_windows_binary.ps1');
    final files = [script, for (final name in required.take(3)) env[name]!];
    final identity = <String, String>{
      'subject': env['BFCLASH_SIGNER_SUBJECT']!,
    };
    for (var index = 0; index < files.length; index++) {
      final file = File(files[index]);
      if (!file.existsSync()) {
        throw BuildException(
          'Required signing input does not exist: ${file.path}',
        );
      }
      identity['input_$index'] = sha256
          .convert(file.readAsBytesSync())
          .toString();
    }
    return WindowsBinarySigner._(script, files, identity, {
      'BFCLASH_WINDOWS_SIGNING_REQUIRED': 'true',
      for (final name in required) name: env[name]!,
    });
  }

  @override
  Future<void> sign(String file) => _run(file, verifyOnly: false);

  @override
  Future<void> verify(String file) => _run(file, verifyOnly: true);

  Future<void> _run(String file, {required bool verifyOnly}) async {
    if (!Platform.isWindows) {
      throw BuildException('Trusted Windows signing requires a Windows host');
    }
    await runCommandStream('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-File',
      script,
      '-FilePath',
      p.absolute(file),
      if (verifyOnly) '-VerifyOnly',
    ], environment: environment);
  }
}
