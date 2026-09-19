@echo off
setlocal

if "%~1"=="" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0remove_patch.ps1"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0remove_patch.ps1" -GameRoot "%~1"
)

set "rc=%ERRORLEVEL%"
if not "%rc%"=="0" (
  echo.
  echo Patch removal failed with exit code %rc%.
  pause
)

endlocal & exit /b %rc%
