$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"
# ============================================================
# HEADER NORMALIZATION MANAGER
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "HEADER NORMALIZATION MANAGER" `
    -RequiresAdmin $false `
    -ScriptBlock {

    $ModulesPath = Join-Path $Root "modules"
    $BackupPath  = Join-Path $Root "backup\header_normalization"

    if (!(Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath | Out-Null
    }

    $Updated = 0
    $Skipped = 0
    $Errors = 0

    Get-ChildItem $ModulesPath -Directory | ForEach-Object {

        $Module = $_
        $RunPs1 = Join-Path $Module.FullName "run.ps1"

        Write-Host "Processing: $($Module.Name)"

        if (!(Test-Path $RunPs1)) {

            Write-Host "  [SKIP] No run.ps1 found" -ForegroundColor Yellow
            $Skipped++
            Write-Host ""
            return
        }

        try {

            $Content = Get-Content $RunPs1 -Raw

            # ------------------------------------------------
            # BACKUP
            # ------------------------------------------------

            $ModuleBackup = Join-Path $BackupPath $Module.Name

            if (!(Test-Path $ModuleBackup)) {
                New-Item -ItemType Directory -Path $ModuleBackup | Out-Null
            }

            Copy-Item `
                $RunPs1 `
                (Join-Path $ModuleBackup "run.ps1.bak") `
                -Force

            # ------------------------------------------------
            # REMOVE OLD ROOT + CORE IMPORTS
            # ------------------------------------------------

            $Content = $Content -replace '(?ms)^\$Root\s*=\s*Resolve-Path.*?module\.loader\.ps1"\s*', ''

            # ------------------------------------------------
            # NEW STANDARD HEADER
            # ------------------------------------------------

            $Header = @'
$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"

'@

            $Content = $Header + $Content.TrimStart()

            # ------------------------------------------------
            # SAVE
            # ------------------------------------------------

            Set-Content `
                $RunPs1 `
                $Content `
                -Encoding UTF8

            Write-Host "  [PASS] Header normalized" -ForegroundColor Green

            $Updated++
        }
        catch {

            Write-Host "  [FAIL] $($_.Exception.Message)" -ForegroundColor Red

            $Errors++
        }

        Write-Host ""
    }

    Write-Host "============================================================"
    Write-Host " HEADER NORMALIZATION COMPLETE"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "Updated : $Updated"
    Write-Host "Skipped : $Skipped"
    Write-Host "Errors  : $Errors"
    Write-Host ""
    Write-Host "Backups:"
    Write-Host $BackupPath
    Write-Host ""

    # 39D_STANDARD_BACK_PAUSE
    Write-Host ""
    Write-Host "[B] Back"
    do { $BackChoice = (Read-Host "Selection").Trim().ToUpper() } until ($BackChoice -eq "B")
}
