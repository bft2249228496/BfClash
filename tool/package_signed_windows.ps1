param(
  [Parameter(Mandatory=$true)][string]$BuildDirectory,
  [Parameter(Mandatory=$true)][string]$WorkDirectory,
  [Parameter(Mandatory=$true)][string]$InstallerScript,
  [Parameter(Mandatory=$true)][string]$OutputBaseName,
  [Parameter(Mandatory=$true)][string]$CoreName,
  [Parameter(Mandatory=$true)][string]$HelperName,
  [Parameter(Mandatory=$true)][string]$ManifestPath,
  [switch]$CreateZip
)
$ErrorActionPreference='Stop'
if($env:BFCLASH_WINDOWS_SIGNING_REQUIRED -cne 'true'){throw 'Trusted signing must be explicitly enabled'}
if($OutputBaseName -notmatch '^BfClash-[a-zA-Z0-9.+-]+-windows-(amd64|arm64)$'){throw 'Invalid output identity'}
$root=Split-Path $PSScriptRoot -Parent
$signer=Join-Path $PSScriptRoot 'sign_windows_binary.ps1'
$compiler=$env:BFCLASH_ISCC
if(!$compiler){$compiler=Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'}
if(!(Test-Path -LiteralPath $compiler -PathType Leaf)){throw 'Inno Setup compiler is unavailable'}
$source=(Resolve-Path -LiteralPath $BuildDirectory).Path
$work=(Resolve-Path -LiteralPath $WorkDirectory).Path
$dist=[IO.Path]::GetFullPath((Join-Path $root 'dist'))
if(!(Split-Path $work -Parent).Equals($dist,[StringComparison]::OrdinalIgnoreCase)){throw 'Staging must be directly inside project dist'}
if(!(Split-Path ([IO.Path]::GetFullPath($InstallerScript)) -Parent).Equals($work,[StringComparison]::OrdinalIgnoreCase)){throw 'Installer script must be inside staging'}
$payload=Join-Path $work 'payload'
New-Item -ItemType Directory -Path $payload|Out-Null
$files=@(Get-ChildItem -LiteralPath $source -Recurse -Force)
if(@($files|Where-Object {($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0}).Count){throw 'Reparse points are not permitted in release payload'}
Copy-Item -Path (Join-Path $source '*') -Destination $payload -Recurse -Force
$manifest=Get-Content -LiteralPath $ManifestPath -Raw|ConvertFrom-Json
$core=Join-Path $payload $CoreName
$helper=Join-Path $payload $HelperName
$runner=if($CoreName -ceq 'BfClashCoreBeta.exe'){'BfClash-Beta.exe'}elseif($CoreName -ceq 'BfClashCore.exe'){'BfClash.exe'}else{throw 'Unknown Core identity'}
$expectedHelper=if($runner -ceq 'BfClash-Beta.exe'){'BfClashHelperServiceBeta.exe'}else{'BfClashHelperService.exe'}
if($HelperName -cne $expectedHelper){throw 'Helper identity does not match Core channel'}
foreach($relative in @($runner,'flutter_windows.dll','data/app.so','node.exe')){
  if(!(Test-Path -LiteralPath (Join-Path $payload $relative) -PathType Leaf)){throw "Required payload is missing: $relative"}
}
foreach($path in @($core,$helper)){if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw 'Core or Helper is missing'}; & $signer -FilePath $path -VerifyOnly}
$coreHash=(Get-FileHash -LiteralPath $core -Algorithm SHA256).Hash.ToLowerInvariant()
if($coreHash -cne $manifest.coreSha256){throw 'Signed Core does not match Helper build manifest'}
function Test-PeFile([string]$Path){
  $stream=[IO.File]::OpenRead($Path)
  $reader=New-Object IO.BinaryReader($stream)
  try {
    if($stream.Length -lt 64 -or $reader.ReadUInt16() -ne 0x5A4D){return $false}
    $stream.Position=60
    $offset=$reader.ReadUInt32()
    if($offset -gt ($stream.Length-4)){return $false}
    $stream.Position=$offset
    return $reader.ReadUInt32() -eq 0x4550
  } finally {$reader.Dispose();$stream.Dispose()}
}
$records=@()
foreach($file in @(Get-ChildItem -LiteralPath $payload -Recurse -File|Where-Object {Test-PeFile $_.FullName})){
  if($file.FullName -ne $core -and $file.FullName -ne $helper){
    $signature=Get-AuthenticodeSignature -LiteralPath $file.FullName
    if($signature.Status -eq 'NotSigned'){& $signer -FilePath $file.FullName}
    elseif($signature.Status -ne 'Valid' -or !$signature.TimeStamperCertificate){throw "Untrusted or untimestamped existing signature: $($file.Name)"}
  }
  $verified=Get-AuthenticodeSignature -LiteralPath $file.FullName
  if($verified.Status -ne 'Valid' -or !$verified.TimeStamperCertificate){throw 'Payload signature verification failed'}
  $records+=@{path=$file.FullName.Substring($payload.Length+1);sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant();publisher=$verified.SignerCertificate.Subject}
}
if((Get-FileHash -LiteralPath $core -Algorithm SHA256).Hash.ToLowerInvariant() -cne $coreHash){throw 'Core was modified after Helper compilation'}
$receiptDirectory=Join-Path $work 'receipts'
New-Item -ItemType Directory -Path $receiptDirectory|Out-Null
$toolCommand='powershell.exe -NoProfile -NonInteractive -File $q'+$signer+'$q -FilePath $f -ReceiptDirectory $q'+$receiptDirectory+'$q'
& $compiler '/Q' '/DBFCLASH_TRUSTED_PAYLOAD' (('/SbfclashTrusted=')+$toolCommand) $InstallerScript
if($LASTEXITCODE -ne 0){throw 'Signed installer compilation failed'}
$installer=Join-Path $work ($OutputBaseName+'-setup.exe')
& $signer -FilePath $installer -VerifyOnly
$installerHash=(Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
$receipts=@(Get-ChildItem -LiteralPath $receiptDirectory -Filter '*.json' -File|ForEach-Object {Get-Content -LiteralPath $_.FullName -Raw|ConvertFrom-Json})
if(!@($receipts|Where-Object {$_.verified -eq $true -and $_.sha256 -ceq $installerHash}).Count){throw 'Installer signing receipt is missing'}
if(!@($receipts|Where-Object {$_.verified -eq $true -and $_.sha256 -cne $installerHash}).Count){throw 'Inno uninstaller signing callback evidence is missing'}
$products=@($installer)
if($CreateZip){
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip=Join-Path $work ($OutputBaseName+'.zip')
  [IO.Compression.ZipFile]::CreateFromDirectory($payload,$zip,[IO.Compression.CompressionLevel]::Optimal,$false)
  $products+=@($zip)
}
$artifactRecords=@()
foreach($file in $products){$artifactRecords+=@{name=[IO.Path]::GetFileName($file);sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}}
$proof=@{coreSha256=$coreHash;payload=$records;artifacts=$artifactRecords;trustedSigning=$true;innoSigningCallbacks=$receipts;deviceStartupVerified=$false}
$proofPath=Join-Path $work ($OutputBaseName+'-signature-verification.json')
$proof|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $proofPath -Encoding UTF8
foreach($file in @($products)+@($proofPath)){Move-Item -LiteralPath $file -Destination (Join-Path $dist ([IO.Path]::GetFileName($file))) -Force}
