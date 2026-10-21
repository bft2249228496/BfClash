param([string]$BundlePath = '', [switch]$ExpectBlocked)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$source = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib/common/windows_portable_update.dart') -Raw
$template = [regex]::Match($source, "(?s)const _scriptTemplate = r'''\r?\n(.*?)''';").Groups[1].Value
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($template, [ref]$tokens, [ref]$parseErrors)
$function = $ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-Payload'}, $true)
if (-not $function) { throw 'Production payload preflight missing' }
. ([ScriptBlock]::Create($function.Extent.Text))
function L([string]$message) {}
function Check([string]$folder, [bool]$blocked) {
  $script:stage = $folder
  $rejected = $false
  $detail = ''
  try { Test-Payload } catch { $rejected = $true; $detail = $_.Exception.Message }
  if ($rejected -ne $blocked) { throw "Payload preflight result incorrect: $folder $detail" }
  Write-Output ('PASS payload/' + $(if ($blocked) { 'blocked: ' + $detail } else { 'loadable' }))
}
if ($BundlePath) {
  Check ([IO.Path]::GetFullPath($BundlePath)) $ExpectBlocked.IsPresent
  return
}
$folder = Join-Path ([IO.Path]::GetTempPath()) ('bfclash-payload-fixtures-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $folder | Out-Null
try {
  Copy-Item (Join-Path $env:WINDIR 'System32\version.dll') (Join-Path $folder 'version.dll')
  [IO.File]::WriteAllBytes((Join-Path $folder 'app.so'), [byte[]](0x7f,0x45,0x4c,0x46))
  Check $folder $false
  [IO.File]::WriteAllText((Join-Path $folder 'broken.dll'), 'not an executable image')
  Check $folder $true
} finally { Remove-Item -LiteralPath $folder -Recurse -Force }
