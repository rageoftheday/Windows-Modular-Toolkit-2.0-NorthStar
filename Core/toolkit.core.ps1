# ============================================================
# TOOLKIT CORE ENGINE
# ============================================================

# ------------------------------------------------------------
# GLOBAL VARIABLES
# ------------------------------------------------------------

$script:ToolkitVersion = "2.0"
$script:ToolkitRoot = Resolve-Path "$PSScriptRoot\.."

# ------------------------------------------------------------
# WRITE TOOLKIT HEADER
# ------------------------------------------------------------

function Write-ToolkitHeader {

    param(
        [string]$Title = "TOOLKIT"
    )

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    if ($Title -eq "WINDOWS MODULAR TOOLKIT") {
        Write-Host "Framework Edition 2.0" -ForegroundColor Cyan
        Write-Host ""
    }
    Write-Host ""
}


# ------------------------------------------------------------
# COMPATIBILITY: SHOW TOOLKIT HEADER
# ------------------------------------------------------------

function Show-ToolkitHeader {

    param(
        [string]$Title = "TOOLKIT"
    )

    Write-ToolkitHeader $Title
}

# ------------------------------------------------------------
# TOOLKIT STATUS MESSAGE
# ------------------------------------------------------------

function Show-ToolkitStatus {

    param(
        [string]$Status,
        [string]$Message
    )

    switch ($Status.ToUpper()) {
        "OK"   { $Color = "Green" }
        "PASS" { $Color = "Green" }
        "WARN" { $Color = "Yellow" }
        "FAIL" { $Color = "Red" }
        default { $Color = "White" }
    }

    Write-Host "[$Status] $Message" -ForegroundColor $Color
}

# ------------------------------------------------------------
# PAUSE TOOLKIT
# ------------------------------------------------------------

function Pause-Toolkit {

    Write-Host ""
    Read-Host "Press Enter to continue"
}

# ------------------------------------------------------------
# WRITE LOG
# ------------------------------------------------------------

function Write-ToolkitLog {

    param(
        [string]$Message,
        [string]$LogName = "toolkit.log"
    )

    $LogDir = Join-Path $script:ToolkitRoot "logs"

    if (!(Test-Path $LogDir)) {

        New-Item -ItemType Directory -Path $LogDir | Out-Null
    }

    $LogFile = Join-Path $LogDir $LogName

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Add-Content $LogFile "[$Time] $Message"
}

# ------------------------------------------------------------
# TEST ADMIN
# ------------------------------------------------------------

function Test-ToolkitAdmin {

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

# ------------------------------------------------------------
# SHOW ADMIN WARNING
# ------------------------------------------------------------

function Show-AdminWarning {

    Write-Host ""
    Write-Host "[WARNING] Administrator privileges recommended." -ForegroundColor Yellow
    Write-Host ""
}

# ------------------------------------------------------------
# EXPORT DATA
# ------------------------------------------------------------

function Export-ToolkitData {

    param(
        [string]$Name,
        [object]$Data
    )

    $ExportDir = Join-Path $script:ToolkitRoot "exports"

    if (!(Test-Path $ExportDir)) {

        New-Item -ItemType Directory -Path $ExportDir | Out-Null
    }

    $Path = Join-Path $ExportDir "$Name.txt"

    $Data | Out-File $Path

    Write-Host ""
    Write-Host "Exported:"
    Write-Host $Path
    Write-Host ""
}

# ------------------------------------------------------------
# SAFE EXECUTION WRAPPER
# ------------------------------------------------------------

function Invoke-ToolkitSafe {

    param(
        [scriptblock]$Script
    )

    try {

        & $Script

    }
    catch {

        Write-Host ""
        Write-Host "[ERROR]" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""

        Write-ToolkitLog $_.Exception.Message "errors.log"
    }
}


# ============================================================
# COMPATIBILITY HELPERS
# ============================================================

if (-not (Get-Command Show-ToolkitHeader -ErrorAction SilentlyContinue)) {
    function Show-ToolkitHeader {
        param([string]$Title = "TOOLKIT")
        Write-ToolkitHeader $Title
    }
}

if (-not (Get-Command Show-ToolkitStatus -ErrorAction SilentlyContinue)) {
    function Show-ToolkitStatus {
        param(
            [string]$Status,
            [string]$Message
        )

        switch ($Status.ToUpper()) {
            "PASS" { Write-Host "[PASS] $Message" -ForegroundColor Green }
            "WARN" { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
            "FAIL" { Write-Host "[FAIL] $Message" -ForegroundColor Red }
            default { Write-Host "[$Status] $Message" }
        }
    }
}
