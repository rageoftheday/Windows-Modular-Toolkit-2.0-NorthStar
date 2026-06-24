$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"
# ============================================================
# BOOTSTRAP INTEGRATION MANAGER
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "BOOTSTRAP INTEGRATION MANAGER" `
    -RequiresAdmin $false `
    -ScriptBlock {

    $ModulesPath = Join-Path $Root "modules"
    $BackupPath  = Join-Path $Root "backup\bootstrap_integration"

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

            if ($Content -match "bootstrap\.ps1") {
                Write-Host "  [SKIP] Already uses bootstrap" -ForegroundColor Yellow
                $Skipped++
                Write-Host ""
                return
            }

            $ModuleBackup = Join-Path $BackupPath $Module.Name

            if (!(Test-Path $ModuleBackup)) {
                New-Item -ItemType Directory -Path $ModuleBackup | Out-Null
            }

            Copy-Item $RunPs1 (Join-Path $ModuleBackup "run.ps1.bak") -Force

            $Content = $Content -replace '(?m)^\s*\.\s+"\$Root\\core\\toolkit\.core\.ps1"\s*\r?\n?', ''
            $Content = $Content -replace '(?m)^\s*\.\s+"\$Root\\core\\settings\.engine\.ps1"\s*\r?\n?', ''
            $Content = $Content -replace '(?m)^\s*\.\s+"\$Root\\core\\dependency\.engine\.ps1"\s*\r?\n?', ''
            $Content = $Content -replace '(?m)^\s*\.\s+"\$Root\\core\\module\.api\.ps1"\s*\r?\n?', ''
            $Content = $Content -replace '(?m)^\s*\.\s+"\$Root\\core\\module\.loader\.ps1"\s*\r?\n?', ''

            if ($Content -notmatch '\$Root\s*=\s*Resolve-Path\s+"\$PSScriptRoot\\\.\.\\\.\."') {
                $Content = '$Root = Resolve-Path "$PSScriptRoot\..\.."' + "`r`n`r`n" + $Content
            }

            $BootstrapLine = '. "$Root\core\bootstrap.ps1"'

            $Content = $Content -replace '(?m)(^\s*\$Root\s*=\s*Resolve-Path\s+"\$PSScriptRoot\\\.\.\\\.\."\s*$)', "`$1`r`n`r`n$BootstrapLine"

            Set-Content $RunPs1 $Content -Encoding UTF8

            Write-Host "  [PASS] Converted to bootstrap" -ForegroundColor Green
            $Updated++
        }
        catch {
            Write-Host "  [FAIL] $($_.Exception.Message)" -ForegroundColor Red
            $Errors++
        }

        Write-Host ""
    }

    Write-Host "============================================================"
    Write-Host " BOOTSTRAP INTEGRATION COMPLETE"
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
