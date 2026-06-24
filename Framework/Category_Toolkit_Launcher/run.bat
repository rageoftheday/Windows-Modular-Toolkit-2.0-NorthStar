@echo off
title Category Toolkit Launcher
color 0B
setlocal EnableDelayedExpansion

set ROOT=%~dp0..\..
cd /d "%ROOT%"

set modulesdir=modules

:mainmenu
cls
echo ============================================================
echo                CATEGORY TOOLKIT LAUNCHER
echo ============================================================
echo.

echo [1] Cleanup and Optimization
echo [2] Diagnostics
echo [3] Network and Internet
echo [4] Windows Repair
echo [5] Setup and Install
echo [6] Toolkit Management
echo [7] Advanced Tools
echo [8] Custom Tools
echo [9] Show ALL Modules
echo.
echo [B] Back
echo.
echo ============================================================
echo.

set "catchoice="
set /p catchoice=Selection: 

if /I "%catchoice%"=="B" exit /b
if /I "%catchoice%"=="Q" exit /b

if "%catchoice%"=="1" set selectedcategory=Cleanup and Optimization
if "%catchoice%"=="2" set selectedcategory=Diagnostics
if "%catchoice%"=="3" set selectedcategory=Network and Internet
if "%catchoice%"=="4" set selectedcategory=Windows Repair
if "%catchoice%"=="5" set selectedcategory=Setup and Install
if "%catchoice%"=="6" set selectedcategory=Toolkit Management
if "%catchoice%"=="7" set selectedcategory=Advanced Tools
if "%catchoice%"=="8" set selectedcategory=Custom Tools
if "%catchoice%"=="9" set selectedcategory=ALL

if not defined selectedcategory goto mainmenu

goto loadmodules

REM ============================================================
REM LOAD MODULES
REM ============================================================

:loadmodules
cls

echo ============================================================
echo                    MODULE LIST
echo ============================================================
echo.

echo Category: %selectedcategory%
echo.

set count=0

for /d %%D in ("%modulesdir%\*") do (

    set modname=%%~nD

    if /I NOT "!modname!"=="quarantine" (

        set showmodule=0

        if /I "%selectedcategory%"=="ALL" (
            set showmodule=1
        )

        if exist "%%D\tool.json" (

            findstr /I /C:"\"category\": \"%selectedcategory%\"" "%%D\tool.json" >nul 2>&1

            if not errorlevel 1 (
                set showmodule=1
            )
        )

        if "!showmodule!"=="1" (

            set /a count+=1

            set module!count!=%%~fD
            set modulename!count!=!modname!

            echo [!count!] !modname!
        )
    )
)

if "%count%"=="0" (

    echo No modules found in this category.
    echo.
    pause
    goto mainmenu
)

echo.
echo ============================================================
echo.
echo [B] Back
echo [M] Main Menu
echo.
echo ============================================================
echo.

set "choice="
set /p choice=Selection: 

if /I "%choice%"=="B" goto mainmenu
if /I "%choice%"=="M" goto mainmenu
if /I "%choice%"=="Q" exit /b

set selected=

for /L %%N in (1,1,%count%) do (

    if "%choice%"=="%%N" (
        set selected=!module%%N!
        set selectedname=!modulename%%N!
    )
)

if not defined selected goto loadmodules

goto launch

REM ============================================================
REM LAUNCH MODULE
REM ============================================================

:launch
cls

echo ============================================================
echo                    MODULE DETAILS
echo ============================================================
echo.

echo Module: %selectedname%
echo Path  : %selected%
echo.

if exist "%selected%\tool.json" (

    echo MODULE INFORMATION
    echo ------------------------------------------------------------

    for /f "tokens=1,* delims=:" %%A in ('findstr /I ^
    /C:"\"description\"" ^
    /C:"\"category\"" ^
    /C:"\"risk\"" ^
    /C:"\"estimated_time\"" ^
    /C:"\"requires_admin\"" ^
    /C:"\"supports_logs\"" ^
    /C:"\"supports_export\"" ^
    "%selected%\tool.json"') do (

        set line=%%A:%%B

        set line=!line:"=!
        set line=!line:,=!

        echo !line!
    )

    echo.
)

findstr /I "\"requires_admin\": true" "%selected%\tool.json" >nul 2>&1

if not errorlevel 1 (

    echo [NOTICE] This module may require Administrator privileges.
    echo.
)

echo ============================================================
echo.
echo [L] Launch Module
echo [B] Back
echo [M] Main Menu
echo.
echo ============================================================
echo.

set "launchchoice="
set /p launchchoice=Selection: 

if /I "%launchchoice%"=="B" goto loadmodules
if /I "%launchchoice%"=="M" goto mainmenu

if /I not "%launchchoice%"=="L" goto launch

echo.
echo ============================================================
echo.

if exist "%selected%\run.bat" (

    echo [INFO] Launching batch module...
    echo.

    call "%selected%\run.bat"

    echo.
    pause
    goto loadmodules
)

if exist "%selected%\run.ps1" (

    echo [INFO] Launching PowerShell module...
    echo.

    powershell -NoProfile -ExecutionPolicy Bypass -File "%selected%\run.ps1"

    echo.
    pause
    goto loadmodules
)

echo [FAIL] No launcher found
echo.
pause
goto loadmodules

