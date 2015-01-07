@ECHO OFF

SETLOCAL
REM Does string have a trailing slash? if so remove it
SET THISDIR=%~dp0
IF %THISDIR:~-1%==\ SET THISDIR=%THISDIR:~0,-1%

SET PKGPARAMS=
IF NOT [%1] == [] SET PKGPARAMS=-packageParameters "%*"

REM ECHO Installing...
choco install neo4jcommunity -Force -source "%THISDIR%\..\artefacts" -debug %PKGPARAMS%
