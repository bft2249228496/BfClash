$ErrorActionPreference='Stop'
$compiler=Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'
if(!(Test-Path $compiler)){throw 'Inno Setup compiler is unavailable'}
$testRoot=Join-Path $env:RUNNER_TEMP ('bfclash-uninstall-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $testRoot|Out-Null
function RunFixture([string]$File,[string]$Arguments){
  $child=Start-Process $File -ArgumentList $Arguments -PassThru
  if(!$child.WaitForExit(30000)){Stop-Process -Id $child.Id -Force;throw 'Installer fixture timed out'}
  return $child.ExitCode
}
$previousMarker=$env:BFCLASH_UNINSTALL_TEST_MARKER
try {
  @'
cmake_minimum_required(VERSION 3.14)
project(HelperFixture LANGUAGES CXX)
add_executable(Helper helper.cpp)
'@|Set-Content "$testRoot/CMakeLists.txt"
  @'
#include <cstdlib>
#include <fstream>
#include <string>
int main(int argc, char** argv) {
  if (argc != 2 || std::string(argv[1]) != "uninstall") return 2;
  const char* marker = std::getenv("BFCLASH_UNINSTALL_TEST_MARKER");
  if (!marker) return 3;
  std::ofstream(marker, std::ios::app) << "uninstall\n";
  return 0;
}
'@|Set-Content "$testRoot/helper.cpp"
  & cmake -S $testRoot -B "$testRoot/build"
  if($LASTEXITCODE -ne 0){throw 'Helper fixture configure failed'}
  & cmake --build "$testRoot/build" --config Release
  if($LASTEXITCODE -ne 0){throw 'Helper fixture build failed'}
  $template=Get-Content 'windows/packaging/exe/inno_setup.iss' -Raw
  $code=($template -split '\[Code\]',2)[1] -split '\[Languages\]',2|Select-Object -First 1
  $code=$code.Replace('{{HELPER_SERVICE_EXECUTABLE_NAME}}','Helper.exe')
  $blockedInstall=Join-Path $testRoot 'policy-blocked'
  $blockedMarker=Join-Path $testRoot 'policy-blocked-marker.txt'
  $env:BFCLASH_UNINSTALL_TEST_MARKER=$blockedMarker
  $blockedCode=[regex]::Replace($code, '(?s)if RegQueryDWordValue\(HKLM,.*?\(PolicyState = 1\) then', 'if True then')
  if($blockedCode -eq $code){throw 'Policy fixture failed to replace the registry read'}
  $blockedScript=@"
[Setup]
AppId=BfClashPolicyFixture
AppName=BfClash Policy Fixture
AppVersion=1.0
DefaultDirName=$blockedInstall
PrivilegesRequired=lowest
CreateUninstallRegKey=no
OutputDir=$testRoot
OutputBaseFilename=policy-blocked-setup
[Files]
Source: "$testRoot\build\Release\Helper.exe"; DestDir: "{app}"
[CustomMessages]
UnsignedPayloadBlocked=Unsigned payload blocked before installation.
[Code]
$blockedCode
"@
  $trustedSettings=[regex]::Match($template,'(?s)#ifdef BFCLASH_TRUSTED_PAYLOAD\s+SignTool=.*?#endif').Value
  if(!$trustedSettings){throw 'Trusted installer settings are missing'}
  $trustedFixture=$blockedScript.Replace('[Files]', $trustedSettings+"`n[Files]")
  $trustedFixture|Set-Content "$testRoot/trusted-without-signer.iss" -Encoding UTF8
  & $compiler /Q /DBFCLASH_TRUSTED_PAYLOAD "$testRoot/trusted-without-signer.iss" 2>&1|Out-Host
  if($LASTEXITCODE -eq 0){throw 'Trusted installer compiled without its required signing tool'}
  if(Test-Path "$testRoot/policy-blocked-setup.exe"){throw 'Unsigned output escaped trusted compilation'}
  Write-Output 'Trusted installer cannot compile without its signing backend'
  $blockedScript|Set-Content "$testRoot/policy-blocked.iss" -Encoding UTF8
  & $compiler /Q "$testRoot/policy-blocked.iss"
  if($LASTEXITCODE -ne 0){throw 'Policy fixture compile failed'}
  $exitCode=RunFixture "$testRoot/policy-blocked-setup.exe" '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
  if($exitCode -eq 0){throw 'Enforcing policy did not reject unsigned installation'}
  if(Test-Path "$blockedInstall/Helper.exe"){throw 'Blocked installer changed app files'}
  if(Test-Path $blockedMarker){throw 'Blocked installer removed Helper'}
  Write-Output 'Enforcing policy rejects unsigned payload before file or Helper changes'
  foreach($cancel in @($true,$false)){
    $label=if($cancel){'cancel'}else{'confirmed'}
    $install=Join-Path $testRoot $label
    $marker=Join-Path $testRoot "$label-marker.txt"
    $env:BFCLASH_UNINSTALL_TEST_MARKER=$marker
    $script=@"
[Setup]
AppId=BfClashUninstallFixture-$label
AppName=BfClash Uninstall Fixture
AppVersion=1.0
DefaultDirName=$install
PrivilegesRequired=lowest
CreateUninstallRegKey=no
Uninstallable=yes
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
OutputDir=$testRoot
OutputBaseFilename=$label-setup
[Files]
Source: "$testRoot\build\Release\Helper.exe"; DestDir: "{app}"
[CustomMessages]
UnsignedPayloadBlocked=Unsigned payload blocked before installation.
[Code]
$code
"@
    if($cancel){$script+="`nfunction InitializeUninstall(): Boolean;`nbegin`n  Result := False;`nend;`n"}
    $script|Set-Content "$testRoot/$label.iss" -Encoding UTF8
    & $compiler /Q "$testRoot/$label.iss"
    if($LASTEXITCODE -ne 0){throw 'Installer fixture compile failed'}
    $exitCode=RunFixture "$testRoot/$label-setup.exe" '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
    if($exitCode -ne 0){throw "Fixture install failed: $exitCode"}
    if(Test-Path $marker){throw 'Helper was removed during first installation'}
    $exitCode=RunFixture "$install/unins000.exe" '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
    if($cancel){
      if(Test-Path $marker){throw 'Cancelled uninstall removed the Helper'}
      if(!(Test-Path "$install/Helper.exe")){throw 'Cancelled uninstall removed app files'}
      Write-Output 'Cancelled uninstall preserves Helper and app files'
    }else{
      if($exitCode -ne 0){throw "Confirmed uninstall failed: $exitCode"}
      if(!(Test-Path $marker)){throw 'Confirmed uninstall did not remove Helper'}
      if(@(Get-Content $marker).Count -ne 1){throw 'Helper uninstall called more than once'}
      if(Test-Path "$install/Helper.exe"){throw 'Confirmed uninstall retained app files'}
      Write-Output 'Confirmed uninstall removes Helper exactly once before deleting files'
    }
  }
}finally{
  $env:BFCLASH_UNINSTALL_TEST_MARKER=$previousMarker
  if(Test-Path $testRoot){Remove-Item $testRoot -Recurse -Force}
}
