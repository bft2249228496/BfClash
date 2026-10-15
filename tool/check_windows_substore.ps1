param([Parameter(Mandatory=$true)][string]$BundlePath)
$ErrorActionPreference='Stop'
$runtime=Join-Path $BundlePath 'node.exe'
$backend=Join-Path $BundlePath 'data/substore/2.39.8/sub-store.bundle.js'
if(!(Test-Path $runtime) -or !(Test-Path $backend)){throw 'Sub-Store package is incomplete'}
$testRoot=Join-Path $env:RUNNER_TEMP ('bfclash-substore-'+[guid]::NewGuid())
New-Item -ItemType Directory $testRoot|Out-Null
$env:SUB_STORE_BACKEND_API_PORT='17391'
$env:SUB_STORE_BACKEND_API_HOST='127.0.0.1'
$env:SUB_STORE_DATA_BASE_PATH=$testRoot
$process=$null
try {
  $process=Start-Process $runtime -ArgumentList ('"'+$backend+'"') -WorkingDirectory $testRoot -PassThru -RedirectStandardOutput "$testRoot/stdout.log" -RedirectStandardError "$testRoot/stderr.log"
  $ready=$false
  for($i=0;$i -lt 30;$i++) {
    if($process.HasExited){throw 'Packaged Sub-Store exited before ready'}
    try {$response=Invoke-WebRequest 'http://127.0.0.1:17391/api/utils/env' -UseBasicParsing -TimeoutSec 1;if($response.StatusCode -eq 200 -and ($response.Content|ConvertFrom-Json).status -eq 'success'){$ready=$true;break}}catch{}
    Start-Sleep -Milliseconds 200
  }
  if(!$ready){throw 'Packaged Sub-Store health check failed'}
  Write-Output 'Packaged Sub-Store health check passed'
} finally {
  if($process -and !$process.HasExited){Stop-Process $process.Id -Force}
  Remove-Item Env:SUB_STORE_BACKEND_API_PORT,Env:SUB_STORE_BACKEND_API_HOST,Env:SUB_STORE_DATA_BASE_PATH -ErrorAction SilentlyContinue
  Remove-Item $testRoot -Recurse -Force
}
