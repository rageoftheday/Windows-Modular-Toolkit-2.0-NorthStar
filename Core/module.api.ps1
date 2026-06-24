# ============================================================
# TOOLKIT MODULE API
# ============================================================

function Invoke-ToolkitModule {

    param(
        [string]$ModuleName,
        [scriptblock]$ScriptBlock,
        [bool]$RequiresAdmin = $false
    )

    Write-ToolkitHeader $ModuleName
    Write-ToolkitLog "Launching module: $ModuleName"

    # Usage tracking is disabled for Framework Edition 2.0.
    # Runtime/error logs are still kept for troubleshooting.

    if (Get-Command Invoke-ToolkitSmartWarning -ErrorAction SilentlyContinue) {
        Invoke-ToolkitSmartWarning $ModuleName
    }

    # --------------------------------------------------------
    # ADMIN CHECK (AUTO-ELEVATE)
    # --------------------------------------------------------

    if ($RequiresAdmin -and !(Test-ToolkitAdmin)) {

        Write-Host ""
        Write-Host "[ELEVATING] Requesting Administrator privileges..." -ForegroundColor Cyan
        Write-Host ""

        $Caller = $MyInvocation.PSCommandPath

        if (-not $Caller) {
            Write-Host "[FAIL] Unable to determine calling script." -ForegroundColor Red
            return
        }

        $CallerFolder = Split-Path -Path $Caller -Parent
        $SafeCaller = $Caller.Replace("'", "''")
        $SafeCallerFolder = $CallerFolder.Replace("'", "''")

        # Keep elevated module windows visible and run from the module's own folder.
        # Use -EncodedCommand so paths with spaces are handled correctly.
        $ElevatedCommand = @"
Set-Location -LiteralPath '$SafeCallerFolder'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$SafeCaller'
Write-Host ''
Read-Host 'Press Enter to close elevated module window'
"@

        $EncodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ElevatedCommand))

        Start-Process `
            -FilePath "powershell.exe" `
            -Verb RunAs `
            -WorkingDirectory $CallerFolder `
            -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$EncodedCommand)

        return
    }

    # --------------------------------------------------------
    # LOGGING SETUP
    # --------------------------------------------------------

    $RuntimeLog = Join-Path $Root "logs\runtime.log"

    if (!(Test-Path "$Root\logs")) {
        New-Item -ItemType Directory -Path "$Root\logs" | Out-Null
    }

    $Start = Get-Date
    Add-Content $RuntimeLog "[START] [$ModuleName] $(Get-Date)"

    try {

        & $ScriptBlock

        $End = Get-Date
        $Duration = [math]::Round(($End - $Start).TotalSeconds, 2)

        Write-ToolkitLog "Completed module: $ModuleName in $Duration seconds"
        Add-Content $RuntimeLog "[SUCCESS] [$ModuleName] Duration=$Duration Seconds"

        if ($Global:ToolkitSuppressCompletion -eq $true) {
            $Global:ToolkitSuppressCompletion = $false
            return
        }

        # Post-change validation is now manual from Toolkit Management.
        # Normal navigation/back actions should return cleanly without fake success prompts.
        # Individual tools are responsible for displaying their own completion messages when useful.
    }
    catch {

        Write-Host ""
        Write-Host "[MODULE ERROR]" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""

        Write-ToolkitLog $_.Exception.Message "errors.log"
        Add-Content $RuntimeLog "[FAILED] [$ModuleName] $($_.Exception.Message)"
    }

    # Framework Edition 2.0 standard:
    # Do not auto-pause after every module. Interactive framework tools handle their own [B] Back screens.
    # Direct-launch .bat wrappers may pause if needed for standalone use.
}

# ============================================================
# SMART WARNINGS
# ============================================================

function Invoke-ToolkitSmartWarning {

    param(
        [string]$ModuleName
    )

    $RegistryPath = Join-Path $Root "cache\toolkit_registry.json"

    if (!(Test-Path $RegistryPath)) {
        return
    }

    $Registry = Get-ToolkitRegistry $RegistryPath

    if ($Registry -isnot [System.Collections.IEnumerable]) {
        $Registry = @($Registry)
    }

    $CurrentModule = $Registry |
        Where-Object { $_.name -eq $ModuleName } |
        Select-Object -First 1

    if (-not $CurrentModule) {
        return
    }

    $Warnings = @()

    if ($CurrentModule.requires_admin -eq $true) {
        $Warnings += "This tool requires administrator privileges."
    }

    switch -Regex ($ModuleName) {
        "DISM|System File Checker|SFC" {
            $Warnings += "Windows repair tools can take several minutes. Do not close the window while running."
        }
        "Check Disk Fix|chkdsk|Disk Fix" {
            $Warnings += "Disk repair may require a reboot or locked-volume scheduling."
        }
        "Clear|Cleanup|Recycle|Temporary|Prefetch|Windows Update Cache" {
            $Warnings += "Cleanup tools may remove cached or temporary files."
        }
        "Winget|RSAT|Psmod|Install|Setup" {
            $Warnings += "Install/setup tools may download packages or change installed components."
        }
        "WMI|Repair|Reset|Restart|Service" {
            $Warnings += "Repair/reset tools may restart services or change system configuration."
        }
        "Network Reset|Net Reset|Adapter Reset|Winsock" {
            $Warnings += "Network reset tools may temporarily interrupt connectivity."
        }
        "Dangerous|Threats|Defender|Firewall|FW" {
            $Warnings += "Security tools may read protected system data or change security configuration."
        }
    }

    if ($CurrentModule.risk -eq "Dangerous") {
        $Warnings += "Risk level is Dangerous. Review the output carefully."
    }

    $Warnings = @($Warnings | Select-Object -Unique)

    if ($Warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Important before running:" -ForegroundColor Yellow

        foreach ($Warning in $Warnings) {
            Write-Host " - $Warning" -ForegroundColor Yellow
        }

        Write-Host ""
    }
}

# ============================================================
# POST-CHANGE WORKFLOW
# ============================================================

function Invoke-PostChangeWorkflow {

    param(
        [string]$ModuleName
    )

    # Post-change checks are intentionally manual now.
    # Use Toolkit Management > Validation & Health when checks are needed.
    return
}

# ============================================================
# USAGE TRACKING + AUTO FAVORITES
# ============================================================

function Register-ToolkitUsage {

    param(
        [string]$ModuleName
    )

    # Disabled by design.
    # The framework keeps troubleshooting logs, but it does not maintain usage analytics.
    return
}

function Update-ToolkitAutoFavorites {

    param(
        [string]$ModuleName,
        [array]$Usage
    )

    # Disabled by design.
    return
}
