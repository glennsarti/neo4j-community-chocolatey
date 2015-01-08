@ECHO OFF

REM This assumes NUGET.EXE is in the same directory as this script or in the path
REM If not download it from http://nuget.org/nuget.exe or via InstallNuget.bat

SETLOCAL

REM Does string have a trailing slash? if so remove it
SET THISDIR=%~dp0
IF %THISDIR:~-1%==\ SET THISDIR=%THISDIR:~0,-1%

SET SRC=%THISDIR%\..\src
SET ARTEFACTS=%THISDIR%\..\artefacts

PUSHD
CD /D %THISDIR%

ECHO Cleaning the artefact directory
RD /S /Q "%ARTEFACTS%" > NUL
MKDIR "%ARTEFACTS%"

ECHO Getting the package version from various sources
SET PKGVERSION=
IF NOT [%1] == [] SET PKGVERSION=%1
IF NOT [%APPVEYOR_BUILD_VERSION%] == [] SET PKGVERSION=%APPVEYOR_BUILD_VERSION%
ECHO Using package version %PKGVERSION%

IF NOT [%PKGVERSION%] == [] SET PKGVERSION=-Version "%PKGVERSION%"

ECHO Run Nuget Pack
"nuget.exe" pack "%SRC%\PackageTemplate.nuspec" -NonInteractive %PKGVERSION% -NoPackageAnalysis -OutputDirectory "%ARTEFACTS%"

EXIT /B %ERRORLEVEL%
