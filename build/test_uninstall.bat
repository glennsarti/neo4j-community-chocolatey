@ECHO OFF

SETLOCAL
REM Does string have a trailing slash? if so remove it
SET THISDIR=%~dp0
IF %THISDIR:~-1%==\ SET THISDIR=%THISDIR:~0,-1%

SET PKGNAME=%1
IF [%PKGNAME%] == [] (
  ECHO Missing package name
) ELSE (
  ECHO Uninstalling %PKGNAME% ...
  choco uninstall %PKGNAME% -debug -source "%THISDIR%\..\artefacts"
)
