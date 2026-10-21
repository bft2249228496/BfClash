$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repository = Split-Path $PSScriptRoot -Parent
$source = Get-Content (Join-Path $repository 'lib/common/windows_portable_update.dart') -Raw
$template = [regex]::Match($source, "(?s)const _scriptTemplate = r'''\r?\n(.*?)''';").Groups[1].Value
if (-not $template) { throw 'Portable updater template not found' }
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('bfclash-update-fixtures-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Assert([bool]$value, [string]$message) { if (-not $value) { throw $message } }
function FileId([string]$file) { ((& fsutil file queryfileid $file) -join '').Trim() }
$fixtures = @('success', 'launch-failure', 'health-failure', 'service-failure', 'swap-failure', 'backup-failure', 'corrupt-zip', 'missing-exe', 'traversal', 'duplicate')
try {
  foreach ($case in $fixtures) {
    $folder = Join-Path $testRoot $case
    $install = Join-Path $folder 'installed'
    $data = Join-Path $folder 'userdata'
    New-Item -ItemType Directory -Path $install,$data | Out-Null
    $exe = Join-Path $install 'Fixture.exe'
    [IO.File]::WriteAllText($exe, 'old app')
    [IO.File]::WriteAllText((Join-Path $install 'old-only.dll'), 'old file')
    [IO.File]::WriteAllText((Join-Path $install 'unins000.dat'), 'uninstaller')
    [IO.File]::WriteAllText((Join-Path $data 'config.json'), 'original config')
    $originalId = FileId $exe
    $archivePath = Join-Path $folder 'update.zip'
    $archive = [IO.Compression.ZipFile]::Open($archivePath, 'Create')
    try {
      $name = if ($case -eq 'missing-exe') { 'missing.txt' } elseif ($case -eq 'traversal') { '../Fixture.exe' } else { 'bundle/Fixture.exe' }
      $entry = $archive.CreateEntry($name)
      $writer = [IO.StreamWriter]::new($entry.Open())
      $writer.Write('new app'); $writer.Dispose()
      if ($case -eq 'duplicate') {
        $entry = $archive.CreateEntry('bundle/fixture.exe')
        $writer = [IO.StreamWriter]::new($entry.Open())
        $writer.Write('duplicate'); $writer.Dispose()
      }
    } finally { $archive.Dispose() }
    if ($case -eq 'corrupt-zip') { [IO.File]::WriteAllText($archivePath, 'not a zip') }
    $script = $template.Replace('__PARENT_PID__', '2147483647')
    $values = @{'__ZIP__'=$archivePath; '__DIR__'=$install; '__EXE__'=$exe; '__SERVICE__'=''; '__VERSION__'='1.0.1-beta.1911'; '__TITLE__'='Fixture'; '__FAILBODY__'='{detail} {log}'; '__TEMP__'=$folder; '__DATA__'=$data; '__HEALTH__'=''}
    foreach ($key in $values.Keys) { $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($values[$key])); $script = $script.Replace($key, "'$encoded'") }
    $overrides = @'
$case = '__CASE__'
$log = Join-Path ([IO.Path]::GetDirectoryName($dir)) 'fixture.log'
$events = Join-Path ([IO.Path]::GetDirectoryName($dir)) 'events.txt'
$health = Join-Path ([IO.Path]::GetDirectoryName($dir)) 'health.json'
$startCalls = 0
$helperCalls = 0
function Get-App { @() }
function Stop-Installed { Add-Content $events 'stop' }
function Start-Helper {
  $script:helperCalls++
  if ($case -eq 'service-failure' -and $script:helperCalls -eq 1) { throw 'injected service failure' }
}
function Start-App {
  $script:startCalls++
  Add-Content $events ('start:' + [IO.File]::ReadAllText($exe))
  if ([IO.File]::ReadAllText($exe) -eq 'new app') {
    [IO.File]::WriteAllText((Join-Path $dataDir 'config.json'), 'migrated config')
    [IO.File]::WriteAllText((Join-Path $dataDir 'new-database'), 'new schema')
    if ($case -eq 'launch-failure') { throw 'injected launch failure' }
    [IO.File]::WriteAllText($health, 'fixture')
  }
}
function Wait-AppReady {
  Add-Content $events 'health'
  if ($case -eq 'health-failure') { throw 'injected failed initialization' }
}
function Wait-RestoredApp {
  if ([IO.File]::ReadAllText($exe) -ne 'old app') { throw 'rollback launched the wrong app' }
  Add-Content $events 'restored'
}
function Show-Fail([string]$message) { Add-Content $events ('failure:' + $message) }
function Update-DisplayVersion { Add-Content $events 'version' }
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($health)) -Force | Out-Null
'@
    $overrides = $overrides.Replace('__CASE__', $case)
    $marker = "try {`n  if (-not `$exe.StartsWith"
    Assert ($script.Contains($marker)) 'Main transaction boundary missing'
    $script = $script.Replace($marker, $overrides + "`n" + $marker)
    if ($case -eq 'swap-failure') { $script = $script.Replace('  Move-Item -LiteralPath $stage -Destination $dir', "  throw 'injected stage rename failure'`n  Move-Item -LiteralPath `$stage -Destination `$dir") }
    $file = Join-Path $folder 'run.ps1'
    [IO.File]::WriteAllText($file, $script, [Text.UTF8Encoding]::new($true))
    $lock = $null
    try {
      if ($case -eq 'backup-failure') { $lock = [IO.File]::Open((Join-Path $data 'config.json'), 'Open', 'ReadWrite', 'None') }
      $child = [Diagnostics.Process]::new()
      $child.StartInfo.FileName = Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
      $child.StartInfo.Arguments = '-NoProfile -NonInteractive -File "' + $file + '"'
      $child.StartInfo.UseShellExecute = $false
      $child.StartInfo.RedirectStandardOutput = $true
      $child.StartInfo.RedirectStandardError = $true
      $child.Start() | Out-Null
      if (-not $child.WaitForExit(30000)) { $child.Kill(); throw "Fixture timed out: $case" }
      [IO.File]::WriteAllText((Join-Path $folder 'stdout'), $child.StandardOutput.ReadToEnd())
      [IO.File]::WriteAllText((Join-Path $folder 'stderr'), $child.StandardError.ReadToEnd())
    } finally { if ($lock) { $lock.Dispose() } }
    $events = Get-Content (Join-Path $folder 'events.txt') -Raw -ErrorAction SilentlyContinue
    $stderr = Get-Content (Join-Path $folder 'stderr') -Raw
    if ($case -eq 'success') {
      Assert ($child.ExitCode -eq 0) "Success fixture failed: $stderr $events"
      Assert ([IO.File]::ReadAllText($exe) -eq 'new app') 'New app not installed'
      $backup = @(Get-ChildItem $folder -Directory -Force -Filter '.installed.update-*')[0].FullName + '\previous\Fixture.exe'
      Assert ((FileId $backup) -eq $originalId) 'Original file identity lost in backup'
      Assert ($events -match 'health\s+version') 'Version committed before initialization'
      Assert ([IO.File]::ReadAllText((Join-Path $data 'config.json')) -eq 'migrated config') 'Successful app data rolled back'
      Assert (Test-Path (Join-Path $install 'unins000.dat')) 'Uninstaller lost'
      Assert (-not (Test-Path (Join-Path $install 'old-only.dll'))) 'Obsolete native DLL carried into new app'
    } else {
      Assert ($child.ExitCode -eq 1) "Failure fixture returned success: $case $stderr $events"
      Assert ([IO.File]::ReadAllText($exe) -eq 'old app') "Original app not restored: $case $stderr $events"
      Assert ((FileId $exe) -eq $originalId) "Original file identity changed: $case"
      Assert ([IO.File]::ReadAllText((Join-Path $data 'config.json')) -eq 'original config') "Original user data not restored: $case"
      Assert (-not (Test-Path (Join-Path $data 'new-database'))) "Migrated data survived rollback: $case"
      Assert ($events -notmatch '(?m)^version$') "Failed update changed version: $case"
      Assert ($events -match 'start:old app') "Old app not restarted: $case $stderr $events"
      Assert ($events -notmatch 'recovery failed') "Recovery failed: $case $stderr $events"
    }
    Write-Output "PASS $case"
  }
} finally {
  if ($env:KEEP_BFCLASH_UPDATE_FIXTURES -ne '1') { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue }
  else { Write-Output "Fixtures retained: $testRoot" }
}
