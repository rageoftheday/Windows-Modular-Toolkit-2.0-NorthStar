# ============================================================
# TOOLKIT HEALTH CENTER
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "TOOLKIT HEALTH CENTER" `
    -RequiresAdmin $false `
    -ScriptBlock {

    Show-ToolkitHeader "TOOLKIT HEALTH CENTER"

    Write-Host "Checking toolkit health..."
    Write-Host ""

    $RegistryPath = Join-Path $Root "cache\toolkit_registry.json"
    $ModulesPath = Join-Path $Root "modules"
    $CorePath = Join-Path $Root "core"
    $LogPath = Join-Path $Root "logs"

    if (Test-Path $RegistryPath) { Write-Host "[PASS] Registry exists." -ForegroundColor Green }
    else { Write-Host "[FAIL] Registry missing." -ForegroundColor Red }

    if (Test-Path $ModulesPath) { Write-Host "[PASS] Modules folder exists." -ForegroundColor Green }
    else { Write-Host "[FAIL] Modules folder missing." -ForegroundColor Red }

    if (Test-Path $CorePath) { Write-Host "[PASS] Core folder exists." -ForegroundColor Green }
    else { Write-Host "[FAIL] Core folder missing." -ForegroundColor Red }

    if (Test-Path $LogPath) { Write-Host "[PASS] Logs folder exists." -ForegroundColor Green }
    else { Write-Host "[WARN] Logs folder missing." -ForegroundColor Yellow }

    Write-Host ""
    Write-Host "Health check complete."

    # 39D_STANDARD_BACK_PAUSE
    Write-Host ""
    Write-Host "[B] Back"
    do { $BackChoice = (Read-Host "Selection").Trim().ToUpper() } until ($BackChoice -eq "B")
}
