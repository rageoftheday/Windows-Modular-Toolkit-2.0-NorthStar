# ============================================================
# ENHANCED DASHBOARD
# Includes Smart Recommendations summary
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "ENHANCED DASHBOARD" `
    -RequiresAdmin $false `
    -ScriptBlock {

    function Add-DashboardRecommendation {
        param(
            [System.Collections.Generic.List[object]]$List,
            [string]$Issue,
            [string]$Reason,
            [string[]]$Tools
        )

        $List.Add([PSCustomObject]@{
            Issue  = $Issue
            Reason = $Reason
            Tools  = ($Tools -join ", ")
        })
    }

    function Get-DashboardRecommendations {

        $List = New-Object System.Collections.Generic.List[object]

        $RegistryPath = Join-Path $Root "cache\toolkit_registry.json"

        if (!(Test-Path $RegistryPath)) {
            Add-DashboardRecommendation `
                -List $List `
                -Issue "Toolkit registry missing" `
                -Reason "Registry cache could not be found." `
                -Tools @("Toolkit Registry Builder", "Dry Run Module Validator")
        }

        $Drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue

        foreach ($Drive in $Drives) {
            if ($Drive.Size -gt 0) {
                $FreePercent = [math]::Round(($Drive.FreeSpace / $Drive.Size) * 100, 1)

                if ($FreePercent -lt 15) {
                    Add-DashboardRecommendation `
                        -List $List `
                        -Issue "Low disk space on $($Drive.DeviceID)" `
                        -Reason "Only $FreePercent% free space remains." `
                        -Tools @("Disk Usage", "Large Files", "Quick Cleanup")
                }
            }
        }

        $Errors = Get-WinEvent -LogName System -MaxEvents 50 -ErrorAction SilentlyContinue |
            Where-Object { $_.LevelDisplayName -in @("Critical", "Error") }

        if ($Errors -and $Errors.Count -ge 5) {
            Add-DashboardRecommendation `
                -List $List `
                -Issue "Recent system errors detected" `
                -Reason "$($Errors.Count) recent critical/error events were found." `
                -Tools @("Powershell Eventlog", "Powershell Bsod")
        }

        $PendingReboot = $false

        $RebootKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
        )

        foreach ($Key in $RebootKeys) {
            if (Test-Path $Key) {
                $PendingReboot = $true
            }
        }

        if ($PendingReboot) {
            Add-DashboardRecommendation `
                -List $List `
                -Issue "Pending reboot detected" `
                -Reason "Windows has pending update or servicing operations." `
                -Tools @("Pending Reboot", "Installed Updates")
        }

        $ErrorLog = Join-Path $Root "logs\errors.log"

        if (Test-Path $ErrorLog) {
            $Recent = Get-Content $ErrorLog -Tail 20 -ErrorAction SilentlyContinue

            if ($Recent -and $Recent.Count -gt 0) {
                Add-DashboardRecommendation `
                    -List $List `
                    -Issue "Toolkit errors found" `
                    -Reason "Recent toolkit errors exist in logs\errors.log." `
                    -Tools @("Dry Run Module Validator", "Toolkit Health Center")
            }
        }

        return $List
    }

    Show-ToolkitHeader "ENHANCED DASHBOARD"

    Write-Host "System Snapshot" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"

    $OS = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $CS = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $CPU = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($OS) {
        $Uptime = (Get-Date) - $OS.LastBootUpTime
        Write-Host "Computer       : $env:COMPUTERNAME"
        Write-Host "User           : $env:USERNAME"
        Write-Host "OS             : $($OS.Caption) $($OS.Version)"
        Write-Host "Last Boot      : $($OS.LastBootUpTime)"
        Write-Host "Uptime         : $($Uptime.Days)d $($Uptime.Hours)h $($Uptime.Minutes)m"
    }

    if ($CPU) {
        Write-Host "CPU            : $($CPU.Name)"
    }

    if ($CS) {
        Write-Host "RAM            : $([math]::Round($CS.TotalPhysicalMemory / 1GB, 2)) GB"
    }

    Write-Host ""
    Write-Host "Disk Snapshot" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"

    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue |
        Select-Object `
            DeviceID,
            VolumeName,
            @{N="SizeGB";E={[math]::Round($_.Size/1GB,2)}},
            @{N="FreeGB";E={[math]::Round($_.FreeSpace/1GB,2)}},
            @{N="FreePercent";E={
                if ($_.Size) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 1) } else { 0 }
            }} |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "Toolkit Snapshot" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"

    $RegistryPath = Join-Path $Root "cache\toolkit_registry.json"

    if (Test-Path $RegistryPath) {
        $Registry = @(Get-ToolkitRegistry $RegistryPath)
        $FrameworkItems = @($Registry | Where-Object { $_.module_scope -eq "Framework" -or $_.framework_protected -eq $true })
        $UserModules = @($Registry | Where-Object { $_.module_scope -ne "Framework" -and $_.framework_protected -ne $true })
        $VisibleUserModules = @($UserModules | Where-Object { $_.hidden -ne $true })
        $UserCategories = @($VisibleUserModules | ForEach-Object {
            if ($_.PSObject.Properties.Name -contains "category" -and -not [string]::IsNullOrWhiteSpace([string]$_.category)) {
                [string]$_.category
            }
        } | Sort-Object -Unique)
        Write-Host "Framework Components : $($FrameworkItems.Count)"
        Write-Host "User Modules         : $($VisibleUserModules.Count)"
        Write-Host "User Categories      : $($UserCategories.Count)"
        Write-Host "Total Registry Items : $($Registry.Count)"
        Write-Host "Admin User Modules   : $(@($VisibleUserModules | Where-Object { $_.PSObject.Properties.Name -contains "requires_admin" -and $_.requires_admin -eq $true }).Count)"
        Write-Host "Hidden User Modules  : $(@($UserModules | Where-Object { $_.PSObject.Properties.Name -contains "hidden" -and $_.hidden -eq $true }).Count)"
    }
    else {
        Write-Host "Registry       : Missing" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Recent System Errors" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"

    $Errors = Get-WinEvent -LogName System -MaxEvents 25 -ErrorAction SilentlyContinue |
        Where-Object { $_.LevelDisplayName -in @("Critical","Error") } |
        Select-Object -First 5 TimeCreated, Id, ProviderName, LevelDisplayName

    if ($Errors) {
        $Errors | Format-Table -AutoSize
    }
    else {
        Write-Host "No recent critical/system errors found." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Smart Recommendations Summary" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"

    $Recommendations = Get-DashboardRecommendations

    if ($Recommendations.Count -eq 0) {
        Write-Host "[PASS] No major recommendations at this time." -ForegroundColor Green
    }
    else {
        $Index = 1

        foreach ($Item in $Recommendations) {
            Write-Host "[$Index] $($Item.Issue)" -ForegroundColor Yellow
            Write-Host "    Reason: $($Item.Reason)"
            Write-Host "    Tools : $($Item.Tools)"
            Write-Host ""
            $Index++
        }

        Write-Host "Open Quick Actions > Smart Recommendations to run suggested tools." -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = Read-Host "Selection"
    if ($Choice.ToUpper() -eq "Q") { return }
    return
}