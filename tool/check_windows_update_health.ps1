$ErrorActionPreference = 'Stop'
$source = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib/common/windows_portable_update.dart') -Raw
$template = [regex]::Match($source, "(?s)const _scriptTemplate = r'''\r?\n(.*?)''';").Groups[1].Value
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($template, [ref]$tokens, [ref]$parseErrors)
$function = $ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Wait-AppReady'}, $true)
if (-not $function) { throw 'Production health gate missing' }
. ([ScriptBlock]::Create($function.Extent.Text))
$folder = Join-Path ([IO.Path]::GetTempPath()) ('bfclash-health-fixtures-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $folder | Out-Null
$health = Join-Path $folder 'health.json'
$nonce = '0123456789abcdef0123456789abcdef'
$version = '1.0.1-beta.1911'
function L([string]$message) {}
function Start-Sleep { param($Milliseconds, $Seconds) }
function Get-Date { $script:tick++; [DateTime]::new(2026,10,21).AddSeconds($script:tick * 20) }
function Get-App {
  $script:reads++
  if ($case -eq 'dead' -or ($case -eq 'dies-after-ready' -and $script:reads -gt 1)) { return @() }
  @([PSCustomObject]@{Id=1234})
}
try {
  foreach ($case in @('ready', 'wrong-nonce', 'wrong-version', 'wrong-pid', 'wrong-protocol', 'dead', 'dies-after-ready', 'no-ack', 'malformed')) {
    $script:tick = 0; $script:reads = 0
    $ack = @{nonce=$nonce; version=$version; processId=1234; protocol=2}
    if ($case -eq 'wrong-nonce') { $ack.nonce = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' }
    if ($case -eq 'wrong-version') { $ack.version = '1.0.0-beta.1871' }
    if ($case -eq 'wrong-protocol') { $ack.protocol = 1 }
    if ($case -eq 'wrong-pid') { $ack.processId = 9999 }
    $ack | ConvertTo-Json | Set-Content -LiteralPath $health -Encoding UTF8
    if ($case -eq 'no-ack') { Remove-Item -LiteralPath $health }
    if ($case -eq 'malformed') { Set-Content -LiteralPath $health -Value 'not json' }
    $accepted = $false
    try { Wait-AppReady; $accepted = $true } catch {}
    if ($accepted -ne ($case -eq 'ready')) { throw "Health gate outcome incorrect: $case" }
    Write-Output "PASS health/$case"
  }
} finally { Remove-Item -LiteralPath $folder -Recurse -Force }
