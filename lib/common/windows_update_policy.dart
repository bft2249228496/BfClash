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

void ensureUnsignedWindowsUpdateAllowed({int? Function()? policyStateReader}) {
  int? state;
  try {
    state = (policyStateReader ?? readWindowsApplicationControlState)();
  } catch (_) {
    throw MessageException(
      currentAppLocalizations.windowsUnsignedUpdateBlocked,
    );
  }
  if (state != null && state != 0 && state != 2) {
    throw MessageException(
      currentAppLocalizations.windowsUnsignedUpdateBlocked,
    );
  }
}

const windowsUpdatePublisher = String.fromEnvironment('WINDOWS_SIGNER_SUBJECT');

void ensureWindowsUpdateDownloadAllowed({
  String expectedPublisher = windowsUpdatePublisher,
  int? Function()? policyStateReader,
}) {
  if (expectedPublisher.isEmpty) {
    ensureUnsignedWindowsUpdateAllowed(policyStateReader: policyStateReader);
  }
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

Future<void> launchWindowsUpdate({
  required String filePath,
  required String installDirectory,
  required bool Function(String, String) launcher,
  required Future<void> Function() exitApplication,
  int? Function()? policyStateReader,
  String expectedPublisher = windowsUpdatePublisher,
  Future<bool> Function(String, String)? signatureVerifier,
}) async {
  if (expectedPublisher.isEmpty) {
    ensureUnsignedWindowsUpdateAllowed(policyStateReader: policyStateReader);
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
