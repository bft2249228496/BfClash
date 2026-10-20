import 'dart:convert';
import 'dart:io';

import 'app_localizations.dart';
import 'exception.dart';

/// `powershell.exe` always lives in the system directory, so the path is stable
/// across x64/arm64 Windows installs.
const windowsPowerShellPath =
    r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe';

/// A fully prepared elevated command that swaps the installed files in place.
///
/// The script is passed to PowerShell through `-EncodedCommand`, which keeps it
/// out of the filesystem: no `.ps1` lands in `%TEMP%`, so Windows never attaches
/// a mark-of-the-web and application control cannot block the helper the way it
/// blocks the Inno Setup staging copy (error 4551).
class WindowsPortableUpdatePlan {
  /// Decoded PowerShell source, kept for logging and tests.
  final String script;

  /// Command line arguments passed to [windowsPowerShellPath].
  final List<String> arguments;

  const WindowsPortableUpdatePlan({
    required this.script,
    required this.arguments,
  });

  String get commandLine => arguments.join(' ');
}

WindowsPortableUpdatePlan buildWindowsPortableUpdatePlan({
  required int parentProcessId,
  required String zipPath,
  required String installDirectory,
  required String executablePath,
  required String serviceName,
  required String targetVersion,
  required String failureTitle,
  required String failureBodyTemplate,
  String powerShellPath = windowsPowerShellPath,
  String temporaryDirectory = '',
}) {
  String encode(String value) => base64Encode(utf8.encode(value));

  final script = _scriptTemplate
      .replaceFirst('__PARENT_PID__', '$parentProcessId')
      .replaceFirst('__ZIP__', "'${encode(zipPath)}'")
      .replaceFirst('__DIR__', "'${encode(installDirectory)}'")
      .replaceFirst('__EXE__', "'${encode(executablePath)}'")
      .replaceFirst('__SERVICE__', "'${encode(serviceName)}'")
      .replaceFirst('__VERSION__', "'${encode(targetVersion)}'")
      .replaceFirst('__TITLE__', "'${encode(failureTitle)}'")
      .replaceFirst('__FAILBODY__', "'${encode(failureBodyTemplate)}'")
      .replaceFirst('__TEMP__', "'${encode(temporaryDirectory)}'");

  final encoded = base64Encode(_utf16LeBytes(script));
  return WindowsPortableUpdatePlan(
    script: script,
    arguments: [
      '-NoProfile',
      '-NonInteractive',
      '-STA',
      '-WindowStyle',
      'Hidden',
      '-ExecutionPolicy',
      'Bypass',
      '-EncodedCommand',
      encoded,
    ],
  );
}

List<int> _utf16LeBytes(String value) {
  final bytes = List<int>.filled(value.length * 2, 0);
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    bytes[index * 2] = unit & 0xFF;
    bytes[index * 2 + 1] = unit >> 8;
  }
  return bytes;
}

/// Replaces the installed files without running the Inno Setup installer.
///
/// Used when Smart App Control (or an unreadable policy state) would otherwise
/// block the unsigned installer's extracted staging copy. The elevated helper
/// waits for this process to exit, stops the helper service, kills leftovers,
/// backs up the previous files, unpacks the verified zip over them, restarts the
/// service and relaunches the app as the signed-in user.
Future<void> launchWindowsPortableUpdate({
  required String zipPath,
  required String installDirectory,
  required String executablePath,
  required String serviceName,
  required String targetVersion,
  required bool Function(String, String) launcher,
  required Future<void> Function() exitApplication,
  int? parentProcessId,
  String failureTitle = '',
  String failureBodyTemplate = '',
  String powerShellPath = windowsPowerShellPath,
  String temporaryDirectory = '',
}) async {
  final plan = buildWindowsPortableUpdatePlan(
    parentProcessId: parentProcessId ?? pid,
    zipPath: zipPath,
    installDirectory: installDirectory,
    executablePath: executablePath,
    serviceName: serviceName,
    targetVersion: targetVersion,
    failureTitle: failureTitle.isEmpty
        ? currentAppLocalizations.windowsPortableUpdateFailedTitle
        : failureTitle,
    // Keep the localized sentence order but leave the placeholders for the
    // elevated helper, which replaces them with the failure detail and log path.
    failureBodyTemplate: failureBodyTemplate.isEmpty
        ? currentAppLocalizations.windowsPortableUpdateFailedBody(
            '{detail}',
            '{log}',
          )
        : failureBodyTemplate,
    powerShellPath: powerShellPath,
    temporaryDirectory: temporaryDirectory,
  );
  if (!launcher(powerShellPath, plan.commandLine)) {
    throw MessageException(currentAppLocalizations.windowsUpdateLaunchFailed);
  }
  await exitApplication();
}

/// ASCII-only helper body; every path, message and version is injected as a
/// base64 blob so the encoded command survives non-ASCII install directories.
const _scriptTemplate = r'''
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
function Dec([string]$v) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($v)) }
$parentPid = __PARENT_PID__
$zip = Dec(__ZIP__)
$dir = Dec(__DIR__)
$exe = Dec(__EXE__)
$service = Dec(__SERVICE__)
$version = Dec(__VERSION__)
$failTitle = Dec(__TITLE__)
$failBody = Dec(__FAILBODY__)
$tempRoot = Dec(__TEMP__)
$log = Join-Path $env:TEMP 'bfclash-portable-update.log'
$backedUp = $false
$backup = Join-Path $env:LOCALAPPDATA 'BfClashUpdateBackup\previous'
function L([string]$m) {
  try { Add-Content -LiteralPath $log -Value ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m) -Encoding UTF8 } catch {}
}
function Start-App {
  try {
    Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList ('"' + $exe + '"') | Out-Null
    Start-Sleep -Milliseconds 1500
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
      $path = $null
      try { $path = $_.Path } catch {}
      $path -and $path.Equals($exe, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($running.Count -eq 0) { Start-Process -FilePath $exe -WorkingDirectory $dir | Out-Null }
    L 'app relaunched'
  } catch { L ('relaunch failed: ' + $_) }
}
function Show-Fail([string]$message) {
  L ('FAILED: ' + $message)
  try {
    $text = $failBody.Replace('{detail}', $message).Replace('{log}', $log)
    $text64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($text))
    $title64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($failTitle))
    $dialog = "Add-Type -AssemblyName PresentationFramework; [void][System.Windows.MessageBox]::Show([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$text64')), [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$title64')), 'OK', 'Error')"
    $encodedDialog = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($dialog))
    Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList @('-NoProfile', '-STA', '-WindowStyle', 'Hidden', '-EncodedCommand', $encodedDialog) | Out-Null
  } catch {}
}
try {
  L ('portable update start pid=' + $parentPid + ' dir=' + $dir)
  try {
    $proc = Get-Process -Id $parentPid -ErrorAction Stop
    [void]$proc.WaitForExit(120000)
  } catch { L 'parent process already exited' }
  Start-Sleep -Milliseconds 800
  if ($service) {
    $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Stopped') {
      L ('stop service ' + $service)
      try { Stop-Service -Name $service -Force -ErrorAction Stop } catch { L ('stop service failed: ' + $_) }
    }
  }
  for ($i = 0; $i -lt 25; $i++) {
    $alive = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
      $path = $null
      try { $path = $_.Path } catch {}
      $path -and $path.StartsWith($dir, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($alive.Count -eq 0) { break }
    foreach ($item in $alive) {
      L ('kill ' + $item.ProcessName + ' ' + $item.Id)
      try { $item.Kill() } catch { L ('kill failed: ' + $_) }
    }
    Start-Sleep -Milliseconds 400
  }
  try {
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue }
    robocopy $dir $backup /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
    if ($LASTEXITCODE -lt 8) { $backedUp = $true; L ('backup ok: ' + $backup) } else { L ('backup exit ' + $LASTEXITCODE) }
  } catch { L ('backup failed: ' + $_) }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [IO.Compression.ZipFile]::OpenRead($zip)
  try {
    $entries = @($archive.Entries | Where-Object {
      -not [string]::IsNullOrEmpty($_.Name) -and -not $_.FullName.StartsWith('__MACOSX/')
    })
    $prefix = ''
    if ($entries.Count -eq 0) { throw 'update archive is empty' }
    $first = $entries[0].FullName
    $slash = $first.IndexOf('/')
    if ($slash -gt 0) {
      $candidate = $first.Substring(0, $slash + 1)
      $shared = $true
      foreach ($entry in $entries) {
        if (-not $entry.FullName.StartsWith($candidate, [StringComparison]::OrdinalIgnoreCase)) { $shared = $false; break }
      }
      if ($shared -and -not (Test-Path -LiteralPath (Join-Path $dir $candidate.TrimEnd('/')))) { $prefix = $candidate }
    }
    L ('zip entries ' + $entries.Count + ' prefix "' + $prefix + '"')
    $count = 0
    foreach ($entry in $entries) {
      $relative = $entry.FullName
      if ($prefix) { $relative = $relative.Substring($prefix.Length) }
      if ([string]::IsNullOrEmpty($relative)) { continue }
      $target = Join-Path $dir $relative
      $targetDir = [IO.Path]::GetDirectoryName($target)
      if ($targetDir -and -not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
      if (Test-Path -LiteralPath $target) { Set-ItemProperty -LiteralPath $target -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue }
      [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
      $count++
    }
    L ('extracted ' + $count + ' files')
  } finally { $archive.Dispose() }
  if ($service) {
    try { Start-Service -Name $service -ErrorAction Stop; L ('service started ' + $service) } catch { L ('start service failed: ' + $_) }
  }
  if ($version) {
    $trimmed = $dir.TrimEnd('\')
    foreach ($root in @(
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
      'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')) {
      Get-ChildItem -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
        $item = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
        if ($item.InstallLocation -and $item.InstallLocation.TrimEnd('\') -ieq $trimmed) {
          Set-ItemProperty -Path $_.PSPath -Name DisplayVersion -Value $version -ErrorAction SilentlyContinue
          L ('display version updated: ' + $_.PSChildName)
        }
      }
    }
  }
  if (-not (Test-Path -LiteralPath $exe)) { throw 'executable missing after update' }
  Start-App
  if ($tempRoot) { try { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue } catch {} }
  L 'portable update done'
  exit 0
} catch {
  $message = $_.Exception.Message
  L ('error: ' + $message)
  if ($backedUp) {
    L 'restoring backup'
    try { robocopy $backup $dir /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null } catch { L ('restore failed: ' + $_) }
    if (Test-Path -LiteralPath $exe) { Start-App }
  }
  if ($service) { try { Start-Service -Name $service -ErrorAction SilentlyContinue } catch {} }
  Show-Fail $message
  exit 1
}
''';
