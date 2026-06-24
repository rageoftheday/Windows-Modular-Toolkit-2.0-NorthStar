@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"
set "TOOLKIT_MODULE_EXITCODE=%ERRORLEVEL%"

REM If launched from inside the toolkit, the framework pauses after return.
REM If double-clicked or run directly, pause here so output stays visible.
if /I not "%TOOLKIT_LAUNCHED%"=="1" (
    echo.
    pause
)

endlocal & exit /b %TOOLKIT_MODULE_EXITCODE%
