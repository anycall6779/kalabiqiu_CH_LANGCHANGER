@echo off
setlocal
echo ========================================
echo   Strinova Korean Patch 26SP5
echo ========================================
echo Auto-detecting the game folder...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_patch.ps1"
set "rc=%ERRORLEVEL%"
echo.
if "%rc%"=="0" (
  echo [OK] Patch installation completed.
) else (
  echo [FAILED] Patch failed with exit code %rc%.
  echo.
)
echo.
pause
endlocal & exit /b %rc%
