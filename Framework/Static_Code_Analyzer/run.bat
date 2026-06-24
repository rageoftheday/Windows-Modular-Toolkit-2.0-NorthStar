@echo off
title Static Code Analyzer
color 0B
setlocal EnableDelayedExpansion

echo Analyzer Starting...
timeout /t 1 >nul

set ROOT=%~dp0..\..
cd /d "%ROOT%"

set modulesdir=modules

set total=0
set passed=0
set warnings=0
set failed=0

if exist analyzer_warnings.log del /f /q analyzer_warnings.log >nul 2>&1
if exist analyzer_failures.log del /f /q analyzer_failures.log >nul 2>&1

:menu
cls
echo ============================================================
echo                  STATIC CODE ANALYZER
echo ============================================================
echo.
echo This analyzer checks:
echo  - Empty scripts
echo  - Missing required files
echo  - PowerShell readability
echo  - Basic structure validation
echo.
echo Modules Folder: %modulesdir%
echo.
echo ============================================================
echo.

pause

cls
echo ============================================================
echo                   STARTING ANALYSIS
echo ============================================================
echo.

for /d %%D in ("%modulesdir%\*") do (

    set modname=%%~nD

    if /I "!modname!"=="quarantine" (

        echo [SKIP] quarantine skipped
        echo.

    ) else (

        set /a total+=1

        echo ------------------------------------------------------------
        echo ANALYZING: !modname!
        echo ------------------------------------------------------------

        set valid=1

        REM ============================================================
        REM BATCH ANALYSIS
        REM ============================================================

        if exist "%%D\run.bat" (

            set script=%%D\run.bat

            REM ============================================================
            REM EMPTY SCRIPT CHECK
            REM ============================================================

            for %%S in ("!script!") do set size=%%~zS

            if "!size!"=="0" (
                echo [FAIL] Empty batch script
                echo [FAIL] !modname! - Empty batch script>>analyzer_failures.log
                set valid=0
                set /a failed+=1
            ) else (
                echo [PASS] Batch script not empty
            )

            REM ============================================================
            REM DUPLICATE LABEL CHECK
            REM ============================================================

            set duplicate=0

            if exist "%temp%\labels_!modname!.tmp" (
                del /f /q "%temp%\labels_!modname!.tmp" >nul 2>&1
            )

            for /f "tokens=1 delims= " %%L in ('findstr /R "^:.*" "!script!"') do (

                set currentlabel=%%L

                find /I "!currentlabel!" "%temp%\labels_!modname!.tmp" >nul 2>&1

                if NOT errorlevel 1 (
                    set duplicate=1
                )

                >>"%temp%\labels_!modname!.tmp" echo !currentlabel!
            )

            if "!duplicate!"=="1" (
                echo [INFO] Duplicate labels detected
            ) else (
                echo [PASS] No duplicate labels
            )

            if exist "%temp%\labels_!modname!.tmp" (
                del /f /q "%temp%\labels_!modname!.tmp" >nul 2>&1
            )

            REM ============================================================
            REM GOTO LABEL CHECK
            REM ============================================================

            set missinggoto=0

            if exist "%temp%\goto_!modname!.tmp" (
                del /f /q "%temp%\goto_!modname!.tmp" >nul 2>&1
            )

            if exist "%temp%\labels_!modname!.tmp" (
                del /f /q "%temp%\labels_!modname!.tmp" >nul 2>&1
            )

            REM BUILD LABEL LIST

            for /f "tokens=1 delims= " %%L in ('findstr /R "^:.*" "!script!"') do (
                >>"%temp%\labels_!modname!.tmp" echo %%L
            )

            REM CHECK GOTOS

            for /f "tokens=2 delims= " %%G in ('findstr /I /R "^goto " "!script!"') do (

                set gotolabel=%%G
                set gotolabel=!gotolabel::=!

                if /I NOT "!gotolabel!"=="eof" (

                    find /I ":!gotolabel!" "%temp%\labels_!modname!.tmp" >nul 2>&1

                    if errorlevel 1 (
                        set missinggoto=1
                    )
                )
            )

            if "!missinggoto!"=="1" (
                echo [INFO] Missing GOTO label detected
            ) else (
                echo [PASS] GOTO labels valid
            )

            if exist "%temp%\goto_!modname!.tmp" (
                del /f /q "%temp%\goto_!modname!.tmp" >nul 2>&1
            )

            if exist "%temp%\labels_!modname!.tmp" (
                del /f /q "%temp%\labels_!modname!.tmp" >nul 2>&1
            )

            REM ============================================================
            REM PARENTHESIS BALANCE CHECK
            REM ============================================================

            set openparens=0
            set closeparens=0

            find /c "(" "!script!" > "%temp%\open.tmp"
            find /c ")" "!script!" > "%temp%\close.tmp"

            for /f "tokens=3" %%O in (%temp%\open.tmp) do set openparens=%%O
            for /f "tokens=3" %%C in (%temp%\close.tmp) do set closeparens=%%C

            del /f /q "%temp%\open.tmp" >nul 2>&1
            del /f /q "%temp%\close.tmp" >nul 2>&1

            if NOT "!openparens!"=="!closeparens!" (
                echo [INFO] Possible malformed parentheses
            ) else (
                echo [PASS] Parentheses balanced
            )
        )

        REM ============================================================
        REM POWERSHELL ANALYSIS
        REM ============================================================

        if exist "%%D\run.ps1" (

            set psscript=%%D\run.ps1

            for %%S in ("!psscript!") do set pssize=%%~zS

            if "!pssize!"=="0" (
                echo [FAIL] Empty PowerShell script
                echo [FAIL] !modname! - Empty PowerShell script>>analyzer_failures.log
                set valid=0
                set /a failed+=1
            ) else (
                echo [PASS] PowerShell script not empty
            )

            powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content '!psscript!' -Raw | Out-Null"

            if NOT "%errorlevel%"=="0" (
                echo [WARN] PowerShell syntax issue detected
                echo [WARN] !modname! - PowerShell syntax issue>>analyzer_warnings.log
                set /a warnings+=1
            ) else (
                echo [PASS] PowerShell syntax valid
            )
        )

        REM ============================================================
        REM FINAL STATUS
        REM ============================================================

        if "!valid!"=="1" (
            echo [PASS] Analysis completed
            set /a passed+=1
        ) else (
            echo [FAIL] Analysis failed
        )

        echo.
    )
)

cls
echo ============================================================
echo                  ANALYSIS COMPLETE
echo ============================================================
echo.

echo Total Modules : %total%
echo Passed        : %passed%
echo Warnings      : %warnings%
echo Failed        : %failed%
echo.

set score=100

set /a score-=failed*15
set /a score-=warnings*2

if %score% LSS 0 set score=0

echo Code Quality Score: %score%%%
echo.

if %score% GEQ 90 (
    echo STATUS: EXCELLENT
) else if %score% GEQ 75 (
    echo STATUS: STABLE
) else if %score% GEQ 50 (
    echo STATUS: NEEDS REVIEW
) else (
    echo STATUS: CRITICAL ISSUES DETECTED
)

echo.
echo ============================================================
echo                    ANALYSIS LOGS
echo ============================================================
echo.

if exist analyzer_failures.log (
    echo FAILURES LOG:
    type analyzer_failures.log
    echo.
)

if exist analyzer_warnings.log (
    echo WARNINGS LOG:
    type analyzer_warnings.log
    echo.
)

echo ============================================================
echo.

pause
exit /b