# ============================================================
# SMART RECOMMENDATIONS ENGINE
# Interactive recommendations + alias learning + auto chain suggestions
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "SMART RECOMMENDATIONS ENGINE" `
    -RequiresAdmin $false `
    -ScriptBlock {

    function Get-Registry {
        $Path = Join-Path $Root "cache\toolkit_registry.json"

        if (!(Test-Path $Path)) {
            return @()
        }

        $Reg = Get-ToolkitRegistry $Path

        if ($Reg -isnot [System.Collections.IEnumerable]) {
            $Reg = @($Reg)
        }

        return @($Reg)
    }

    function Get-AliasCachePath {
        return (Join-Path $Root "config\smart_recommendation_aliases.json")
    }

    function Get-AliasCache {
        $AliasPath = Get-AliasCachePath

        if (!(Test-Path $AliasPath)) {
            return @{}
        }

        try {
            $Raw = Get-Content $AliasPath -Raw | ConvertFrom-Json
            $Cache = @{}

            foreach ($Property in $Raw.PSObject.Properties) {

                $Value = $Property.Value

                if ($Value -is [string]) {
                    $Cache[$Property.Name] = @{
                        folder = $Value
                        name   = $Value.Replace("_", " ")
                    }
                }
                else {
                    $Cache[$Property.Name] = @{
                        folder = [string]$Value.folder
                        name   = [string]$Value.name
                    }
                }
            }

            return $Cache
        }
        catch {
            return @{}
        }
    }

    function Save-AliasCache {
        param([hashtable]$Cache)

        try {
            $ConfigDir = Join-Path $Root "config"

            if (!(Test-Path $ConfigDir)) {
                New-Item -ItemType Directory -Path $ConfigDir | Out-Null
            }

            $AliasPath = Get-AliasCachePath

            $Cache |
                ConvertTo-Json -Depth 8 |
                Set-Content $AliasPath -Encoding UTF8
        }
        catch {
            Write-Host "[WARN] Could not save alias cache." -ForegroundColor Yellow
        }
    }

    function Learn-Alias {
        param(
            [string]$RequestedName,
            $ResolvedTool
        )

        if ([string]::IsNullOrWhiteSpace($RequestedName) -or -not $ResolvedTool) {
            return
        }

        try {
            $Cache = Get-AliasCache
            $Cache[$RequestedName] = @{
                folder = $ResolvedTool.folder
                name   = $ResolvedTool.name
            }
            Save-AliasCache $Cache
        }
        catch {
            # Alias learning should never block recommendations.
        }
    }

    function Write-ExternalLaunchLog {
        param(
            [string]$ToolName,
            [string]$RunPath
        )

        try {
            $LogDir = Join-Path $Root "logs"

            if (!(Test-Path $LogDir)) {
                New-Item -ItemType Directory -Path $LogDir | Out-Null
            }

            $LogPath = Join-Path $LogDir "external_launches.log"
            $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

            Add-Content $LogPath "[$Time] [LAUNCH] $ToolName -> $RunPath"
        }
        catch {}
    }

    function Start-ExternalTool {
        param($Tool)

        if (-not $Tool) {
            Write-Host "[SKIP] Empty tool reference." -ForegroundColor Yellow
            return
        }

        $RunPath = Join-Path $Root "$($Tool.path)\$($Tool.entry)"

        if (!(Test-Path $RunPath)) {
            Write-Host "[MISSING] $RunPath" -ForegroundColor Red
            return
        }

        Write-Host ""
        Write-Host "==========================================" -ForegroundColor DarkGray
        Write-Host " OPENING TOOL" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor DarkGray
        Write-Host " Tool : $($Tool.name)"
        Write-Host " File : $RunPath"
        Write-Host " Mode : Same window"
        Write-Host " Note : Window will stay open if the tool pauses."
        Write-Host "==========================================" -ForegroundColor DarkGray
        Write-Host ""

        Write-ExternalLaunchLog `
            -ToolName $Tool.name `
            -RunPath $RunPath

        Start-Sleep -Milliseconds 500

        if ($Tool.entry -like "*.bat") {
            & cmd.exe /c "`"$RunPath`""
        }
        else {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RunPath
        }
    }

    function Find-Tool {
        param(
            [array]$Registry,
            [string]$Name
        )

        if ([string]::IsNullOrWhiteSpace($Name)) {
            return $null
        }

        $Cache = Get-AliasCache

        if ($Cache.ContainsKey($Name)) {
            $CachedFolder = $Cache[$Name].folder
            $CachedName   = $Cache[$Name].name

            $CachedTool = $Registry |
                Where-Object {
                    $_.folder -eq $CachedFolder -or
                    $_.name -eq $CachedName
                } |
                Select-Object -First 1

            if ($CachedTool) {
                return $CachedTool
            }
        }

        $Tool = $Registry |
            Where-Object {
                $_.name -eq $Name -or
                $_.folder -eq $Name
            } |
            Select-Object -First 1

        if ($Tool) {
            Learn-Alias -RequestedName $Name -ResolvedTool $Tool
            return $Tool
        }

        $Aliases = @{
            "Validate Modules" = @("Module Validator","Module_Validator","Smart Module Validator","Validate Modules")
            "Module Validator" = @("Module Validator","Module_Validator")
            "Toolkit Registry Builder" = @("Toolkit_Registry_Builder","Toolkit_Registry","Registry Builder")
            "Dry Run Module Validator" = @("Dry Run Module Validator","Dry_Run_Module_Validator")
            "Toolkit Health Center" = @("Toolkit Health Center","Toolkit_Health_Center")
            "Smart Recommendations Engine" = @("Smart Recommendations Engine","Smart_Recommendations_Engine")
            "Enhanced Dashboard" = @("Enhanced Dashboard","Enhanced_Dashboard")
            "Usage Statistics" = @("Usage Statistics","Usage_Statistics")
            "Quick Actions Hub" = @("Quick Actions Hub","Quick_Actions_Hub")
            "Tool Chain Runner" = @("Tool Chain Runner","Tool_Chain_Runner")
        }

        if ($Aliases.ContainsKey($Name)) {
            foreach ($Alias in $Aliases[$Name]) {
                $Tool = $Registry |
                    Where-Object {
                        $_.name -eq $Alias -or
                        $_.folder -eq $Alias
                    } |
                    Select-Object -First 1

                if ($Tool) {
                    Learn-Alias -RequestedName $Name -ResolvedTool $Tool
                    return $Tool
                }
            }
        }

        $Tool = $Registry |
            Where-Object {
                $_.name -like "*$Name*" -or
                $_.folder -like "*$Name*"
            } |
            Select-Object -First 1

        if ($Tool) {
            Learn-Alias -RequestedName $Name -ResolvedTool $Tool
        }

        return $Tool
    }

    function Add-Rec {
        param(
            [System.Collections.Generic.List[object]]$List,
            [string]$Issue,
            [string]$Reason,
            [string[]]$Tools,
            [string]$SuggestedChain,
            [string[]]$ChainTools
        )

        $List.Add([PSCustomObject]@{
            Issue          = $Issue
            Reason         = $Reason
            Tools          = $Tools
            SuggestedChain = $SuggestedChain
            ChainTools     = $ChainTools
        })
    }

    function Build-Recommendations {

        $List = New-Object System.Collections.Generic.List[object]

        $RegistryPath = Join-Path $Root "cache\toolkit_registry.json"

        if (!(Test-Path $RegistryPath)) {
            Add-Rec `
                -List $List `
                -Issue "Toolkit registry missing" `
                -Reason "The toolkit registry was not found." `
                -Tools @("Toolkit Registry Builder", "Dry Run Module Validator") `
                -SuggestedChain "Toolkit Health Pack" `
                -ChainTools @("Toolkit Registry Builder", "Dry Run Module Validator", "Toolkit Health Center")
        }

        $Drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue

        foreach ($Drive in $Drives) {
            if ($Drive.Size -gt 0) {
                $FreePercent = [math]::Round(($Drive.FreeSpace / $Drive.Size) * 100, 1)

                if ($FreePercent -lt 15) {
                    Add-Rec `
                        -List $List `
                        -Issue "Low disk space on $($Drive.DeviceID)" `
                        -Reason "Only $FreePercent% free space remains." `
                        -Tools @("Disk Usage","Large Files","Quick Cleanup","Clear Temporary Files") `
                        -SuggestedChain "Cleanup Pack" `
                        -ChainTools @("Disk Usage","Large Files","Quick Cleanup","Clear Temporary Files","Windows Update Cache")
                }
            }
        }

        $Errors = Get-WinEvent -LogName System -MaxEvents 50 -ErrorAction SilentlyContinue |
            Where-Object { $_.LevelDisplayName -in @("Critical", "Error") }

        if ($Errors -and $Errors.Count -ge 5) {
            Add-Rec `
                -List $List `
                -Issue "Recent system errors detected" `
                -Reason "$($Errors.Count) recent critical/error events were found." `
                -Tools @("Powershell Eventlog","Powershell Bsod","Enhanced Dashboard") `
                -SuggestedChain "Repair Pack" `
                -ChainTools @("Powershell Eventlog","Powershell Bsod","System File Checker","DISM RestoreHealth","Toolkit Health Center")
        }

        $Ping = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
        $Dns  = Resolve-DnsName "microsoft.com" -ErrorAction SilentlyContinue

        if (-not $Ping) {
            Add-Rec `
                -List $List `
                -Issue "Internet connectivity may be down" `
                -Reason "Ping to 8.8.8.8 failed." `
                -Tools @("Powershell Internet Connectivity Test","Net Info","DNS Test","Ping Trace") `
                -SuggestedChain "Network Pack" `
                -ChainTools @("Powershell Internet Connectivity Test","DNS Test","Net Info","Adapter Info","Ping Trace")
        }
        elseif (-not $Dns) {
            Add-Rec `
                -List $List `
                -Issue "DNS resolution may be failing" `
                -Reason "Internet ping worked, but DNS lookup failed." `
                -Tools @("DNS Flush","DNS Test","Powershell DNS Cache") `
                -SuggestedChain "Network Pack" `
                -ChainTools @("DNS Flush","DNS Test","Powershell DNS Cache","Powershell Internet Connectivity Test")
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
            Add-Rec `
                -List $List `
                -Issue "Pending reboot detected" `
                -Reason "Windows has pending update or servicing operations." `
                -Tools @("Pending Reboot","Installed Updates","Windows Update Cache") `
                -SuggestedChain "Toolkit Health Pack" `
                -ChainTools @("Pending Reboot","Installed Updates","Windows Update Cache","Toolkit Health Center")
        }

        $Defender = Get-MpComputerStatus -ErrorAction SilentlyContinue

        if ($Defender) {
            if ($Defender.AntivirusEnabled -ne $true -or $Defender.RealTimeProtectionEnabled -ne $true) {
                Add-Rec `
                    -List $List `
                    -Issue "Microsoft Defender protection issue" `
                    -Reason "Defender or real-time protection may be disabled." `
                    -Tools @("Powershell Defender","Powershell Threats") `
                    -SuggestedChain "Security Check Pack" `
                    -ChainTools @("Powershell Defender","Powershell Threats","FW Rules","Audit Policy")
            }
        }

        $ErrorLog = Join-Path $Root "logs\errors.log"

        if (Test-Path $ErrorLog) {
            $Recent = Get-Content $ErrorLog -Tail 20 -ErrorAction SilentlyContinue

            if ($Recent -and $Recent.Count -gt 0) {
                Add-Rec `
                    -List $List `
                    -Issue "Toolkit errors found" `
                    -Reason "Recent toolkit errors exist in logs\errors.log." `
                    -Tools @("Dry Run Module Validator","Toolkit Health Center","Module Validator") `
                    -SuggestedChain "Toolkit Health Pack" `
                    -ChainTools @("Dry Run Module Validator","Toolkit Health Center","Module Validator","Enhanced Dashboard")
            }
        }

        $UsagePath = Join-Path $Root "logs\usage.json"

        if (!(Test-Path $UsagePath)) {
            Add-Rec `
                -List $List `
                -Issue "No usage history yet" `
                -Reason "Usage tracking has not collected enough data." `
                -Tools @("Usage Statistics","Quick Actions Hub") `
                -SuggestedChain "Toolkit Health Pack" `
                -ChainTools @("Usage Statistics","Quick Actions Hub","Enhanced Dashboard")
        }

        return $List
    }

    function Save-RecommendationReport {
        param([System.Collections.Generic.List[object]]$Recommendations)

        try {
            $LogDir = Join-Path $Root "logs"

            if (!(Test-Path $LogDir)) {
                New-Item -ItemType Directory -Path $LogDir | Out-Null
            }

            $Out = Join-Path $LogDir "smart_recommendations.txt"

            $Recommendations |
                ForEach-Object {
                    "Issue: $($_.Issue)"
                    "Reason: $($_.Reason)"
                    "Tools: $($_.Tools -join ', ')"
                    "Suggested Chain: $($_.SuggestedChain)"
                    "Chain Tools: $($_.ChainTools -join ', ')"
                    ""
                } |
                Set-Content $Out -Encoding UTF8

            Write-Host "Saved report:"
            Write-Host $Out
            Write-Host ""
        }
        catch {
            Write-Host "[WARN] Could not save recommendation report." -ForegroundColor Yellow
        }
    }

    function Invoke-ToolListExternal {
        param(
            [array]$Registry,
            [string[]]$ToolNames
        )

        foreach ($ToolName in $ToolNames) {
            $Tool = Find-Tool -Registry $Registry -Name $ToolName

            if ($Tool) {
                Start-ExternalTool $Tool
            }
            else {
                Write-Host "[SKIP] Tool not found: $ToolName" -ForegroundColor Yellow
            }
        }
    }

    while ($true) {

        $Registry = Get-Registry
        $Recommendations = Build-Recommendations

        Show-ToolkitHeader "SMART RECOMMENDATIONS ENGINE"

        if ($Recommendations.Count -eq 0) {
            Write-Host "[PASS] No issues found." -ForegroundColor Green
            Write-Host ""
            Write-Host "Recommended routine:"
            Write-Host " - Dry Run Module Validator"
            Write-Host " - Toolkit Health Center"
            Write-Host " - Enhanced Dashboard"
            Write-Host ""
            return
        }

        Write-Host "Recommendations found: $($Recommendations.Count)" -ForegroundColor Yellow
        Write-Host ""

        $Index = 1

        foreach ($Recommendation in $Recommendations) {
            Write-Host "[$Index] $($Recommendation.Issue)" -ForegroundColor Yellow
            Write-Host "    Reason: $($Recommendation.Reason)"
            Write-Host "    Tools : $($Recommendation.Tools -join ', ')"
            Write-Host "    Suggested chain: $($Recommendation.SuggestedChain)" -ForegroundColor Cyan
            Write-Host ""
            $Index++
        }

        Save-RecommendationReport -Recommendations $Recommendations

        Write-Host "[number] Pick a recommendation"
        Write-Host "[A] Run ALL tools from all recommendations"
        Write-Host "[C] Run BEST suggested chain"
        Write-Host "[R] Refresh recommendations"
        Write-Host "[B] Back"
        Write-Host ""

        $Choice = Read-Host "Selection"

        if ($Choice.ToUpper() -eq "B") {
            return
        }

        if ($Choice.ToUpper() -eq "R") {
            continue
        }

        if ($Choice.ToUpper() -eq "A") {
            foreach ($Recommendation in $Recommendations) {
                Invoke-ToolListExternal -Registry $Registry -ToolNames $Recommendation.Tools
            }
            continue
        }

        if ($Choice.ToUpper() -eq "C") {
            # Best chain = first recommendation's suggested chain.
            $Best = $Recommendations[0]

            Write-Host ""
            Write-Host "Running suggested chain: $($Best.SuggestedChain)" -ForegroundColor Cyan
            Write-Host ""

            Invoke-ToolListExternal -Registry $Registry -ToolNames $Best.ChainTools
            continue
        }

        if ($Choice -match '^\d+$') {

            $RecIndex = [int]$Choice - 1

            if ($RecIndex -lt 0 -or $RecIndex -ge $Recommendations.Count) {
                continue
            }

            $SelectedRecommendation = $Recommendations[$RecIndex]

            while ($true) {

                Show-ToolkitHeader "RUN RECOMMENDED TOOLS"

                Write-Host "$($SelectedRecommendation.Issue)" -ForegroundColor Yellow
                Write-Host "$($SelectedRecommendation.Reason)"
                Write-Host ""
                Write-Host "Suggested chain: $($SelectedRecommendation.SuggestedChain)" -ForegroundColor Cyan
                Write-Host ""

                $ToolMap = @()
                $ToolIndex = 1

                foreach ($ToolName in $SelectedRecommendation.Tools) {

                    $Tool = Find-Tool -Registry $Registry -Name $ToolName

                    if ($Tool) {
                        Write-Host "[$ToolIndex] $($Tool.name)"
                        if ($Tool.description) {
                            Write-Host "    $($Tool.description)"
                        }
                        Write-Host ""
                        $ToolMap += $Tool
                        $ToolIndex++
                    }
                    else {
                        Write-Host "[missing] $ToolName" -ForegroundColor Yellow
                    }
                }

                Write-Host "[A] Run all listed tools"
                Write-Host "[C] Run suggested chain"
                Write-Host "[B] Back"
                Write-Host ""

                $ToolChoice = Read-Host "Select tool"

                if ($ToolChoice.ToUpper() -eq "B") {
                    break
                }

                if ($ToolChoice.ToUpper() -eq "A") {
                    foreach ($Tool in $ToolMap) {
                        Start-ExternalTool $Tool
                    }
                    continue
                }

                if ($ToolChoice.ToUpper() -eq "C") {
                    Invoke-ToolListExternal -Registry $Registry -ToolNames $SelectedRecommendation.ChainTools
                    continue
                }

                if ($ToolChoice -match '^\d+$') {
                    $ToolSelected = $ToolMap[[int]$ToolChoice - 1]

                    if ($ToolSelected) {
                        Start-ExternalTool $ToolSelected
                    }
                }
            }
        }
    }
}
