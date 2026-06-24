
@echo off
title Duplicate Tool Scanner
color 0E
cls

echo ============================================================
echo               DUPLICATE TOOL SCANNER
echo ============================================================
echo.

setlocal enabledelayedexpansion

for /f "delims=" %%A in ('dir /b /ad modules') do (
    set name=%%A
    call :checkdup "%%A"
)

echo.
echo Duplicate scan completed.
pause
exit

:checkdup
set count=0

for /f "delims=" %%B in ('dir /b /ad modules') do (
    if /I "%%~B"=="%~1" (
        set /a count+=1
    )
)

if !count! GTR 1 (
    echo [WARNING] Duplicate found: %~1
)

exit /b
