import 'dart:convert';
import 'dart:io';

import 'app_localizations.dart';
import 'exception.dart';

const windowsPowerShellPath =
    r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe';

class WindowsPortableUpdatePlan {
  final String script;

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
  String dataDirectory = '',
  String healthDirectory = '',
  String preparationFile = '',
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
      .replaceFirst('__TEMP__', "'${encode(temporaryDirectory)}'")
      .replaceFirst('__DATA__', "'${encode(dataDirectory)}'")
      .replaceFirst('__HEALTH__', "'${encode(healthDirectory)}'")
      .replaceFirst('__PREPARED__', "'${encode(preparationFile)}'");

  final compressed = base64Encode(gzip.encode(utf8.encode(script)));
  final bootstrap =
      r'$bytes=[Convert]::FromBase64String('
      "'$compressed');"
      r'$stream=[IO.MemoryStream]::new($bytes);'
      r'$gzip=[IO.Compression.GZipStream]::new($stream,[IO.Compression.CompressionMode]::Decompress);'
      r'$reader=[IO.StreamReader]::new($gzip,[Text.Encoding]::UTF8);'
      r'try { & ([ScriptBlock]::Create($reader.ReadToEnd())) } finally { $reader.Dispose(); $stream.Dispose() }';
  final encoded = base64Encode(_utf16LeBytes(bootstrap));
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
  String dataDirectory = '',
  Future<void> Function(File)? waitForPreparation,
}) async {
  final preparation = await Directory.systemTemp.createTemp(
    'bfclash-update-ready-',
  );
  final prepared = File(
    '${preparation.path}${Platform.pathSeparator}ready.json',
  );
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
    dataDirectory: dataDirectory,
    preparationFile: prepared.path,
    healthDirectory:
        '${Platform.environment['LOCALAPPDATA'] ?? ''}\\BfClashUpdateHealth',
  );
  try {
    if (!launcher(powerShellPath, plan.commandLine)) {
      throw MessageException(currentAppLocalizations.windowsUpdateLaunchFailed);
    }
    await (waitForPreparation ?? _waitForPreparation)(prepared);
  } catch (_) {
    await prepared.writeAsString(jsonEncode({'status': 'cancelled'}));
    rethrow;
  }
  await exitApplication();
}

Future<void> _waitForPreparation(File prepared) async {
  final deadline = DateTime.now().add(const Duration(minutes: 3));
  while (DateTime.now().isBefore(deadline)) {
    if (await prepared.exists()) {
      try {
        final result = jsonDecode(await prepared.readAsString());
        if (result is Map && result['status'] == 'ready') return;
        if (result is Map && result['status'] == 'failed') {
          throw MessageException(
            currentAppLocalizations.windowsPortableUpdateFailedBody(
              '${result['detail']}',
              '${result['log']}',
            ),
          );
        }
      } on FormatException {
        // The elevated helper may still be writing its preparation result.
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw MessageException(currentAppLocalizations.windowsUpdateLaunchFailed);
}

const _scriptTemplate = r'''
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:PSModulePath = Join-Path $PSHOME 'Modules'
function Dec([string]$v) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($v)) }
$parentPid = __PARENT_PID__
$zip = Dec(__ZIP__)
$dir = [IO.Path]::GetFullPath((Dec(__DIR__))).TrimEnd('\')
$exe = [IO.Path]::GetFullPath((Dec(__EXE__)))
$service = Dec(__SERVICE__)
$version = Dec(__VERSION__)
$failTitle = Dec(__TITLE__)
$failBody = Dec(__FAILBODY__)
$dataDir = Dec(__DATA__)
$downloadDir = Dec(__TEMP__)
$log = Join-Path $env:TEMP 'bfclash-portable-update.log'
$nonce = [Guid]::NewGuid().ToString('N')
$transaction = Join-Path ([IO.Path]::GetDirectoryName($dir)) ('.' + [IO.Path]::GetFileName($dir) + '.update-' + $nonce)
$backup = Join-Path $transaction 'previous'
$stage = Join-Path $transaction 'staged'
$dataBackup = Join-Path $transaction 'userdata'
$prepared = Dec(__PREPARED__)
$healthRoot = Dec(__HEALTH__)
if (-not $healthRoot) { $healthRoot = Join-Path $env:LOCALAPPDATA 'BfClashUpdateHealth' }
$health = Join-Path $healthRoot ($nonce + '.json')
$pending = Join-Path $dir '.bfclash-update-pending.json'
$launchAttempted = $false
$stopped = $false
$serviceWasRunning = $false
$mutex = $null
$locked = $false
function L([string]$m) {
  try { Add-Content -LiteralPath $log -Value ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m) -Encoding UTF8 } catch {}
}
function Get-InstalledProcesses {
  @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $path = $null
    try { $path = $_.Path } catch {}
    $path -and $path.StartsWith($dir + '\', [StringComparison]::OrdinalIgnoreCase)
  })
}
function Get-App {
  @(Get-InstalledProcesses | Where-Object { $_.Path -ieq $exe })
}
function Stop-Installed {
  if ($service) {
    $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Stopped') {
      Stop-Service -Name $service -Force -ErrorAction Stop
      $svc.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(20))
    }
  }
  for ($i = 0; $i -lt 30; $i++) {
    $alive = @(Get-InstalledProcesses)
    if ($alive.Count -eq 0) { return }
    foreach ($item in $alive) { $item.Kill() }
    Start-Sleep -Milliseconds 300
  }
  throw 'installed processes did not exit; files have not been replaced'
}
function Start-Helper {
  if ($serviceWasRunning) {
    Start-Service -Name $service -ErrorAction Stop
    (Get-Service -Name $service).WaitForStatus('Running', [TimeSpan]::FromSeconds(20))
  }
}
function Start-App {
  Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList ('"' + $exe + '"') | Out-Null
  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 200
    if (@(Get-App).Count -gt 0) { L 'app process started'; return }
  }
  throw 'app did not start'
}
function Wait-AppReady {
  $deadline = (Get-Date).AddSeconds(60)
  while ((Get-Date) -lt $deadline) {
    if (Test-Path -LiteralPath $health) {
      $ready = $null
      try { $ready = Get-Content -LiteralPath $health -Raw | ConvertFrom-Json } catch {}
      if ($ready -and $ready.nonce -ceq $nonce -and $ready.version -ceq $version) {
        $app = @(Get-App | Where-Object { $_.Id -eq $ready.processId })
        if ($app.Count -eq 1) {
          for ($i = 0; $i -lt 16; $i++) {
            Start-Sleep -Milliseconds 500
            if (@(Get-App | Where-Object { $_.Id -eq $ready.processId }).Count -ne 1) { throw 'updated app exited after initialization' }
          }
          L 'app initialization and core connection confirmed'
          return
        }
      }
    }
    if (@(Get-App).Count -eq 0) { throw 'updated app exited before initialization' }
    Start-Sleep -Milliseconds 300
  }
  throw 'updated app did not confirm initialization and core connection'
}
function Wait-RestoredApp {
  Add-Type -TypeDefinition @'
using System;using System.Text;using System.Runtime.InteropServices;
public class BfUpdateWindow {
 public delegate bool Callback(IntPtr h,IntPtr l);
 [DllImport("user32.dll")] static extern bool EnumWindows(Callback c,IntPtr l);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h,StringBuilder b,int n);
 [DllImport("user32.dll")] static extern bool IsHungAppWindow(IntPtr h);
 public static bool Ready(uint id) {bool found=false;EnumWindows((h,l)=>{uint p;GetWindowThreadProcessId(h,out p);var b=new StringBuilder(256);GetClassName(h,b,256);if(p==id&&b.ToString().StartsWith("FLUTTER_RUNNER")&&!IsHungAppWindow(h)){found=true;return false;}return true;},IntPtr.Zero);return found;}
}
'@
  for ($i = 0; $i -lt 60; $i++) {
    $app = @(Get-App)
    foreach ($item in $app) {
      if ([BfUpdateWindow]::Ready($item.Id)) {
        Start-Sleep -Seconds 3
        if (@(Get-App | Where-Object { $_.Id -eq $item.Id }).Count -eq 1) { L 'previous app window restored'; return }
      }
    }
    Start-Sleep -Milliseconds 300
  }
  throw 'previous app window could not be confirmed'
}
function Copy-Tree([string]$source, [string]$destination, [bool]$mirror = $false) {
  $mode = '/E'
  if ($mirror) { $mode = '/MIR' }
  robocopy $source $destination $mode /XJ /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
  if ($LASTEXITCODE -ge 8) { throw ('file copy failed with code ' + $LASTEXITCODE) }
}
function Show-Fail([string]$message) {
  L ('FAILED: ' + $message)
  try {
    Add-Type -AssemblyName PresentationFramework
    [void][System.Windows.MessageBox]::Show($failBody.Replace('{detail}', $message).Replace('{log}', $log), $failTitle, 'OK', 'Error')
  } catch {}
}
function Hash-File([string]$path) {
  $stream = [IO.File]::OpenRead($path)
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($algorithm.ComputeHash($stream)) }
  finally { $stream.Dispose(); $algorithm.Dispose() }
}
function Preserve-UnchangedNativeFiles {
  foreach ($file in @(Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object { $_.Extension -in '.dll','.exe' })) {
    $relative = $file.FullName.Substring($stage.Length + 1)
    $original = Join-Path $dir $relative
    if (-not (Test-Path -LiteralPath $original -PathType Leaf)) { continue }
    if ((Get-Item -LiteralPath $original).Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
    if ((Hash-File $original) -cne (Hash-File $file.FullName)) { continue }
    Remove-Item -LiteralPath $file.FullName -Force
    New-Item -ItemType HardLink -Path $file.FullName -Value $original | Out-Null
    L ('preserved unchanged native file identity: ' + $relative)
  }
}
function Preparation-Result([string]$status, [string]$detail) {
  if (-not $prepared) { return }
  $cancelled = $false
  if (Test-Path -LiteralPath $prepared) {
    try { $cancelled = (Get-Content -LiteralPath $prepared -Raw | ConvertFrom-Json).status -eq 'cancelled' } catch {}
  }
  if ($cancelled) {
    if ($status -eq 'ready') { throw 'update preparation cancelled' }
    return
  }
  try {
    @{status=$status; detail=$detail; log=$log} | ConvertTo-Json | Set-Content -LiteralPath ($prepared + '.tmp') -Encoding UTF8
    Move-Item -LiteralPath ($prepared + '.tmp') -Destination $prepared -Force
  }
  catch { if ($status -eq 'ready') { throw }; L ('preparation result failed: ' + $_) }
}
function Test-Payload {
  $root64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($stage))
  $body = '$ErrorActionPreference="Stop";$ProgressPreference="SilentlyContinue"; Add-Type -TypeDefinition ''using System;using System.Runtime.InteropServices;public class BfPayload { [DllImport("kernel32",CharSet=CharSet.Unicode,SetLastError=true)]public static extern IntPtr LoadLibraryEx(string p,IntPtr f,uint flags);[DllImport("kernel32")]public static extern bool FreeLibrary(IntPtr h);[DllImport("kernel32",CharSet=CharSet.Unicode)]public static extern IntPtr AddDllDirectory(string p);[DllImport("kernel32")]public static extern bool SetDefaultDllDirectories(uint f);}''; $root=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("__ROOT__")); [BfPayload]::SetDefaultDllDirectories(0x1000)|Out-Null; [BfPayload]::AddDllDirectory($root)|Out-Null; foreach($file in @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {$_.Extension -eq ".dll"})) { $h=[BfPayload]::LoadLibraryEx($file.FullName,[IntPtr]::Zero,0x1100); if($h -eq [IntPtr]::Zero){$code=[Runtime.InteropServices.Marshal]::GetLastWin32Error();if($file.Name -eq "dartjni.dll" -and $code -eq 126){continue};[Console]::Error.WriteLine($file.Name+": "+$code);exit 2}; [BfPayload]::FreeLibrary($h)|Out-Null }; exit 0'
  $body = $body.Replace('__ROOT__', $root64)
  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($body))
  $check = [Diagnostics.Process]::new()
  $check.StartInfo.FileName = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $check.StartInfo.Arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand ' + $encoded
  $check.StartInfo.UseShellExecute = $false
  $check.StartInfo.RedirectStandardError = $true
  try {
    $check.Start() | Out-Null
    if (-not $check.WaitForExit(90000)) { $check.Kill(); $check.WaitForExit(); throw 'payload load check timed out; current app was not stopped' }
    $detail = $check.StandardError.ReadToEnd()
    if ($check.ExitCode -ne 0) { throw ('Windows could not load the update; current app was not stopped: ' + $detail) }
  } finally { $check.Dispose() }
  L 'payload load check passed before app shutdown'
}

function Retain-Backups {
  try {
    @{install=$dir; nonce=$nonce; committedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $transaction 'committed.json') -Encoding UTF8
    $committed = @()
    $parent = [IO.Path]::GetDirectoryName($dir)
    $prefix = '.' + [IO.Path]::GetFileName($dir) + '.update-'
    foreach ($folder in @(Get-ChildItem -LiteralPath $parent -Directory -Force)) {
      if (-not $folder.Name.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or ($folder.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
      $marker = Join-Path $folder.FullName 'committed.json'
      if (-not (Test-Path -LiteralPath $marker)) { continue }
      try {
        $record = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
        if ($record.install -ine $dir -or $record.nonce -notmatch '^[a-f0-9]{32}$' -or $folder.Name -ine ($prefix + $record.nonce)) { continue }
        $committed += [PSCustomObject]@{Path=$folder.FullName;Time=[DateTime]::Parse($record.committedUtc)}
      } catch {}
    }
    foreach ($entry in @($committed | Sort-Object Time -Descending | Select-Object -Skip 2)) {
      if ($entry.Path -ine $transaction) { Remove-Item -LiteralPath $entry.Path -Recurse -Force; L ('removed older committed backup: ' + $entry.Path) }
    }
  } catch { L ('backup retention deferred: ' + $_) }
}
function Update-DisplayVersion {
  if (-not $version) { return }
  foreach ($root in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')) {
    Get-ChildItem -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
      $item = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
      if ($item.InstallLocation -and $item.InstallLocation.TrimEnd('\') -ieq $dir) {
        Set-ItemProperty -Path $_.PSPath -Name DisplayVersion -Value $version -ErrorAction Stop
      }
    }
  }
}
try {
  if (-not $exe.StartsWith($dir + '\', [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetDirectoryName($dir) -eq $null) { throw 'invalid install path' }
  $keyBytes = [Text.Encoding]::UTF8.GetBytes($dir.ToLowerInvariant())
  $key = ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($keyBytes))).Replace('-', '')
  $mutex = [Threading.Mutex]::new($false, ('Global\BfClashUpdate-' + $key))
  try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
  if (-not $locked) { throw 'another update is already running' }
  L ('transaction start: ' + $transaction)
  New-Item -ItemType Directory -Path $stage -Force | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [IO.Compression.ZipFile]::OpenRead($zip)
  try {
    $entries = @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) -and -not $_.FullName.StartsWith('__MACOSX/') })
    if ($entries.Count -eq 0) { throw 'update archive is empty' }
    foreach ($entry in $entries) {
      if ([IO.Path]::IsPathRooted($entry.FullName) -or $entry.FullName.Contains(':') -or @($entry.FullName.Split('/\') | Where-Object { $_ -eq '..' }).Count -gt 0) { throw 'invalid archive path' }
    }
    $prefix = ''
    $slash = $entries[0].FullName.IndexOf('/')
    if ($slash -gt 0) {
      $candidate = $entries[0].FullName.Substring(0, $slash + 1)
      $shared = @($entries | Where-Object { -not $_.FullName.StartsWith($candidate, [StringComparison]::OrdinalIgnoreCase) }).Count -eq 0
      if ($shared -and @($entries | Where-Object { $_.FullName -ieq ($candidate + [IO.Path]::GetFileName($exe)) }).Count -eq 1) { $prefix = $candidate }
    }
    $seen = @{}
    $stagedExe = Join-Path $stage $exe.Substring($dir.Length + 1)
    foreach ($entry in $entries) {
      $relative = $entry.FullName.Substring($prefix.Length)
      $target = [IO.Path]::GetFullPath((Join-Path $stage $relative))
      if (-not $target.StartsWith($stage + '\', [StringComparison]::OrdinalIgnoreCase) -or $seen.ContainsKey($target)) { throw 'invalid or duplicate archive path' }
      $seen[$target] = $true
      New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
      [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
    }
    if (-not $seen.ContainsKey($stagedExe)) { throw 'executable missing from update archive' }
    if ($seen.ContainsKey((Join-Path $stage '.bfclash-update-pending.json'))) { throw 'reserved update file in archive' }
  } finally { $archive.Dispose() }
  Preserve-UnchangedNativeFiles
  Test-Payload
  Preparation-Result 'ready' ''
  $proc = Get-Process -Id $parentPid -ErrorAction SilentlyContinue
  if ($proc -and -not $proc.WaitForExit(120000)) { throw 'app did not exit; update cancelled' }
  if ($prepared -and (Test-Path -LiteralPath $prepared) -and (Get-Content -LiteralPath $prepared -Raw | ConvertFrom-Json).status -eq 'cancelled') { throw 'update preparation cancelled' }
  $svc = $null
  if ($service) { $svc = Get-Service -Name $service -ErrorAction SilentlyContinue }
  $serviceWasRunning = $svc -and $svc.Status -eq 'Running'
  $stopped = $true
  Stop-Installed
  foreach ($uninstaller in @(Get-ChildItem -LiteralPath $dir -Filter 'unins*' -File)) {
    if (-not (Test-Path -LiteralPath (Join-Path $stage $uninstaller.Name))) { New-Item -ItemType HardLink -Path (Join-Path $stage $uninstaller.Name) -Value $uninstaller.FullName | Out-Null }
  }
  if ($dataDir) {
    $dataDir = [IO.Path]::GetFullPath($dataDir).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $dataDir -PathType Container) -or $dataDir.Length -le 3 -or $dataDir -ieq $dir -or $dataDir.StartsWith($dir + '\', [StringComparison]::OrdinalIgnoreCase) -or $dir.StartsWith($dataDir + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'invalid user data directory' }
    New-Item -ItemType Directory -Path $dataBackup -Force | Out-Null
    $dataAcl = Get-Acl -LiteralPath $dataDir
    $dataAcl.SetAccessRuleProtection($true, $true)
    Set-Acl -LiteralPath $dataBackup -AclObject $dataAcl
    Copy-Tree $dataDir $dataBackup
  }
  @{nonce=$nonce; version=$version; createdUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stage '.bfclash-update-pending.json') -Encoding UTF8
  Move-Item -LiteralPath $dir -Destination $backup
  Move-Item -LiteralPath $stage -Destination $dir
  Start-Helper
  $launchAttempted = $true
  Start-App
  Wait-AppReady
  Remove-Item -LiteralPath $pending -Force
  Remove-Item -LiteralPath $health -Force -ErrorAction SilentlyContinue
  try { Update-DisplayVersion } catch { L ('display version update failed: ' + $_) }
  Retain-Backups
  if ($downloadDir -and [IO.Path]::GetFileName($downloadDir) -match '^bfclash-update-[a-f0-9]{64}$' -and [IO.Path]::GetDirectoryName($zip) -ieq $downloadDir -and -not $dir.StartsWith($downloadDir + '\', [StringComparison]::OrdinalIgnoreCase) -and -not $dataDir.StartsWith($downloadDir + '\', [StringComparison]::OrdinalIgnoreCase)) {
    try { Remove-Item -LiteralPath $downloadDir -Recurse -Force } catch { L ('download cleanup deferred: ' + $_) }
  }
  L ('portable update committed; original files retained: ' + $backup)
  exit 0
} catch {
  $message = $_.Exception.Message
  L ('update error: ' + $message)
  Preparation-Result 'failed' $message
  if ($locked -and $stopped) {
    try {
      Stop-Installed
      if (Test-Path -LiteralPath $backup) {
        if (Test-Path -LiteralPath $dir) { Move-Item -LiteralPath $dir -Destination (Join-Path $transaction 'failed') }
        Move-Item -LiteralPath $backup -Destination $dir
        if ($launchAttempted -and (Test-Path -LiteralPath $dataBackup)) { Copy-Tree $dataBackup $dataDir $true }
      }
      Start-Helper
      Start-App
      Wait-RestoredApp
      L 'rollback confirmed'
      try { Remove-Item -LiteralPath $transaction -Recurse -Force } catch { L ('rollback cleanup deferred: ' + $_) }
    } catch { $message += '; recovery failed: ' + $_.Exception.Message; L $message }
  } elseif ($locked -and @(Get-App).Count -eq 0 -and (Test-Path -LiteralPath $exe)) {
    try { Start-App; Wait-RestoredApp } catch { L ('restart unchanged app failed: ' + $_) }
  }
  if ($locked -and -not $stopped) {
    try { Remove-Item -LiteralPath $transaction -Recurse -Force -ErrorAction SilentlyContinue } catch {}
  }
  if ($stopped -or -not $prepared) { Show-Fail $message }
  exit 1
} finally {
  if ($locked -and $mutex) { $mutex.ReleaseMutex() }
  if ($mutex) { $mutex.Dispose() }
}
''';
