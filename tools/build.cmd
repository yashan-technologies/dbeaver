@echo off
setlocal EnableExtensions

set "scriptDir=%~dp0"
set "workspaceDir=%scriptDir%..\.."
set "dbeaverCommonDir=%workspaceDir%\dbeaver-common"
set "productDir=%workspaceDir%\dbeaver\product"
set "aggregateDir=%productDir%\aggregate"
set "communityTargetDir=%productDir%\community\target"
set "productRootDir=%communityTargetDir%\products\org.jkiss.dbeaver.core.product"
set "releasePackageDir=%communityTargetDir%\release-packages"

if "%RELEASE_VERSION%"=="" set "RELEASE_VERSION=%GITHUB_REF_NAME%"
if "%RELEASE_VERSION%"=="" set "RELEASE_VERSION=latest"
if /I "%RELEASE_VERSION:~0,1%"=="v" set "RELEASE_VERSION=%RELEASE_VERSION:~1%"

if not exist "%productDir%" (
    echo Error: Product directory not found at "%productDir%"
    exit /b 1
)

if not exist "%dbeaverCommonDir%" (
    echo Cloning dbeaver-common repository...
    git clone https://github.com/dbeaver/dbeaver-common.git "%dbeaverCommonDir%"
    if errorlevel 1 exit /b 1
) else (
    echo DBeaver common directory already exists at "%dbeaverCommonDir%"
)

echo Starting Maven build...
call "%dbeaverCommonDir%\mvnw.cmd" %MAVEN_ARGS% clean install -Pproduct-dbeaver-ce,product-dbeaver-eclipse-ce,appstore -T 1C -f "%aggregateDir%"
if errorlevel 1 exit /b 1

echo Build completed successfully
echo Packaging release products...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$productRootDir = [IO.Path]::GetFullPath('%productRootDir%');" ^
  "$releasePackageDir = [IO.Path]::GetFullPath('%releasePackageDir%');" ^
  "$releaseVersion = '%RELEASE_VERSION%';" ^
  "if (Test-Path -LiteralPath $releasePackageDir) { Remove-Item -LiteralPath $releasePackageDir -Recurse -Force }" ^
  "New-Item -ItemType Directory -Path $releasePackageDir | Out-Null;" ^
  "function Assert-ProductDir([string] $path) { if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw ('Product directory not found: ' + $path) } }" ^
  "function New-ZipPackage([string] $sourceDir, [string] $archiveName) { Assert-ProductDir $sourceDir; Compress-Archive -LiteralPath $sourceDir -DestinationPath (Join-Path $releasePackageDir $archiveName) -Force }" ^
  "function New-TarGzPackage([string] $sourceDir, [string] $archiveName) { Assert-ProductDir $sourceDir; $parentDir = Split-Path -Parent $sourceDir; $rootDir = Split-Path -Leaf $sourceDir; & tar.exe -C $parentDir -czf (Join-Path $releasePackageDir $archiveName) $rootDir; if ($LASTEXITCODE -ne 0) { throw ('tar failed for ' + $sourceDir) } }" ^
  "New-ZipPackage (Join-Path $productRootDir 'win32\win32\x86_64\dbeaver') ('dbeaver-ce-' + $releaseVersion + '-win32.win32.x86_64.zip');" ^
  "New-ZipPackage (Join-Path $productRootDir 'win32\win32\aarch64\dbeaver') ('dbeaver-ce-' + $releaseVersion + '-win32.win32.aarch64.zip');" ^
  "New-TarGzPackage (Join-Path $productRootDir 'linux\gtk\x86_64\dbeaver') ('dbeaver-ce-' + $releaseVersion + '-linux.gtk.x86_64.tar.gz');" ^
  "New-TarGzPackage (Join-Path $productRootDir 'linux\gtk\aarch64\dbeaver') ('dbeaver-ce-' + $releaseVersion + '-linux.gtk.aarch64.tar.gz');" ^
  "New-TarGzPackage (Join-Path $productRootDir 'macosx\cocoa\x86_64\DBeaver.app') ('dbeaver-ce-' + $releaseVersion + '-macosx.cocoa.x86_64.tar.gz');" ^
  "New-TarGzPackage (Join-Path $productRootDir 'macosx\cocoa\aarch64\DBeaver.app') ('dbeaver-ce-' + $releaseVersion + '-macosx.cocoa.aarch64.tar.gz');" ^
  "$packages = Get-ChildItem -LiteralPath $releasePackageDir -File | Where-Object { $_.Name -like '*.zip' -or $_.Name -like '*.tar.gz' };" ^
  "if ($packages.Count -ne 6) { throw ('Expected 6 release packages, found ' + $packages.Count) }" ^
  "Write-Host ('Release packages created in ' + $releasePackageDir);" ^
  "$packages | Sort-Object Name | Format-Table -AutoSize Name,Length"
if errorlevel 1 exit /b 1

endlocal
