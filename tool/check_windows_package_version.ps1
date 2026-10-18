param([Parameter(Mandatory=$true)][string]$Executable,[switch]$Beta)
$ErrorActionPreference='Stop'
$build=1000+([int]$env:GITHUB_RUN_NUMBER)*10+([int]$env:GITHUB_RUN_ATTEMPT)
$info=[Diagnostics.FileVersionInfo]::GetVersionInfo((Resolve-Path $Executable))
if($info.FilePrivatePart -ne $build){throw "Packaged build number is wrong: $($info.FilePrivatePart), expected $build"}
if($Beta -and $info.ProductVersion -notmatch "-beta\.$build(?:\+|$)"){throw "Packaged beta version is wrong: $($info.ProductVersion)"}
if(!$Beta -and $info.ProductVersion -match '-beta'){throw 'Stable package contains beta version'}
Write-Output ("Packaged Windows version verified: "+$info.ProductVersion)
