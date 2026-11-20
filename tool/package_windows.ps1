<#
.SYNOPSIS
  Builds and packages the Serlink Windows release.

.DESCRIPTION
  Produces, in build\dist\windows:
    Serlink-<version>-windows-x64.zip        portable bundle
    Serlink-<version>-windows-x64-setup.exe  Inno Setup installer
    SHA256SUMS-windows-x64.txt

  Requires Flutter, the Visual Studio C++ desktop workload and Inno Setup 6
  (ISCC.exe on PATH or in Program Files). Run from any directory.

.EXAMPLE
  pwsh tool/package_windows.ps1
  pwsh tool/package_windows.ps1 -Version 1.2.0-beta.1 -BuildNumber 7
#>
[CmdletBinding()]
param(
  # Display version, e.g. 1.2.0 or 1.2.0-beta.1. Defaults to pubspec.yaml.
  [string]$Version,
  # Windows file version build component. Defaults to pubspec.yaml.
  [int]$BuildNumber = -1,
  # Package an existing build\windows\x64\runner\Release bundle.
  [switch]$SkipBuild,
  [switch]$SkipInstaller
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $root

$pubspecVersion = (Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$pubspecName, $pubspecBuild = $pubspecVersion -split '\+', 2
if (-not $Version) { $Version = $pubspecName }
if ($BuildNumber -lt 0) { $BuildNumber = if ($pubspecBuild) { [int]$pubspecBuild } else { 0 } }
if ($BuildNumber -gt 65535) { throw "BuildNumber $BuildNumber exceeds the Windows file version limit (65535)." }

# Windows file versions are numeric; keep any pre-release label for names only.
if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$') {
  throw "Version '$Version' is not semantic (expected MAJOR.MINOR.PATCH[-label])."
}
$buildName = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
$fileVersion = "$buildName.$BuildNumber"
$baseName = "Serlink-$Version-windows-x64"

Write-Host "Serlink $Version (file version $fileVersion)"

if (-not $SkipBuild) {
  flutter build windows --release `
    --build-name=$buildName `
    --build-number=$BuildNumber `
    --dart-define=SERLINK_DISTRIBUTION=direct
  if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed.' }
}

$bundle = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path $bundle)) { throw "Release bundle not found at $bundle." }

# Fail on a bundle that would not start on a clean Windows install.
$required = @(
  'serlink.exe',
  'flutter_windows.dll',
  'flutter_pty.dll',
  'vcruntime140.dll',
  'vcruntime140_1.dll',
  'msvcp140.dll',
  'data\app.so',
  'data\icudtl.dat',
  'data\flutter_assets'
)
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $bundle $_)) })
if (-not (Get-ChildItem $bundle -Filter '*sqlite3*.dll' -ErrorAction SilentlyContinue)) {
  $missing += 'sqlite3 native library (*sqlite3*.dll)'
}
if ($missing.Count -gt 0) {
  throw "Release bundle is incomplete. Missing: $($missing -join ', ')"
}

$dist = Join-Path $root 'build\dist\windows'
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Path $dist | Out-Null

# Portable zip with a top-level Serlink folder.
$staging = Join-Path ([IO.Path]::GetTempPath()) "serlink-package-$([Guid]::NewGuid())"
$stagedApp = Join-Path $staging 'Serlink'
New-Item -ItemType Directory -Path $stagedApp -Force | Out-Null
Copy-Item -Path (Join-Path $bundle '*') -Destination $stagedApp -Recurse
Copy-Item -Path LICENSE, NOTICE -Destination $stagedApp
$zip = Join-Path $dist "$baseName.zip"
Compress-Archive -Path $stagedApp -DestinationPath $zip -CompressionLevel Optimal
Remove-Item $staging -Recurse -Force
Write-Host "Created $zip"

if (-not $SkipInstaller) {
  $iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
  if (-not $iscc) {
    $iscc = @(
      "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
      "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
      "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
  }
  if (-not $iscc) { throw 'Inno Setup 6 (ISCC.exe) was not found. Install it or pass -SkipInstaller.' }

  & $iscc /Qp `
    "/DAppVersion=$Version" `
    "/DFileVersion=$fileVersion" `
    "/DSourceDir=$bundle" `
    "/DOutputDir=$dist" `
    "/DOutputBaseName=$baseName-setup" `
    (Join-Path $root 'windows\installer\serlink.iss')
  if ($LASTEXITCODE -ne 0) { throw 'Inno Setup failed.' }
  Write-Host "Created $(Join-Path $dist "$baseName-setup.exe")"
}

$sums = Get-ChildItem $dist -File | Sort-Object Name | ForEach-Object {
  "$((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $($_.Name)"
}
$sums | Set-Content -Path (Join-Path $dist 'SHA256SUMS-windows-x64.txt') -Encoding ascii
$sums | ForEach-Object { Write-Host $_ }
