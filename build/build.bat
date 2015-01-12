@ECHO OFF

REM This assumes NUGET.EXE is in the same directory as this script or in the path
REM If not download it from http://nuget.org/nuget.exe or via InstallNuget.bat

SETLOCAL

REM Does string have a trailing slash? if so remove it
SET THISDIR=%~dp0
IF %THISDIR:~-1%==\ SET THISDIR=%THISDIR:~0,-1%

SET PKGNAME=%1
IF [%PKGNAME%] == [] (
  ECHO Missing package name
  EXIT /B 255
)

SET SRC=%THISDIR%\..\%PKGNAME%
SET ARTEFACTS=%THISDIR%\..\artefacts

IF NOT EXIST "%SRC%\PackageTemplate.nuspec" (
  ECHO Package %SRC%\PackageTemplate.nuspec does not exist
  EXIT /B 255
)


PUSHD
CD /D %THISDIR%

ECHO Cleaning the artefact directory
RD /S /Q "%ARTEFACTS%" > NUL
MKDIR "%ARTEFACTS%"

ECHO Getting the package version from various sources
SET PKGVERSION=
IF NOT [%2] == [] SET PKGVERSION=%2
IF NOT [%APPVEYOR_BUILD_VERSION%] == [] SET PKGVERSION=%APPVEYOR_BUILD_VERSION%
ECHO Using package version %PKGVERSION%

IF NOT [%PKGVERSION%] == [] SET PKGVERSION=-Version "%PKGVERSION%"

ECHO Run Nuget Pack for "%PKGNAME%\PackageTemplate.nuspec"
"nuget.exe" pack "%SRC%\PackageTemplate.nuspec" -NonInteractive %PKGVERSION% -NoPackageAnalysis -OutputDirectory "%ARTEFACTS%"

POPD

EXIT /B %ERRORLEVEL%
