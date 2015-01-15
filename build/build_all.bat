@ECHO OFF

SETLOCAL

REM Does string have a trailing slash? if so remove it
SET THISDIR=%~dp0
IF %THISDIR:~-1%==\ SET THISDIR=%THISDIR:~0,-1%

ECHO Cleaning...
CALL "%THISDIR%\build.bat" CLEANONLY

POWERSHELL "& { Get-ChildItem -Path '%THISDIR%\..' | ? { $_.Name -match 'neo4j-'} | ForEach-Object { & '%THISDIR%\build.bat' $_.Name NOCLEAN} }"

EXIT /B %ERRORLEVEL%