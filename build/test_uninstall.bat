@ECHO OFF

SETLOCAL
REM Does string have a trailing slash? if so remove it
SET THISDIR=%~dp0
IF %THISDIR:~-1%==\ SET THISDIR=%THISDIR:~0,-1%

ECHO Uninstalling...
choco uninstall neo4j-community -debug
