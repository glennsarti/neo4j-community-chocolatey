@ECHO OFF

powershell "& { Invoke-WebRequest -Uri 'http://nuget.org/nuget.exe' -OutFile '%~dp0nuget.exe' }"

EXIT /B %ERRORLEVEL%