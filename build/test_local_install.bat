@ECHO OFF

SETLOCAL
REM Does string have a trailing slash? if so remove it
SET THISDIR=%~dp0
IF %THISDIR:~-1%==\ SET THISDIR=%THISDIR:~0,-1%

SET PKGNAME=%1
IF [%PKGNAME%] == [] (
  ECHO Missing package name
  EXIT /B 255
)

SET PKGPARAMS=
IF NOT [%2] == [] SET PKGPARAMS=-packageParameters "%2 %3 %4 %3 %5 %6 %7 %8 %9"

ECHO Installing (%PKGPARAMS%)...
choco install %PKGNAME% -source "%THISDIR%\..\artefacts" -debug %PKGPARAMS%
