$ErrorActionPreference = "Continue"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ExportRoot = Join-Path $Root "Exports"
$LogRoot = Join-Path $Root "Logs"
if (!(Test-Path $ExportRoot)) { New-Item -ItemType Directory -Path $ExportRoot -Force | Out-Null }
if (!(Test-Path $LogRoot)) { New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null }
$LogPath = Join-Path $LogRoot "compatibility_center.log"
$script:LastResults = $null

function Write-CompatLog {
    param([string]$Message)
    $Line = "{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $LogPath -Value $Line -ErrorAction SilentlyContinue
}

function Show-CompatHeader {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "============================================================"
    Write-Host (" " + $Title)
    Write-Host "============================================================"
    Write-Host ""
}

function Wait-Back {
    Write-Host ""
    Write-Host "[B] Back"
    do { $Choice = (Read-Host "Selection").Trim() } while ($Choice.ToUpper() -ne "B")
}

function New-CheckResult {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Summary,
        [string[]]$Details = @(),
        [string[]]$Recommendations = @()
    )
    [PSCustomObject]@{
        Name = $Name
        Status = $Status
        Summary = $Summary
        Details = @($Details)
        Recommendations = @($Recommendations)
    }
}

function Get-StatusRank {
    param([string]$Status)
    switch ($Status) {
        "FAIL" { return 3 }
        "WARNING" { return 2 }
        "PASS" { return 1 }
        default { return 0 }
    }
}

function Get-OverallStatus {
    param([array]$Checks)
    $Ranks = @($Checks | ForEach-Object { Get-StatusRank $_.Status })
    if ($Ranks -contains 3) { return "FAIL" }
    if ($Ranks -contains 2) { return "WARNING" }
    return "HEALTHY"
}

function Normalize-DependencyName {
    param([string]$Name)
    $Raw = ($Name -as [string]).Trim()
    switch -Regex ($Raw.ToLower()) {
        '^(ps|powershell|pwsh)$' { return "PowerShell" }
        '^(importexcel|import excel|excel)$' { return "ImportExcel" }
        '^(rsat|remote server administration tools)$' { return "RSAT" }
        '^(winget|windows package manager)$' { return "Winget" }
        '^(7zip|7-zip|7z)$' { return "7-Zip" }
        '^(git|git cli)$' { return "Git" }
        '^(wsl|windows subsystem for linux)$' { return "WSL" }
        '^(hyper-v|hyperv)$' { return "Hyper-V" }
        '^(active directory|activedirectory|ad)$' { return "Active Directory" }
        default { return $Raw }
    }
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-DependencyAvailable {
    param([string]$Dependency)
    switch ($Dependency) {
        "PowerShell" { return $true }
        "Winget" { return (Test-CommandExists "winget") }
        "Git" { return (Test-CommandExists "git") }
        "7-Zip" { return ((Test-CommandExists "7z") -or (Test-CommandExists "7za")) }
        "ImportExcel" { return [bool](Get-Module -ListAvailable -Name ImportExcel -ErrorAction SilentlyContinue) }
        "Active Directory" { return [bool](Get-Module -ListAvailable -Name ActiveDirectory -ErrorAction SilentlyContinue) }
        "RSAT" { return ((Get-Module -ListAvailable -Name ActiveDirectory -ErrorAction SilentlyContinue) -or (Test-CommandExists "dsa.msc")) }
        "WSL" { return (Test-CommandExists "wsl") }
        "Hyper-V" { return ((Get-Command Get-VM -ErrorAction SilentlyContinue) -ne $null) }
        default { return $false }
    }
}

function Get-ToolkitFilesForScan {
    $Folders = @("Core","Framework","Modules") | ForEach-Object { Join-Path $Root $_ } | Where-Object { Test-Path $_ }
    $Files = @()
    foreach ($Folder in $Folders) {
        $Files += Get-ChildItem -Path $Folder -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Extension -match '^\.(ps1|bat|cmd|json|txt)$'
        }
    }
    return @($Files)
}

function Test-OperatingSystemCompatibility {
    $Details = @()
    $Recs = @()
    $Status = "PASS"
    try {
        $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $Caption = [string]$OS.Caption
        $Build = [string]$OS.BuildNumber
        $Arch = [string]$OS.OSArchitecture
        $Details += "OS: $Caption"
        $Details += "Build: $Build"
        $Details += "Architecture: $Arch"
        if ($Caption -notmatch "Windows 10|Windows 11") {
            $Status = "WARNING"
            $Recs += "Framework baseline is Windows 10/11. Test carefully on this OS."
        }
        if ($Arch -notmatch "64") {
            $Status = "WARNING"
            $Recs += "64-bit Windows is recommended."
        }
        return New-CheckResult "Operating System" $Status "$Caption build $Build" $Details $Recs
    }
    catch {
        $Details += "Could not query Win32_OperatingSystem: $($_.Exception.Message)"
        return New-CheckResult "Operating System" "WARNING" "OS information could not be fully read." $Details @("Run inside Windows PowerShell on the target computer for best results.")
    }
}

function Test-PowerShellCompatibility {
    $Details = @()
    $Recs = @()
    $Status = "PASS"
    $Version = $PSVersionTable.PSVersion.ToString()
    $Edition = [string]$PSVersionTable.PSEdition
    $Policy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
    $MachinePolicy = Get-ExecutionPolicy -Scope LocalMachine -ErrorAction SilentlyContinue
    $Details += "PowerShell Version: $Version"
    $Details += "Edition: $Edition"
    $Details += "CurrentUser Execution Policy: $Policy"
    $Details += "LocalMachine Execution Policy: $MachinePolicy"
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $Status = "FAIL"
        $Recs += "Windows PowerShell 5.1 or newer is required."
    }
    elseif ($PSVersionTable.PSVersion.Major -eq 5) {
        $Recs += "Windows PowerShell 5.1 is the Framework 2.0 baseline."
    }
    else {
        $Recs += "PowerShell 7+ is supported as optional, but Windows PowerShell 5.1 remains the baseline."
    }
    if ($Policy -match "Restricted|AllSigned" -or $MachinePolicy -match "Restricted|AllSigned") {
        $Status = "WARNING"
        $Recs += "Launch through Start.bat or powershell.exe -ExecutionPolicy Bypass if scripts are blocked."
    }
    return New-CheckResult "PowerShell" $Status "PowerShell $Version" $Details $Recs
}

function Test-PortableModeCompatibility {
    $Details = @()
    $Recs = @()
    $Status = "PASS"
    $RootString = [string]$Root
    $Details += "Toolkit Root: $RootString"
    $Files = @(Get-ToolkitFilesForScan)
    $Findings = @()
    foreach ($File in $Files) {
        try {
            $Text = Get-Content -Path $File.FullName -Raw -ErrorAction Stop
            $Matches = [regex]::Matches($Text, '(?<![A-Za-z0-9_])[A-Za-z]:\\[^\"''<>|`r`n]+')
            foreach ($Match in $Matches) {
                $Value = $Match.Value
                # Ignore registry-provider paths such as HKLM:\SOFTWARE, which can be partially matched as M:\SOFTWARE.
                $Start = [Math]::Max(0, $Match.Index - 8)
                $Prefix = $Text.Substring($Start, $Match.Index - $Start)
                if ($Prefix -match 'HKLM:$|HKCU:$|HKCR:$|HKU:$|HKCC:$') { continue }
                if ($Value -match '^[A-Za-z]:\\SOFTWARE(\\|\.|$)') { continue }
                if ($Value -and $Value -notlike "$RootString*") {
                    $Findings += [PSCustomObject]@{ File = $File.FullName.Replace($RootString, "."); Path = $Value }
                }
            }
        } catch {}
    }
    $Details += "Files Scanned: $($Files.Count)"
    $Details += "Hardcoded Path Findings: $($Findings.Count)"
    if ($Findings.Count -gt 0) {
        $Status = "WARNING"
        $Recs += "Review hardcoded paths. Portable modules should use toolkit-relative paths."
        $Findings | Select-Object -First 10 | ForEach-Object { $Details += "$($_.File) -> $($_.Path)" }
        if ($Findings.Count -gt 10) { $Details += "... $($Findings.Count - 10) more" }
    }
    else {
        $Recs += "No obvious hardcoded non-toolkit paths found in scanned files."
    }
    return New-CheckResult "Portable Mode" $Status "Hardcoded paths found: $($Findings.Count)" $Details $Recs
}

function Get-UserModuleObjects {
    $ModulesRoot = Join-Path $Root "Modules"
    if (!(Test-Path $ModulesRoot)) { return @() }
    $Items = @()
    foreach ($Dir in Get-ChildItem -Path $ModulesRoot -Directory -ErrorAction SilentlyContinue) {
        $JsonPath = Join-Path $Dir.FullName "tool.json"
        $Obj = $null
        $JsonOk = $false
        if (Test-Path $JsonPath) {
            try { $Obj = Get-Content $JsonPath -Raw | ConvertFrom-Json; $JsonOk = $true } catch { $Obj = $null }
        }
        $Items += [PSCustomObject]@{
            Folder = $Dir.FullName
            Name = $Dir.Name
            JsonPath = $JsonPath
            JsonOk = $JsonOk
            Metadata = $Obj
        }
    }
    return @($Items)
}

function Test-ModuleCompatibility {
    $Details = @()
    $Recs = @()
    $Status = "PASS"
    $Modules = @(Get-UserModuleObjects)
    $Warnings = 0
    $Errors = 0
    foreach ($Module in $Modules) {
        if (!(Test-Path $Module.JsonPath)) {
            $Errors++; $Details += "$($Module.Name): missing tool.json"; continue
        }
        if (!$Module.JsonOk) {
            $Errors++; $Details += "$($Module.Name): invalid tool.json"; continue
        }
        $Meta = $Module.Metadata
        $Entry = if ($Meta.entry) { [string]$Meta.entry } else { "run.ps1" }
        $EntryPath = Join-Path $Module.Folder $Entry
        $RunPs1 = Join-Path $Module.Folder "run.ps1"
        $RunBat = Join-Path $Module.Folder "run.bat"
        if (!(Test-Path $EntryPath) -and !(Test-Path $RunPs1) -and !(Test-Path $RunBat)) {
            $Errors++; $Details += "$($Meta.name): missing entry file ($Entry)"
        }
        if (![string]$Meta.name) { $Errors++; $Details += "$($Module.Name): missing name" }
        if (![string]$Meta.category) { $Errors++; $Details += "$($Meta.name): missing category" }
        if ($Meta.category -eq "Uncategorized") { $Errors++; $Details += "$($Meta.name): invalid category Uncategorized" }
        $Keywords = @($Meta.keywords)
        if ($Keywords.Count -lt 1) { $Warnings++; $Details += "$($Meta.name): no keywords" }
        if ($Keywords.Count -gt 10) { $Warnings++; $Details += "$($Meta.name): too many keywords ($($Keywords.Count))" }
        $Deps = @($Meta.dependencies)
        if ($Deps.Count -gt 15) { $Warnings++; $Details += "$($Meta.name): too many dependencies ($($Deps.Count))" }
        if ($Meta.risk -and @("Safe","Moderate","High Impact") -notcontains [string]$Meta.risk) {
            $Warnings++; $Details += "$($Meta.name): non-standard risk value $($Meta.risk)"
        }
    }
    if ($Errors -gt 0) { $Status = "FAIL" }
    elseif ($Warnings -gt 0) { $Status = "WARNING" }
    $Details = @("Modules Scanned: $($Modules.Count)", "Errors: $Errors", "Warnings: $Warnings") + $Details
    if ($Errors -eq 0 -and $Warnings -eq 0) { $Recs += "All user modules passed baseline compatibility checks." }
    else { $Recs += "Run Validation Center for deeper module validation." }
    return New-CheckResult "Modules" $Status "Errors: $Errors, Warnings: $Warnings" $Details $Recs
}

function Test-DependencyCompatibility {
    $Details = @()
    $Recs = @()
    $Status = "PASS"
    $Modules = @(Get-UserModuleObjects | Where-Object { $_.JsonOk })
    $AllDeps = @()
    foreach ($Module in $Modules) {
        foreach ($Dep in @($Module.Metadata.dependencies)) {
            if ([string]$Dep) { $AllDeps += (Normalize-DependencyName $Dep) }
        }
    }
    $AllDeps = @($AllDeps | Sort-Object -Unique)
    $Missing = @()
    foreach ($Dep in $AllDeps) {
        $Available = Test-DependencyAvailable $Dep
        $Details += "${Dep}: " + ($(if ($Available) { "Available" } else { "Missing/Unknown" }))
        if (!$Available) { $Missing += $Dep }
    }
    if ($AllDeps.Count -eq 0) {
        $Details += "No declared dependencies found in user modules."
        $Recs += "Dependencies are optional. Add them to tool.json when a module requires external software or PowerShell modules."
    }
    elseif ($Missing.Count -gt 0) {
        $Status = "WARNING"
        $Recs += "Missing or unknown dependencies: $($Missing -join ', ')"
    }
    else {
        $Recs += "Declared dependencies appear available."
    }
    return New-CheckResult "Dependencies" $Status "Declared: $($AllDeps.Count), Missing/Unknown: $($Missing.Count)" $Details $Recs
}

function Test-FrameworkBaselineCompatibility {
    $Details = @()
    $Recs = @()
    $Status = "PASS"
    $Required = @("Core","Framework","Modules","Config","Cache","Logs","Exports")
    foreach ($Name in $Required) {
        $Path = Join-Path $Root $Name
        if (Test-Path $Path) { $Details += "$($Name): Present" }
        else { $Status = "WARNING"; $Details += "$($Name): Missing"; $Recs += "Create missing framework folder: $Name" }
    }
    $Registry = Join-Path $Root "Cache\toolkit_registry.json"
    if (Test-Path $Registry) { $Details += "Registry: Present" }
    else { $Status = "WARNING"; $Details += "Registry: Missing"; $Recs += "Run Registry Manager or Framework Repair to rebuild toolkit_registry.json." }
    $Details += "Public Module Contract: Modules\<Tool>\tool.json + run.ps1/run.bat"
    $Recs += "Future framework versions should preserve the public module contract or provide a migration path."
    return New-CheckResult "Framework Baseline" $Status "Required framework paths checked." $Details $Recs
}

function Invoke-CompatibilityCheck {
    Write-CompatLog "Compatibility check started"
    $Checks = @(
        (Test-OperatingSystemCompatibility),
        (Test-PowerShellCompatibility),
        (Test-PortableModeCompatibility),
        (Test-ModuleCompatibility),
        (Test-DependencyCompatibility),
        (Test-FrameworkBaselineCompatibility)
    )
    $Overall = Get-OverallStatus $Checks
    $script:LastResults = [PSCustomObject]@{
        Generated = Get-Date
        ToolkitRoot = [string]$Root
        OverallStatus = $Overall
        Checks = @($Checks)
    }
    Write-CompatLog "Compatibility check completed overall=$Overall"
    return $script:LastResults
}

function Show-CompatibilitySummary {
    $Results = Invoke-CompatibilityCheck
    Show-CompatHeader "COMPATIBILITY RESULTS"
    foreach ($Check in $Results.Checks) {
        $Line = "{0,-24} {1}" -f ($Check.Name + " ....."), $Check.Status
        if ($Check.Status -eq "PASS" -or $Check.Status -eq "HEALTHY") { Write-Host $Line -ForegroundColor Green }
        elseif ($Check.Status -eq "WARNING") { Write-Host $Line -ForegroundColor Yellow }
        else { Write-Host $Line -ForegroundColor Red }
        Write-Host "  $($Check.Summary)"
    }
    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host ("Overall Status ....... " + $Results.OverallStatus)
    $Recs = @($Results.Checks | ForEach-Object { $_.Recommendations } | Where-Object { $_ })
    Write-Host ""
    if ($Recs.Count -gt 0) {
        Write-Host "Recommendations"
        Write-Host "---------------"
        foreach ($Rec in ($Recs | Select-Object -Unique)) { Write-Host "- $Rec" }
    }
    else {
        Write-Host "Recommendations ...... NONE"
    }
    Wait-Back
}

function Show-DetailedResults {
    if (!$script:LastResults) { $script:LastResults = Invoke-CompatibilityCheck }
    Show-CompatHeader "DETAILED COMPATIBILITY RESULTS"
    Write-Host "Generated: $($script:LastResults.Generated)"
    Write-Host "Toolkit Root: $($script:LastResults.ToolkitRoot)"
    Write-Host "Overall Status: $($script:LastResults.OverallStatus)"
    Write-Host ""
    foreach ($Check in $script:LastResults.Checks) {
        Write-Host "------------------------------------------------------------"
        Write-Host $Check.Name
        Write-Host "Status : $($Check.Status)"
        Write-Host "Summary: $($Check.Summary)"
        Write-Host ""
        foreach ($Detail in @($Check.Details)) { Write-Host "  $Detail" }
        if (@($Check.Recommendations).Count -gt 0) {
            Write-Host ""
            Write-Host "Recommendations:"
            foreach ($Rec in @($Check.Recommendations)) { Write-Host "  - $Rec" }
        }
        Write-Host ""
    }
    Wait-Back
}

function ConvertTo-HtmlSafe {
    param([string]$Text)
    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function New-CompatibilityReport {
    if (!$script:LastResults) { $script:LastResults = Invoke-CompatibilityCheck }
    $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $ReportPath = Join-Path $ExportRoot "Compatibility_Report_$Stamp.html"
    $Html = @()
    $Html += "<html><head><title>Compatibility Report</title><style>body{font-family:Segoe UI,Arial;margin:24px;} .pass{color:green;} .warning{color:#9a6700;} .fail{color:red;} pre{background:#f5f5f5;padding:10px;}</style></head><body>"
    $Html += "<h1>Windows Modular Toolkit - Compatibility Report</h1>"
    $Html += "<p><strong>Generated:</strong> $($script:LastResults.Generated)</p>"
    $Html += "<p><strong>Toolkit Root:</strong> $(ConvertTo-HtmlSafe $script:LastResults.ToolkitRoot)</p>"
    $Html += "<p><strong>Overall Status:</strong> $($script:LastResults.OverallStatus)</p>"
    foreach ($Check in $script:LastResults.Checks) {
        $Class = $Check.Status.ToLower()
        $Html += "<h2>$(ConvertTo-HtmlSafe $Check.Name) - <span class='$Class'>$($Check.Status)</span></h2>"
        $Html += "<p>$(ConvertTo-HtmlSafe $Check.Summary)</p>"
        $Html += "<h3>Details</h3><ul>"
        foreach ($Detail in @($Check.Details)) { $Html += "<li>$(ConvertTo-HtmlSafe $Detail)</li>" }
        $Html += "</ul>"
        if (@($Check.Recommendations).Count -gt 0) {
            $Html += "<h3>Recommendations</h3><ul>"
            foreach ($Rec in @($Check.Recommendations)) { $Html += "<li>$(ConvertTo-HtmlSafe $Rec)</li>" }
            $Html += "</ul>"
        }
    }
    $Html += "</body></html>"
    Set-Content -Path $ReportPath -Value ($Html -join [Environment]::NewLine) -Encoding UTF8
    Write-CompatLog "Compatibility report exported path=$ReportPath"
    Show-CompatHeader "COMPATIBILITY REPORT EXPORTED"
    Write-Host "Report created:"
    Write-Host $ReportPath
    Write-Host ""
    Write-Host "[O] Open Report"
    Write-Host "[B] Back"
    while ($true) {
        $Choice = (Read-Host "Selection").Trim().ToUpper()
        if ($Choice -eq "O") { Start-Process $ReportPath }
        if ($Choice -eq "B") { return }
    }
}

while ($true) {
    Show-CompatHeader "COMPATIBILITY CENTER"
    Write-Host "Simple first. Details available when needed."
    Write-Host ""
    Write-Host "[1] Run Compatibility Check"
    Write-Host "[2] Detailed Results"
    Write-Host "[3] Generate Compatibility Report"
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = (Read-Host "Selection").Trim().ToUpper()
    switch ($Choice) {
        "1" { Show-CompatibilitySummary }
        "2" { Show-DetailedResults }
        "3" { New-CompatibilityReport }
        "B" { return }
    }
}
