@echo off
setlocal
cd /d "%~dp0"

echo Installing the Strinova Korean localization patch...
set "PATCH_POWERSHELL=powershell.exe"
where pwsh.exe >nul 2>nul
if not errorlevel 1 set "PATCH_POWERSHELL=pwsh.exe"

"%PATCH_POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_patch.ps1"
set "PATCH_EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%PATCH_EXIT_CODE%"=="0" (
    echo Installation failed. Check the message above.
) else (
    echo Installation completed successfully.
)
echo.
pause
exit /b %PATCH_EXIT_CODE%
