@echo off
title Dynamic Toolkit Launcher
color 0B
setlocal EnableDelayedExpansion

set ROOT=%~dp0..\..
cd /d "%ROOT%"

set modulesdir=modules

:menu
cls
echo ============================================================
echo                 DYNAMIC TOOLKIT LAUNCHER
echo ============================================================
echo.

set count=0

for /d %%D in ("%modulesdir%\*") do (

    set modname=%%~nD

    if /I NOT "!modname!"=="quarantine" (

        set /a count+=1

        set module!count!=%%~fD
        set modulename!count!=!modname!

        echo [!count!] !modname!
    )
)

echo.
echo ============================================================
echo.
echo [S] Search Modules
echo [R] Refresh
echo [B] Back
echo.
echo ============================================================
echo.

set "choice="
set /p choice=Selection: 

if /I "%choice%"=="Q" exit /b
if /I "%choice%"=="B" exit /b

if /I "%choice%"=="R" goto menu

if /I "%choice%"=="S" goto search

REM ============================================================
REM VALIDATE SELECTION
REM ============================================================

set selected=

for /L %%N in (1,1,%count%) do (

    if "%choice%"=="%%N" (
        set selected=!module%%N!
        set selectedname=!modulename%%N!
    )
)

if not defined selected goto menu

goto launch

:launch
cls
echo ============================================================
echo                    LAUNCHING MODULE
echo ============================================================
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

    REM ============================================================
    REM ADMIN WARNING
    REM ============================================================

    findstr /I "\"requires_admin\": true" "%selected%\tool.json" >nul 2>&1

    if not errorlevel 1 (
        echo [NOTICE] This module may require Administrator privileges.
        echo.
    )
)

echo Module: %selectedname%
echo Path  : %selected%
echo.
echo ============================================================
echo.

REM ============================================================
REM LAUNCHER VALIDATION
REM ============================================================

if not exist "%selected%\run.bat" (
    if not exist "%selected%\run.ps1" (
        echo [FAIL] No launcher found for this module.
        echo.
        pause
        goto menu
    )
)

echo [L] Launch Module
echo [B] Back to Menu
echo.

set "launchchoice="
set /p launchchoice=Selection: 

if /I "%launchchoice%"=="B" goto menu

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
    goto menu
)

if exist "%selected%\run.ps1" (

    echo [INFO] Launching PowerShell module...
    echo.

    powershell -NoProfile -ExecutionPolicy Bypass -File "%selected%\run.ps1"

    echo.
    pause
    goto menu
)

echo [FAIL] No launcher found
echo.
pause
goto menu

:search
cls
echo ============================================================
echo                     SEARCH MODULES
echo ============================================================
echo.

set "searchterm="
echo [B] Back
echo.
set /p searchterm=Enter search term: 

if /I "%searchterm%"=="B" goto menu
if "%searchterm%"=="" goto menu

cls
echo ============================================================
echo                    SEARCH RESULTS
echo ============================================================
echo.

set found=0
set resultcount=0

for /d %%D in ("%modulesdir%\*") do (

    set modname=%%~nD

    echo !modname! | find /I "%searchterm%" >nul

    if not errorlevel 1 (

        set /a found+=1
        set /a resultcount+=1

        set result!resultcount!=%%~fD
        set resultname!resultcount!=!modname!

        echo [!resultcount!] !modname!
    )
)

if "!found!"=="0" (

    echo No matching modules found.
    echo.
    pause
    goto menu
)

echo.
echo ============================================================
echo.
echo [B] Back
echo.
echo ============================================================
echo.

set "searchchoice="
set /p searchchoice=Selection: 

if /I "%searchchoice%"=="B" goto menu

set selected=

for /L %%N in (1,1,!resultcount!) do (

    if "%searchchoice%"=="%%N" (
        set selected=!result%%N!
        set selectedname=!resultname%%N!
    )
)

if not defined selected goto search

goto launch
