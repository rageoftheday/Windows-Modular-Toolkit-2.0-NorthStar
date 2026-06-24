@echo off
title Toolkit Logger
color 0A
setlocal EnableDelayedExpansion

set logdir=logs
set exportdir=exports

if not exist "%logdir%" (
    mkdir "%logdir%"
)

if not exist "%exportdir%" (
    mkdir "%exportdir%"
)

set toolkitlog=%logdir%\toolkit.log
set errorlog=%logdir%\errors.log
set healthlog=%logdir%\health.log
set cleanuplog=%logdir%\cleanup.log

:menu
cls
echo ============================================================
echo                     TOOLKIT LOGGER
echo ============================================================
echo.
echo [1] View Toolkit Log
echo [2] View Error Log
echo [3] View Health Log
echo [4] View Cleanup Log
echo.
echo [5] Export Toolkit Log
echo [6] Export Error Log
echo [7] Export Health Log
echo [8] Export Cleanup Log
echo.
echo [9] Clear Toolkit Log
echo [10] Clear Error Log
echo [11] Clear Health Log
echo [12] Clear Cleanup Log
echo [13] Clear ALL Logs
echo.
echo [14] Log Statistics
echo [15] Write Test Log Entry
echo [16] Manage Toolkit Log Entries
echo.
echo [EXIT] Return to Main Menu
echo.
echo ============================================================
echo.

set "choice="
set /p choice=Selection: 

if /I "%choice%"=="EXIT" exit /b

if "%choice%"=="1" goto viewtoolkit
if "%choice%"=="2" goto viewerrors
if "%choice%"=="3" goto viewhealth
if "%choice%"=="4" goto viewcleanup

if "%choice%"=="5" goto exporttoolkit
if "%choice%"=="6" goto exporterrors
if "%choice%"=="7" goto exporthealth
if "%choice%"=="8" goto exportcleanup

if "%choice%"=="9" goto cleartoolkit
if "%choice%"=="10" goto clearerrors
if "%choice%"=="11" goto clearhealth
if "%choice%"=="12" goto clearcleanup
if "%choice%"=="13" goto clearall

if "%choice%"=="14" goto logstats
if "%choice%"=="15" goto writetest
if "%choice%"=="16" goto managetoolkit

goto menu

:viewtoolkit
cls
echo ============================================================
echo                     TOOLKIT LOG
echo ============================================================
echo.

if exist "%toolkitlog%" (
    type "%toolkitlog%"
) else (
    echo No toolkit log entries found.
)

echo.
pause
goto menu

:viewerrors
cls
echo ============================================================
echo                      ERROR LOG
echo ============================================================
echo.

if exist "%errorlog%" (
    type "%errorlog%"
) else (
    echo No error log entries found.
)

echo.
pause
goto menu

:viewhealth
cls
echo ============================================================
echo                     HEALTH LOG
echo ============================================================
echo.

if exist "%healthlog%" (
    type "%healthlog%"
) else (
    echo No health log entries found.
)

echo.
pause
goto menu

:viewcleanup
cls
echo ============================================================
echo                    CLEANUP LOG
echo ============================================================
echo.

if exist "%cleanuplog%" (
    type "%cleanuplog%"
) else (
    echo No cleanup log entries found.
)

echo.
pause
goto menu

:exporttoolkit
copy "%toolkitlog%" "%exportdir%\toolkit.log" >nul 2>&1
echo Toolkit log exported.
pause
goto menu

:exporterrors
copy "%errorlog%" "%exportdir%\errors.log" >nul 2>&1
echo Error log exported.
pause
goto menu

:exporthealth
copy "%healthlog%" "%exportdir%\health.log" >nul 2>&1
echo Health log exported.
pause
goto menu

:exportcleanup
copy "%cleanuplog%" "%exportdir%\cleanup.log" >nul 2>&1
echo Cleanup log exported.
pause
goto menu

:cleartoolkit
cls
echo ============================================================
echo                  CLEAR TOOLKIT LOG
echo ============================================================
echo.
echo WARNING:
echo This will erase toolkit.log
echo.

set /p confirm=Type DELETE to confirm: 

if /I not "%confirm%"=="DELETE" goto menu

del /f /q "%toolkitlog%" >nul 2>&1

echo.
echo Toolkit log cleared.
echo.
pause
goto menu

:clearerrors
cls
echo ============================================================
echo                   CLEAR ERROR LOG
echo ============================================================
echo.
echo WARNING:
echo This will erase errors.log
echo.

set /p confirm=Type DELETE to confirm: 

if /I not "%confirm%"=="DELETE" goto menu

del /f /q "%errorlog%" >nul 2>&1

echo.
echo Error log cleared.
echo.
pause
goto menu

:clearhealth
cls
echo ============================================================
echo                  CLEAR HEALTH LOG
echo ============================================================
echo.
echo WARNING:
echo This will erase health.log
echo.

set /p confirm=Type DELETE to confirm: 

if /I not "%confirm%"=="DELETE" goto menu

del /f /q "%healthlog%" >nul 2>&1

echo.
echo Health log cleared.
echo.
pause
goto menu

:clearcleanup
cls
echo ============================================================
echo                 CLEAR CLEANUP LOG
echo ============================================================
echo.
echo WARNING:
echo This will erase cleanup.log
echo.

set /p confirm=Type DELETE to confirm: 

if /I not "%confirm%"=="DELETE" goto menu

del /f /q "%cleanuplog%" >nul 2>&1

echo.
echo Cleanup log cleared.
echo.
pause
goto menu

:clearall
cls
echo ============================================================
echo                    CLEAR ALL LOGS
echo ============================================================
echo.
echo WARNING:
echo This will permanently erase ALL logs.
echo.

set /p confirm=Type DELETEALL to confirm: 

if /I not "%confirm%"=="DELETEALL" goto menu

del /f /q "%logdir%\*.log" >nul 2>&1

echo.
echo All logs cleared successfully.
echo.
pause
goto menu

:logstats
cls
echo ============================================================
echo                    LOG STATISTICS
echo ============================================================
echo.

for %%F in ("%logdir%\*.log") do (

    echo File: %%~nxF
    echo Size: %%~zF bytes
    echo Modified: %%~tF
    echo.
)

pause
goto menu

:writetest
cls
echo ============================================================
echo                  WRITE TEST ENTRY
echo ============================================================
echo.

echo [%date% %time%] TOOLKIT LOGGER TEST ENTRY >> "%toolkitlog%"
echo [%date% %time%] SAMPLE ERROR ENTRY >> "%errorlog%"
echo [%date% %time%] SAMPLE HEALTH ENTRY >> "%healthlog%"
echo [%date% %time%] SAMPLE CLEANUP ENTRY >> "%cleanuplog%"

echo Test log entries written successfully.
echo.
pause
goto menu

:managetoolkit
cls
echo ============================================================
echo              MANAGE TOOLKIT LOG ENTRIES
echo ============================================================
echo.

if not exist "%toolkitlog%" (
    echo No toolkit log found.
    echo.
    pause
    goto menu
)

set linecount=0

for /f "delims=" %%A in (%toolkitlog%) do (
    set /a linecount+=1
    echo [!linecount!] %%A
)

echo.
echo ------------------------------------------------------------
echo [DELETE] Remove Log Entry
echo [BACK] Return
echo ------------------------------------------------------------
echo.

set "action="
set /p action=Selection: 

if /I "%action%"=="BACK" goto menu

if /I not "%action%"=="DELETE" goto managetoolkit

echo.
set /p removeline=Enter line number to remove: 

if "%removeline%"=="" goto managetoolkit

set tempfile=%temp%\toolkitlog_tmp.txt

break > "%tempfile%"

set currentline=0

for /f "delims=" %%A in (%toolkitlog%) do (

    set /a currentline+=1

    if NOT "!currentline!"=="%removeline%" (
        echo %%A>>"%tempfile%"
    )
)

move /y "%tempfile%" "%toolkitlog%" >nul

echo.
echo Selected log entry removed successfully.
echo.
pause
goto managetoolkit


