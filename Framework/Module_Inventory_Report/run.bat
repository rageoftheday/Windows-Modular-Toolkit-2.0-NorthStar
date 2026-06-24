@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Module Inventory Report
color 0A
cls

cd /d "%~dp0\..\.."

echo ============================================================
echo                MODULE INVENTORY REPORT
echo ============================================================
echo.

set userCount=0
set frameworkCount=0

for /d %%D in (modules\*) do (
    set /a userCount+=1
)

for /d %%D in (Framework\*) do (
    set /a frameworkCount+=1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $raw = Get-Content 'cache\toolkit_registry.json' -Raw | ConvertFrom-Json; $r = @(); if ($raw -is [System.Array]) { $r = @($raw) } elseif ($null -ne $raw) { $r = @($raw) }; $u = @($r | Where-Object { $_.module_scope -ne 'Framework' -and $_.framework_protected -ne $true }); $f = @($r | Where-Object { $_.module_scope -eq 'Framework' -or $_.framework_protected -eq $true }); $cats = @($u | Where-Object { $_.hidden -ne $true } | ForEach-Object { if ($_.PSObject.Properties.Name -contains 'category' -and -not [string]::IsNullOrWhiteSpace([string]$_.category)) { [string]$_.category } } | Sort-Object -Unique); Write-Host ('Framework Components : ' + $f.Count); Write-Host ('User Modules          : ' + $u.Count); Write-Host ('User Categories       : ' + $cats.Count); } catch { Write-Host ('Framework Components : ' + $env:frameworkCount); Write-Host ('User Modules          : ' + $env:userCount); Write-Host 'User Categories       : Unknown'; }"

echo.
echo Toolkit structure scanned successfully.
echo.
echo [B] Back
echo.
set /p choice=Selection: 
if /I "%choice%"=="Q" exit
exit /b 0
