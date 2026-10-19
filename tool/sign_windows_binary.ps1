param(
  [Parameter(Mandatory=$true)][string]$FilePath,
  [switch]$VerifyOnly
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if($env:BFCLASH_WINDOWS_SIGNING_REQUIRED -ne 'true'){throw 'Trusted signing was not explicitly enabled'}
if(!(Test-Path -LiteralPath $FilePath -PathType Leaf)){throw 'Signing target does not exist'}
foreach($name in @('BFCLASH_SIGNTOOL','BFCLASH_SIGNING_DLIB','BFCLASH_SIGNING_METADATA')){
  $value=[Environment]::GetEnvironmentVariable($name)
  if(!$value -or !(Test-Path -LiteralPath $value -PathType Leaf)){throw "Missing signing input: $name"}
}
if(!$env:BFCLASH_SIGNER_SUBJECT){throw 'Expected publisher subject is required'}
$metadata=Get-Content -LiteralPath $env:BFCLASH_SIGNING_METADATA -Raw|ConvertFrom-Json
$endpoint=[uri]$metadata.Endpoint
if($endpoint.Scheme -ne 'https' -or !$endpoint.Host.EndsWith('.codesigning.azure.net') -or $endpoint.Port -ne 443 -or $endpoint.UserInfo -or $endpoint.Query -or $endpoint.Fragment -or !$metadata.CodeSigningAccountName -or !$metadata.CertificateProfileName){throw 'Invalid Artifact Signing metadata'}
if(!$VerifyOnly){
  & $env:BFCLASH_SIGNTOOL sign /fd SHA256 /td SHA256 /tr 'http://timestamp.acs.microsoft.com' /dlib $env:BFCLASH_SIGNING_DLIB /dmdf $env:BFCLASH_SIGNING_METADATA $FilePath
  if($LASTEXITCODE -ne 0){throw 'Trusted signing failed; unsigned output is not accepted'}
}
& $env:BFCLASH_SIGNTOOL verify /pa /all $FilePath
if($LASTEXITCODE -ne 0){throw 'Authenticode verification failed'}
$signature=Get-AuthenticodeSignature -LiteralPath $FilePath
if($signature.Status -ne 'Valid' -or !$signature.SignerCertificate -or !$signature.TimeStamperCertificate){throw 'A trusted timestamped signature is required'}
if($signature.SignerCertificate.Subject -cne $env:BFCLASH_SIGNER_SUBJECT){throw 'Signing publisher differs from the authorized publisher'}
if($signature.SignerCertificate.PublicKey.Oid.Value -ne '1.2.840.113549.1.1.1'){throw 'Smart App Control signing requires the configured RSA identity'}
Write-Output 'Trusted signature and publisher verified'
