$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"
# ============================================================
# TOOLKIT UPGRADE MANAGER
# ============================================================

Clear-Host

$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
Set-Location $Root

$ModulesPath = Join-Path $Root "modules"
$BackupPath = Join-Path $Root "backup"

# ------------------------------------------------------------
# LOAD TOOLKIT CORE
# ------------------------------------------------------------
Write-ToolkitHeader "TOOLKIT UPGRADE MANAGER"

# ------------------------------------------------------------
# CREATE BACKUP FOLDER
# ------------------------------------------------------------

if (!(Test-Path $BackupPath)) {

    New-Item -ItemType Directory -Path $BackupPath | Out-Null
}

# ------------------------------------------------------------
# STANDARD BAT LAUNCHER
# ------------------------------------------------------------

$StandardLauncher = @'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"
'@

# ------------------------------------------------------------
# CORE LOADER BLOCK
# ------------------------------------------------------------

$CoreLoader = @'
$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
'@

# ------------------------------------------------------------
# PROCESS MODULES
# ------------------------------------------------------------

$Updated = 0
$Skipped = 0
$Errors = 0

Get-ChildItem $ModulesPath -Directory | ForEach-Object {

    $Module = $_
    $ModuleName = $Module.Name

    $RunPs1 = Join-Path $Module.FullName "run.ps1"
    $RunBat = Join-Path $Module.FullName "run.bat"

    Write-Host "Processing: $ModuleName"

    # --------------------------------------------------------
    # ONLY PROCESS MODULES WITH run.ps1
    # --------------------------------------------------------

    if (!(Test-Path $RunPs1)) {

        Write-Host "  [SKIP] No PowerShell backend found" -ForegroundColor Yellow
        $Skipped++
        Write-Host ""
        return
    }

    try {

        # ----------------------------------------------------
        # BACKUP ORIGINAL FILES
        # ----------------------------------------------------

        $ModuleBackup = Join-Path $BackupPath $ModuleName

        if (!(Test-Path $ModuleBackup)) {

            New-Item -ItemType Directory -Path $ModuleBackup | Out-Null
        }

        Copy-Item $RunPs1 "$ModuleBackup\run.ps1.bak" -Force

        if (Test-Path $RunBat) {

            Copy-Item $RunBat "$ModuleBackup\run.bat.bak" -Force
        }

        # ----------------------------------------------------
        # READ EXISTING PS1 CONTENT
        # ----------------------------------------------------

        $Ps1Content = Get-Content $RunPs1 -Raw

        # ----------------------------------------------------
        # INJECT CORE LOADER IF MISSING
        # ----------------------------------------------------

        if ($Ps1Content -notmatch "toolkit\.core\.ps1") {

            $Ps1Content = $CoreLoader + "`r`n" + $Ps1Content

            Set-Content $RunPs1 $Ps1Content

            Write-Host "  [PASS] Core loader injected" -ForegroundColor Green

        } else {

            Write-Host "  [PASS] Core loader already exists" -ForegroundColor Green
        }

        # ----------------------------------------------------
        # REBUILD BAT LAUNCHER
        # ----------------------------------------------------

        Set-Content $RunBat $StandardLauncher

        Write-Host "  [PASS] BAT launcher upgraded" -ForegroundColor Green

        # ----------------------------------------------------
        # COMPLETE
        # ----------------------------------------------------

        $Updated++

    }
    catch {

        Write-Host "  [FAIL] $_" -ForegroundColor Red

        $Errors++
    }

    Write-Host ""
}

# ------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------

Write-Host "============================================================"
Write-Host "                 UPGRADE COMPLETE"
Write-Host "============================================================"
Write-Host ""

Write-Host "Updated Modules : $Updated"
Write-Host "Skipped Modules : $Skipped"
Write-Host "Errors Found    : $Errors"

Write-Host ""
Write-Host "Backup Location:"
Write-Host $BackupPath

Write-Host ""

Write-Host "[B] Back"
do { $BackChoice = (Read-Host "Selection").Trim().ToUpper() } until ($BackChoice -eq "B")



