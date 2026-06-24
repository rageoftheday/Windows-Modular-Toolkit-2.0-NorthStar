$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
# ============================================================
# WINDOWS MODULAR TOOLKIT
# Check Winget
# ============================================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "Checking Winget availability..." -ForegroundColor Cyan
Write-Host ""

$WingetCommand = Get-Command winget.exe -ErrorAction SilentlyContinue

if ($null -eq $WingetCommand) {
    Write-Host "[ERROR] winget is not available on this machine." -ForegroundColor Red
    Write-Host ""
    Write-Host "Winget usually requires Windows 10 1809+ or Windows 11."
    Write-Host "Install or update App Installer from the Microsoft Store."
    Write-Host "Microsoft link: https://aka.ms/getwinget"
    Write-Host ""
    exit 1
}

Write-Host "[OK] winget found:" -ForegroundColor Green
Write-Host "     $($WingetCommand.Source)"
Write-Host ""

try {
    $Version = (& winget --version) 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($Version)) {
        Write-Host "Version: $Version" -ForegroundColor Green
    }
    else {
        Write-Host "[WARN] winget exists, but version check returned exit code $LASTEXITCODE." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[WARN] winget exists, but could not be tested." -ForegroundColor Yellow
    Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "Winget check complete."


