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

REM Clearout the artefacts dir except if NOCLEAN is specified
SET ARTEFACTS=%THISDIR%\..\artefacts
IF NOT [%2] == [NOCLEAN] (
  ECHO Cleaning the artefact directory
  RD /S /Q "%ARTEFACTS%" > NUL
)
MKDIR "%ARTEFACTS%" 2> NUL

REM If the package name is CLEANONLY then exit with success.  This is just used to clean the artefacts out.  Useful in batch build operations
IF [%PKGNAME%] == [CLEANONLY] (
  EXIT /B 0
)

REM Sanity checks...
SET SRC=%THISDIR%\..\%PKGNAME%

IF NOT EXIST "%SRC%\PackageTemplate.nuspec" (
  ECHO Package %SRC%\PackageTemplate.nuspec does not exist
  EXIT /B 255
)

PUSHD "%ARTEFACTS%"

REM Start the build process...
REM Package version ALWAYS comes from the nuspec file
choco pack "%SRC%\PackageTemplate.nuspec"

POPD

EXIT /B %ERRORLEVEL%
