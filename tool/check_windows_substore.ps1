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
  $body=@{name='bfclash-ci-verification';type='single';source='local';content='ss://YWVzLTEyOC1nY206dGVzdA==@192.0.2.1:8388#verification'}|ConvertTo-Json
  $created=Invoke-RestMethod 'http://127.0.0.1:17391/api/subs' -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 5
  if($created.status -ne 'success'){throw 'Sub-Store local subscription creation failed'}
  $converted=Invoke-WebRequest 'http://127.0.0.1:17391/download/bfclash-ci-verification?target=ClashMeta' -UseBasicParsing -TimeoutSec 10
  if($converted.StatusCode -ne 200 -or $converted.Content -notmatch '192.0.2.1'){throw 'Sub-Store conversion failed'}
  Stop-Process $process.Id -Force
  if(!$process.WaitForExit(5000)){throw 'Sub-Store failed to exit'}
  $process=Start-Process $runtime -ArgumentList ('"'+$backend+'"') -WorkingDirectory $testRoot -PassThru -RedirectStandardOutput "$testRoot/restart-stdout.log" -RedirectStandardError "$testRoot/restart-stderr.log"
  $persisted=$false
  for($i=0;$i -lt 30;$i++) {
    if($process.HasExited){throw 'Sub-Store restart failed'}
    try {$list=Invoke-RestMethod 'http://127.0.0.1:17391/api/subs' -TimeoutSec 1;$persisted=(@($list.data|Where-Object name -eq 'bfclash-ci-verification').Count -eq 1);if($persisted){break}}catch{}
    Start-Sleep -Milliseconds 200
  }
  if(!$persisted){throw 'Sub-Store did not persist the local subscription'}
  Write-Output 'Packaged Sub-Store conversion and restart persistence passed'

} finally {
  if($process -and !$process.HasExited){Stop-Process $process.Id -Force;$process.WaitForExit(5000)|Out-Null}
  Remove-Item Env:SUB_STORE_BACKEND_API_PORT,Env:SUB_STORE_BACKEND_API_HOST,Env:SUB_STORE_DATA_BASE_PATH -ErrorAction SilentlyContinue
  Remove-Item $testRoot -Recurse -Force
}
