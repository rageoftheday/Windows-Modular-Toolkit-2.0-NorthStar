# ============================================================
# TOOL CHAIN RUNNER
# Runs curated tool packs in sequence
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "TOOL CHAIN RUNNER" `
    -RequiresAdmin $false `
    -ScriptBlock {

    function Get-Registry {
        $RegistryPath = Join-Path $Root "cache\toolkit_registry.json"

        if (!(Test-Path $RegistryPath)) {
            Write-Host "Registry not found." -ForegroundColor Red
            return @()
        }

        $Registry = Get-ToolkitRegistry $RegistryPath

        if ($Registry -isnot [System.Collections.IEnumerable]) {
            $Registry = @($Registry)
        }

        return @($Registry)
    }

    function Find-Tool {
        param(
            [array]$Registry,
            [string]$Name
        )

        $Tool = $Registry |
            Where-Object {
                $_.name -eq $Name -or
                $_.folder -eq $Name
            } |
            Select-Object -First 1

        if ($Tool) {
            return $Tool
        }

        $Tool = $Registry |
            Where-Object {
                $_.name -like "*$Name*" -or
                $_.folder -like "*$Name*"
            } |
            Select-Object -First 1

        return $Tool
    }

    function Write-ChainLog {
        param(
            [string]$Message
        )

        try {
            $LogDir = Join-Path $Root "logs"

            if (!(Test-Path $LogDir)) {
                New-Item -ItemType Directory -Path $LogDir | Out-Null
            }

            $LogPath = Join-Path $LogDir "tool_chains.log"
            $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Add-Content $LogPath "[$Time] $Message"
        }
        catch {}
    }

    function Start-ToolExternal {
        param($Tool)

        if (-not $Tool) {
            return
        }

        $RunPath = Join-Path $Root "$($Tool.path)\$($Tool.entry)"

        if (!(Test-Path $RunPath)) {
            Write-Host "[MISSING] $RunPath" -ForegroundColor Red
            Write-ChainLog "[MISSING] $RunPath"
            return
        }

        Write-Host ""
        Write-Host "==========================================" -ForegroundColor DarkGray
        Write-Host " OPENING TOOL" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor DarkGray
        Write-Host " Tool : $($Tool.name)"
        Write-Host " File : $RunPath"
        Write-Host " Mode : Same PowerShell window"
        Write-Host "==========================================" -ForegroundColor DarkGray
        Write-Host ""

        Write-ChainLog "[LAUNCH] $($Tool.name) -> $RunPath"

        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RunPath

        Start-Sleep -Milliseconds 700
    }

    function Invoke-ToolChain {
        param(
            [string]$ChainName,
            [string[]]$Tools
        )

        $Registry = Get-Registry

        Show-ToolkitHeader "TOOL CHAIN - $ChainName"

        Write-Host "This chain will open each tool in a separate window."
        Write-Host "Tool output will stay visible in its own window."
        Write-Host ""

        $ResolvedTools = @()

        foreach ($Name in $Tools) {
            $Tool = Find-Tool -Registry $Registry -Name $Name

            if ($Tool) {
                $ResolvedTools += $Tool
                Write-Host "[FOUND] $($Tool.name)" -ForegroundColor Green
            }
            else {
                Write-Host "[MISSING] $Name" -ForegroundColor Yellow
            }
        }

        if (!$ResolvedTools -or $ResolvedTools.Count -eq 0) {
            Write-Host ""
            Write-Host "No tools could be resolved for this chain." -ForegroundColor Red
            return
        }

        Write-Host ""
        Write-Host "Run this chain?"
        Write-Host "[Y] Yes"
        Write-Host "[N] No"
        Write-Host ""

        $Confirm = Read-Host "Selection"

        if ($Confirm.ToUpper() -ne "Y") {
            return
        }

        Write-ChainLog "[CHAIN START] $ChainName"

        foreach ($Tool in $ResolvedTools) {
            Start-ToolExternal $Tool
        }

        Write-ChainLog "[CHAIN END] $ChainName"

        Write-Host ""
        Write-Host "Chain launched." -ForegroundColor Green
        Write-Host "Review each opened window before closing it."
        Write-Host ""
    }

    while ($true) {

        Show-ToolkitHeader "TOOL CHAIN RUNNER"

        Write-Host "[1] Repair Pack"
        Write-Host "    DISM/SFC-style repair, health, and validation tools."
        Write-Host ""

        Write-Host "[2] Cleanup Pack"
        Write-Host "    Disk usage, large files, quick cleanup, temp cleanup."
        Write-Host ""

        Write-Host "[3] Network Pack"
        Write-Host "    Internet, DNS, adapters, and ping/trace checks."
        Write-Host ""

        Write-Host "[4] Toolkit Health Pack"
        Write-Host "    Registry, dry-run validation, health center, dashboard."
        Write-Host ""

        Write-Host "[B] Back"
        Write-Host ""

        $Choice = Read-Host "Selection"

        if ($Choice.ToUpper() -eq "B") { return }
        if ($Choice.ToUpper() -eq "Q") { return }

        switch ($Choice) {
            "1" {
                Invoke-ToolChain `
                    -ChainName "Repair Pack" `
                    -Tools @(
                        "DISM RestoreHealth",
                        "System File Checker",
                        "SFC",
                        "Check Disk Scan",
                        "Toolkit Health Center",
                        "Dry Run Module Validator"
                    )
            }

            "2" {
                Invoke-ToolChain `
                    -ChainName "Cleanup Pack" `
                    -Tools @(
                        "Disk Usage",
                        "Large Files",
                        "Quick Cleanup",
                        "Clear Temporary Files",
                        "Windows Update Cache",
                        "Backup File Cleanup"
                    )
            }

            "3" {
                Invoke-ToolChain `
                    -ChainName "Network Pack" `
                    -Tools @(
                        "Powershell Internet Connectivity Test",
                        "DNS Test",
                        "DNS Flush",
                        "Net Info",
                        "Adapter Info",
                        "Ping Trace"
                    )
            }

            "4" {
                Invoke-ToolChain `
                    -ChainName "Toolkit Health Pack" `
                    -Tools @(
                        "Toolkit_Registry_Builder",
                        "Dry Run Module Validator",
                        "Toolkit Health Center",
                        "Enhanced Dashboard",
                        "Smart Recommendations Engine"
                    )
            }
        }
    }
}
