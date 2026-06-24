@echo off
title Validate Modules
color 0B
setlocal EnableDelayedExpansion

set ROOT=%~dp0..\..
cd /d "%ROOT%"
set MODULES=Modules

cls
echo ============================================================
echo                  VALIDATE MODULES
echo ============================================================
echo.

echo Toolkit Root: %CD%
echo Modules Path: %MODULES%
echo.

if not exist "%MODULES%" (
    echo [FAIL] Modules directory not found.
    echo.
    echo [B] Back
    set /p back=Selection: 
    exit /b
)

set total=0
set passed=0
set failed=0

for /d %%D in ("%MODULES%\*") do (
    if /I NOT "%%~nD"=="quarantine" (
        set /a total+=1
        set issues=0
        echo Checking %%~nD

        if not exist "%%D\tool.json" (
            echo   [FAIL] Missing tool.json
            set /a issues+=1
        ) else (
            echo   [PASS] tool.json found
        )

        if exist "%%D\run.ps1" (
            echo   [PASS] launcher found: run.ps1
        ) else if exist "%%D\run.bat" (
            echo   [PASS] launcher found: run.bat
        ) else if exist "%%D\run.cmd" (
            echo   [PASS] launcher found: run.cmd
        ) else (
            echo   [FAIL] Missing launcher ^(run.ps1/run.bat/run.cmd^)
            set /a issues+=1
        )

        if "!issues!"=="0" (
            set /a passed+=1
        ) else (
            set /a failed+=1
        )
        echo.
    )
)

echo ============================================================
echo                VALIDATION COMPLETE
echo ============================================================
echo.
echo Total Modules : %total%
echo Passed        : %passed%
echo Failed        : %failed%
echo.
echo [B] Back
set /p back=Selection: 
exit /b
