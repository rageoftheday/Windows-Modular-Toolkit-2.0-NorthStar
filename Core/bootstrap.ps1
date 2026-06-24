# ============================================================
# TOOLKIT BOOTSTRAP
# ============================================================

$Global:ToolkitRoot = Resolve-Path "$PSScriptRoot\.."

# ------------------------------------------------------------
# LOAD CORE FILES SAFELY
# ------------------------------------------------------------

$CoreFiles = @(
    "display.engine.ps1",
    "toolkit.core.ps1",
    "settings.engine.ps1",
    "dependency.engine.ps1",
    "module.api.ps1",
    "module.loader.ps1",
    "framework.integrity.ps1"
)

foreach ($File in $CoreFiles) {

    $Path = Join-Path $Global:ToolkitRoot "core\$File"

    if (Test-Path $Path) {
        . $Path
    }
    else {
        Write-Host ""
        Write-Host "[BOOTSTRAP ERROR] Missing core file:" -ForegroundColor Red
        Write-Host $Path -ForegroundColor Red
        Write-Host ""
        Read-Host "Press Enter to continue"
        exit
    }
}

# ------------------------------------------------------------
# LOAD SETTINGS IF AVAILABLE
# ------------------------------------------------------------

try {
    $Global:ToolkitSettings = Get-ToolkitSettings
}
catch {
    $Global:ToolkitSettings = $null
}

# ------------------------------------------------------------
# DEBUG MODE
# ------------------------------------------------------------

if ($Global:ToolkitSettings -and $Global:ToolkitSettings.runtime.debug_mode) {
    Write-Host ""
    Write-Host "[DEBUG] Bootstrap Loaded" -ForegroundColor Yellow
    Write-Host ""
}

# ------------------------------------------------------------
# LOAD MENU ENGINE IF AVAILABLE
# ------------------------------------------------------------

$MenuEngine = Join-Path $Global:ToolkitRoot "core\menu.engine.ps1"

if (Test-Path $MenuEngine) {
    . $MenuEngine
}