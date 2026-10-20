import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:win32_registry/win32_registry.dart';

import 'app_localizations.dart';
import 'exception.dart';

int? readWindowsApplicationControlState() => LOCAL_MACHINE.getInt(
  'VerifiedAndReputablePolicyState',
  path: r'SYSTEM\CurrentControlSet\Control\CI\Policy',
);

/// Smart App Control (application control) visibility for an unsigned update.
enum WindowsApplicationControlState {
  /// Off, evaluation mode, or not configured: Windows does not block
  /// unsigned installers, so updating can proceed without extra prompts.
  inactive,

  /// Enforcement is on: unsigned installers are likely to be blocked or
  /// flagged by Windows, so the user should confirm before updating.
  enforced,

  /// The state could not be read or is an unknown value: stay cautious.
  unknown,
}

WindowsApplicationControlState windowsApplicationControlState({
  int? Function()? policyStateReader,
}) {
  int? state;
  try {
    state = (policyStateReader ?? readWindowsApplicationControlState)();
  } catch (_) {
    return WindowsApplicationControlState.unknown;
  }
  return switch (state) {
    null || 0 || 2 => WindowsApplicationControlState.inactive,
    1 => WindowsApplicationControlState.enforced,
    _ => WindowsApplicationControlState.unknown,
  };
}

/// How an in-app Windows update is applied.
enum WindowsUpdateStrategy {
  /// Run the packaged Inno Setup installer, which registers the uninstaller and
  /// shortcuts. Fine when Windows is not policing unsigned executables.
  installer,

  /// Unpack the portable archive over the installed files. Used when Smart App
  /// Control is enforced (or unreadable): Windows blocks the installer's
  /// extracted staging copy with error 4551, while plain file replacement of
  /// already-trusted files is not intercepted.
  portableOverwrite,
}

WindowsUpdateStrategy windowsUpdateStrategy({
  int? Function()? policyStateReader,
  bool? fixedPortable,
}) {
  if (fixedPortable != null) {
    return fixedPortable
        ? WindowsUpdateStrategy.portableOverwrite
        : WindowsUpdateStrategy.installer;
  }
  return windowsApplicationControlState(policyStateReader: policyStateReader) ==
          WindowsApplicationControlState.inactive
      ? WindowsUpdateStrategy.installer
      : WindowsUpdateStrategy.portableOverwrite;
}

void ensureUnsignedWindowsUpdateAllowed({
  int? Function()? policyStateReader,
  bool allowWhenEnforced = false,
}) {
  final state = windowsApplicationControlState(
    policyStateReader: policyStateReader,
  );
  if (state == WindowsApplicationControlState.inactive) return;
  if (allowWhenEnforced) return;
  throw MessageException(
    currentAppLocalizations.windowsUnsignedUpdateBlocked,
  );
}

const windowsUpdatePublisher = String.fromEnvironment('WINDOWS_SIGNER_SUBJECT');

Future<void> launchWindowsUpdate({
  required String filePath,
  required String installDirectory,
  required bool Function(String, String) launcher,
  required Future<void> Function() exitApplication,
  int? Function()? policyStateReader,
  String expectedPublisher = windowsUpdatePublisher,
  Future<bool> Function(String, String)? signatureVerifier,
  bool allowUnsignedWhenEnforced = false,
}) async {
  if (expectedPublisher.isEmpty) {
    ensureUnsignedWindowsUpdateAllowed(
      policyStateReader: policyStateReader,
      allowWhenEnforced: allowUnsignedWhenEnforced,
    );
  } else if (!await (signatureVerifier ?? verifyWindowsInstallerSignature)(
    filePath,
    expectedPublisher,
  )) {
    throw MessageException(
      currentAppLocalizations.windowsUnsignedUpdateBlocked,
    );
  }
  if (!launcher(filePath, '/DIR="$installDirectory" /NORESTART')) {
    throw MessageException(currentAppLocalizations.windowsUpdateLaunchFailed);
  }
  await exitApplication();
}

Future<bool> verifyWindowsInstallerSignature(
  String filePath,
  String expectedPublisher, {
  Future<ProcessResult> Function(String, List<String>)? processRunner,
}) async {
  if (expectedPublisher.isEmpty) return false;
  final encodedPath = base64Encode(utf8.encode(filePath));
  final script =
      r'''$ErrorActionPreference='Stop'
$path=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('ENCODED_PATH'))
$signature=Get-AuthenticodeSignature -LiteralPath $path
@{valid=($signature.Status -eq 'Valid');publisher=$signature.SignerCertificate.Subject;timestamp=($null -ne $signature.TimeStamperCertificate);rsa=($signature.SignerCertificate.PublicKey.Oid.Value -eq '1.2.840.113549.1.1.1')}|ConvertTo-Json -Compress
'''
          .replaceFirst('ENCODED_PATH', encodedPath);
  final bytes = ByteData(script.length * 2);
  for (var index = 0; index < script.length; index++) {
    bytes.setUint16(index * 2, script.codeUnitAt(index), Endian.little);
  }
  try {
    final result =
        await (processRunner ??
            (executable, arguments) =>
                Process.run(executable, arguments))('powershell.exe', [
          '-NoProfile',
          '-NonInteractive',
          '-EncodedCommand',
          base64Encode(bytes.buffer.asUint8List()),
        ]);
    if (result.exitCode != 0) return false;
    final response = jsonDecode(result.stdout as String);
    return response is Map &&
        response['valid'] == true &&
        response['timestamp'] == true &&
        response['rsa'] == true &&
        response['publisher'] == expectedPublisher;
  } catch (_) {
    return false;
  }
}
