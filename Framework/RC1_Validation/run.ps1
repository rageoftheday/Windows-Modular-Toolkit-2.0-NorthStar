# ============================================================
# WINDOWS MODULAR TOOLKIT - RELEASE CANDIDATE VALIDATION
# Framework Edition 2.0
# ============================================================

$ErrorActionPreference = "Continue"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolkitRoot = Resolve-Path (Join-Path $ScriptRoot "..\..")
$ToolkitRoot = $ToolkitRoot.Path
$script:LastRCResults = $null

function Show-LocalHeader {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "============================================================"
    Write-Host " $Title"
    Write-Host "============================================================"
    Write-Host ""
}

function Wait-Back {
    Write-Host ""
    Write-Host "[B] Back"
    do { $Choice = Read-Host "Selection" } while ($Choice.ToUpper() -ne "B")
}

function New-CheckResult {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Summary,
        [string[]]$Details = @(),
        [string[]]$Findings = @(),
        [string[]]$Recommendations = @()
    )
    return [PSCustomObject]@{
        Name = $Name
        Status = $Status
        Summary = $Summary
        Details = @($Details)
        Findings = @($Findings)
        Recommendations = @($Recommendations)
    }
}

function Get-OverallStatus {
    param($Results)
    $Statuses = @($Results | ForEach-Object { $_.Status })
    if ($Statuses -contains "FAIL") { return "NOT READY" }
    if ($Statuses -contains "WARNING") { return "READY WITH WARNINGS" }
    return "READY"
}

function Get-StatusRank {
    param([string]$Status)
    switch ($Status) {
        "FAIL" { return 3 }
        "WARNING" { return 2 }
        default { return 1 }
    }
}

function Get-ToolJsonObjects {
    $Items = New-Object System.Collections.ArrayList
    $Roots = @(
        @{ Scope = "Modules"; Base = Join-Path $ToolkitRoot "Modules" },
        @{ Scope = "Framework"; Base = Join-Path $ToolkitRoot "Framework" }
    )

    foreach ($RootItem in $Roots) {
        $Base = $RootItem.Base
        if (-not (Test-Path $Base)) { continue }
        Get-ChildItem -Path $Base -Recurse -Filter "tool.json" -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $Json = Get-Content $_.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
                $FolderPath = Split-Path -Parent $_.FullName
                $FolderName = Split-Path -Leaf $FolderPath
                $RelPath = $FolderPath.Substring($ToolkitRoot.Length).TrimStart('\','/') -replace '\\','/'

                if (-not ($Json.PSObject.Properties.Name -contains 'folder')) {
                    Add-Member -InputObject $Json -MemberType NoteProperty -Name folder -Value $FolderName -Force
                } else { $Json.folder = $FolderName }

                if (-not ($Json.PSObject.Properties.Name -contains 'path')) {
                    Add-Member -InputObject $Json -MemberType NoteProperty -Name path -Value $RelPath -Force
                } else { $Json.path = $RelPath }

                if (-not ($Json.PSObject.Properties.Name -contains 'scope')) {
                    Add-Member -InputObject $Json -MemberType NoteProperty -Name scope -Value $RootItem.Scope -Force
                } else { $Json.scope = $RootItem.Scope }

                [void]$Items.Add($Json)
            } catch {
                $Bad = [PSCustomObject]@{ name = "Invalid tool.json"; folder = (Split-Path -Leaf (Split-Path -Parent $_.FullName)); path = $_.FullName; scope = $RootItem.Scope; parse_error = $_.Exception.Message }
                [void]$Items.Add($Bad)
            }
        }
    }
    return @($Items)
}

function Test-ScriptParse {
    param([string]$Path)
    try {
        $Content = Get-Content -Path $Path -Raw -ErrorAction Stop
        [void][scriptblock]::Create($Content)
        return $null
    } catch {
        return $_.Exception.Message
    }
}

function Test-CoreIntegrity {
    $Details = New-Object System.Collections.ArrayList
    $Findings = New-Object System.Collections.ArrayList
    $Recommendations = New-Object System.Collections.ArrayList
    $CorePath = Join-Path $ToolkitRoot "Core"
    $Required = @(
        "bootstrap.ps1",
        "toolkit.core.ps1",
        "module.loader.ps1",
        "module.api.ps1",
        "menu.engine.ps1",
        "settings.engine.ps1",
        "framework.integrity.ps1"
    )

    if (-not (Test-Path $CorePath)) {
        return New-CheckResult -Name "Core Integrity" -Status "FAIL" -Summary "Core folder missing." -Findings @("Missing Core folder.") -Recommendations @("Restore the Core folder from a trusted framework package.")
    }

    foreach ($File in $Required) {
        $Path = Join-Path $CorePath $File
        if (Test-Path $Path) {
            [void]$Details.Add("Present: $File")
            $ParseError = Test-ScriptParse -Path $Path
            if ($ParseError) { [void]$Findings.Add("Parse error in Core\$($File): $ParseError") }
        } else {
            [void]$Findings.Add("Missing Tier 1/2 core file: $File")
        }
    }

    $Status = if ($Findings.Count -gt 0) { "FAIL" } else { "PASS" }
    $Summary = if ($Status -eq "PASS") { "Required core files are present and parse cleanly." } else { "One or more required core files are missing or invalid." }
    if ($Status -ne "PASS") { [void]$Recommendations.Add("Run Framework Repair or restore Core from a trusted build.") }
    return New-CheckResult -Name "Core Integrity" -Status $Status -Summary $Summary -Details @($Details) -Findings @($Findings) -Recommendations @($Recommendations)
}

function Test-FrameworkIntegrity {
    $Details = New-Object System.Collections.ArrayList
    $Findings = New-Object System.Collections.ArrayList
    $Recommendations = New-Object System.Collections.ArrayList
    $FrameworkPath = Join-Path $ToolkitRoot "Framework"
    $Required = @(
        "Validation_Center",
        "Tool_Manager",
        "Dashboard_Health_Center",
        "Category_Manager",
        "Compatibility_Center",
        "Framework_Repair",
        "RC1_Validation"
    )

    if (-not (Test-Path $FrameworkPath)) {
        return New-CheckResult -Name "Framework Integrity" -Status "FAIL" -Summary "Framework folder missing." -Findings @("Missing Framework folder.") -Recommendations @("Restore the Framework folder from a trusted framework package.")
    }

    foreach ($Folder in $Required) {
        $Base = Join-Path $FrameworkPath $Folder
        $Run = Join-Path $Base "run.ps1"
        $Json = Join-Path $Base "tool.json"
        if (Test-Path $Base) { [void]$Details.Add("Present: Framework\$Folder") } else { [void]$Findings.Add("Missing framework component folder: $Folder"); continue }
        if (Test-Path $Run) {
            $ParseError = Test-ScriptParse -Path $Run
            if ($ParseError) { [void]$Findings.Add("Parse error in Framework\$($Folder)\run.ps1: $ParseError") }
        } else { [void]$Findings.Add("Missing run.ps1 for $Folder") }
        if (-not (Test-Path $Json)) { [void]$Findings.Add("Missing tool.json for $Folder") }
    }

    $Status = if ($Findings.Count -gt 0) { "FAIL" } else { "PASS" }
    $Summary = if ($Status -eq "PASS") { "Required framework centers are present." } else { "One or more required framework centers are missing or invalid." }
    if ($Status -ne "PASS") { [void]$Recommendations.Add("Run Framework Repair or restore missing Framework components.") }
    return New-CheckResult -Name "Framework Integrity" -Status $Status -Summary $Summary -Details @($Details) -Findings @($Findings) -Recommendations @($Recommendations)
}

function Test-NavigationIntegrity {
    $Details = New-Object System.Collections.ArrayList
    $Findings = New-Object System.Collections.ArrayList
    $Recommendations = New-Object System.Collections.ArrayList
    $ToolkitPs1 = Join-Path $ToolkitRoot "Toolkit.ps1"
    $RequiredCenters = @("Validation_Center","Tool_Manager","Dashboard_Health_Center","Category_Manager","Compatibility_Center","Framework_Repair","RC1_Validation")

    if (Test-Path $ToolkitPs1) {
        [void]$Details.Add("Toolkit.ps1 present")
        $Content = Get-Content $ToolkitPs1 -Raw
        if ($Content -match '\[Q\]\s*Quit' -or ($Content -match 'Key\s*=\s*"Q"' -and $Content -match 'Label\s*=\s*"Quit"')) { [void]$Details.Add("Root quit option present") } else { [void]$Findings.Add("Root quit option not detected.") }
        if ($Content -match "\[B\] Back") { [void]$Details.Add("Back option detected in Toolkit.ps1 menus") } else { [void]$Findings.Add("Back option not detected in Toolkit.ps1.") }
        $ParseError = Test-ScriptParse -Path $ToolkitPs1
        if ($ParseError) { [void]$Findings.Add("Toolkit.ps1 parse error: $ParseError") }
    } else {
        [void]$Findings.Add("Toolkit.ps1 missing.")
    }

    foreach ($Folder in $RequiredCenters) {
        $Run = Join-Path (Join-Path $ToolkitRoot "Framework\$Folder") "run.ps1"
        if (Test-Path $Run) {
            $Text = Get-Content $Run -Raw
            if ($Text -match "\[B\] Back") { [void]$Details.Add("Back option present: $Folder") }
            else { [void]$Findings.Add("Back option not detected in $Folder") }
        }
    }

    $Status = if ($Findings.Count -gt 0) { "WARNING" } else { "PASS" }
    $Summary = if ($Status -eq "PASS") { "Navigation markers were found in required menus." } else { "Some navigation markers may be missing." }
    if ($Status -ne "PASS") { [void]$Recommendations.Add("Review menus for the Framework 2.0 navigation standard: B backs up, Q quits only at the root menu.") }
    return New-CheckResult -Name "Navigation Integrity" -Status $Status -Summary $Summary -Details @($Details) -Findings @($Findings) -Recommendations @($Recommendations)
}

function Test-CompatibilityStatus {
    $Details = New-Object System.Collections.ArrayList
    $Findings = New-Object System.Collections.ArrayList
    $Recommendations = New-Object System.Collections.ArrayList

    try {
        $OS = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        [void]$Details.Add("OS: $($OS.Caption) build $($OS.BuildNumber)")
        if ($OS.Caption -match "Windows 10|Windows 11") { [void]$Details.Add("OS baseline supported") }
        else { [void]$Findings.Add("OS baseline warning: $($OS.Caption)") }
    } catch {
        [void]$Findings.Add("Unable to read operating system information: $($_.Exception.Message)")
    }

    [void]$Details.Add("PowerShell: $($PSVersionTable.PSVersion)")
    if ($PSVersionTable.PSVersion.Major -lt 5) { [void]$Findings.Add("PowerShell version below 5.1 baseline.") }

    $ScanRoots = @("Framework","Modules","Core") | ForEach-Object { Join-Path $ToolkitRoot $_ } | Where-Object { Test-Path $_ }
    $Hardcoded = New-Object System.Collections.ArrayList
    foreach ($Root in $ScanRoots) {
        Get-ChildItem -Path $Root -Recurse -Include *.ps1,*.bat,*.cmd,*.json -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $Text = Get-Content $_.FullName -Raw -ErrorAction Stop
                $Matches = [regex]::Matches($Text, "(?<![A-Za-z0-9_])[A-Za-z]:\\[^`"'<>|`r`n]+")
                foreach ($M in $Matches) {
                    $Value = $M.Value
                    # Ignore PowerShell registry-provider paths such as HKLM:\SOFTWARE... which the simple drive regex can partially match as M:\SOFTWARE.
                    $Start = [Math]::Max(0, $M.Index - 8)
                    $Prefix = $Text.Substring($Start, $M.Index - $Start)
                    if ($Prefix -match 'HKLM:$|HKCU:$|HKCR:$|HKU:$|HKCC:$') { continue }
                    if ($Value -match '^[A-Za-z]:\\SOFTWARE(\\|\.|$)') { continue }
                    if ($Value -notmatch [regex]::Escape($ToolkitRoot)) {
                        $Rel = $_.FullName.Substring($ToolkitRoot.Length).TrimStart('\','/')
                        [void]$Hardcoded.Add("$Rel -> $($Value.Substring(0,[Math]::Min(80,$Value.Length)))")
                    }
                }
            } catch {}
        }
    }
    $UniqueHardcoded = @($Hardcoded | Sort-Object -Unique)
    [void]$Details.Add("Hardcoded path findings: $($UniqueHardcoded.Count)")
    if ($UniqueHardcoded.Count -gt 0) {
        foreach ($Item in @($UniqueHardcoded | Select-Object -First 10)) { [void]$Findings.Add("Hardcoded path: $Item") }
        [void]$Recommendations.Add("Review hardcoded paths. Portable tools should use toolkit-relative paths.")
    }

    $Status = if ($Findings.Count -gt 0) { "WARNING" } else { "PASS" }
    $Summary = if ($Status -eq "PASS") { "Baseline compatibility checks passed." } else { "Compatibility warnings detected." }
    [void]$Recommendations.Add("Use Compatibility Center for detailed compatibility reporting.")
    return New-CheckResult -Name "Compatibility Status" -Status $Status -Summary $Summary -Details @($Details) -Findings @($Findings) -Recommendations @($Recommendations)
}

function Test-RepairStatus {
    $Details = New-Object System.Collections.ArrayList
    $Findings = New-Object System.Collections.ArrayList
    $Recommendations = New-Object System.Collections.ArrayList
    $RequiredPaths = @("Core","Framework","Modules","Config","Cache","Logs","Exports","Docs")
    foreach ($Name in $RequiredPaths) {
        if (Test-Path (Join-Path $ToolkitRoot $Name)) { [void]$Details.Add("Present: $Name") }
        else { [void]$Findings.Add("Missing required path: $Name") }
    }
    $Registry = Join-Path $ToolkitRoot "Cache\toolkit_registry.json"
    if (Test-Path $Registry) { [void]$Details.Add("Registry present: Cache\toolkit_registry.json") }
    else { [void]$Findings.Add("Registry missing: Cache\toolkit_registry.json") }
    if (Test-Path (Join-Path $ToolkitRoot "Framework\Framework_Repair\run.ps1")) { [void]$Details.Add("Framework Repair component present") }
    else { [void]$Findings.Add("Framework Repair component missing") }

    $Status = if ($Findings.Count -gt 0) { "WARNING" } else { "PASS" }
    $Summary = if ($Status -eq "PASS") { "Framework repair prerequisites are available." } else { "Repair prerequisites need attention." }
    if ($Status -ne "PASS") { [void]$Recommendations.Add("Run Framework Repair to recreate missing framework-owned state.") }
    return New-CheckResult -Name "Repair Capability" -Status $Status -Summary $Summary -Details @($Details) -Findings @($Findings) -Recommendations @($Recommendations)
}

function Test-DocumentationStatus {
    $Details = New-Object System.Collections.ArrayList
    $Findings = New-Object System.Collections.ArrayList
    $Recommendations = New-Object System.Collections.ArrayList
    $Docs = Join-Path $ToolkitRoot "Docs"
    if (Test-Path $Docs) { [void]$Details.Add("Docs folder present") }
    else { [void]$Findings.Add("Docs folder missing") }

    $DocsWanted = @("Framework_Design_Notes.md","Lessons_Learned.md","Public_Contracts.md")
    foreach ($File in $DocsWanted) {
        $Path = Join-Path $Docs $File
        if (Test-Path $Path) { [void]$Details.Add("Present: Docs\$File") }
        else { [void]$Findings.Add("Missing doc: Docs\$File") }
    }

    if (Test-Path (Join-Path $ToolkitRoot "README.md")) { [void]$Details.Add("README.md present") }
    elseif (Test-Path (Join-Path $ToolkitRoot "README.txt")) { [void]$Details.Add("README.txt present") }
    else { [void]$Findings.Add("README missing") }

    $HistoryDocs = @("Framework_History.md","Release_History.md","Core_Catalog.md","Framework_Architecture.md","Future_Framework_Notes.md")
    $MissingHistoryDocs = @()
    foreach ($File in $HistoryDocs) {
        $Path = Join-Path $Docs $File
        if (Test-Path $Path) { [void]$Details.Add("Present: Docs\$File") }
        else { $MissingHistoryDocs += $File }
    }

    if ($MissingHistoryDocs.Count -gt 0) {
        [void]$Details.Add("Knowledge Preservation Pack pending: $($MissingHistoryDocs -join ', ')")
        [void]$Recommendations.Add("Build 31 should create the Knowledge Preservation Pack and consolidate temporary framework notes into Docs.")
    }

    $Status = if ($Findings.Count -gt 0) { "WARNING" } else { "PASS" }
    $Summary = if ($Status -eq "PASS") { "Release documentation baseline is present. Knowledge Preservation may still be pending for Build 31." } else { "Documentation needs attention before final release." }
    return New-CheckResult -Name "Documentation Status" -Status $Status -Summary $Summary -Details @($Details) -Findings @($Findings) -Recommendations @($Recommendations)
}


function Test-AllScriptSyntax {
    $Details = New-Object System.Collections.ArrayList
    $Findings = New-Object System.Collections.ArrayList
    $Recommendations = New-Object System.Collections.ArrayList

    $Roots = @("Toolkit.ps1", "Core", "Framework", "Modules")
    $Scripts = New-Object System.Collections.ArrayList
    foreach ($RootName in $Roots) {
        $Path = Join-Path $ToolkitRoot $RootName
        if (-not (Test-Path $Path)) { continue }
        if ((Get-Item $Path).PSIsContainer) {
            Get-ChildItem -Path $Path -Recurse -Filter "*.ps1" -File -ErrorAction SilentlyContinue | ForEach-Object { [void]$Scripts.Add($_.FullName) }
        } else {
            [void]$Scripts.Add($Path)
        }
    }

    foreach ($ScriptPath in @($Scripts | Sort-Object -Unique)) {
        $ParseError = Test-ScriptParse -Path $ScriptPath
        if ($ParseError) {
            $Rel = $ScriptPath.Substring($ToolkitRoot.Length).TrimStart('\','/')
            [void]$Findings.Add("Parse error: $Rel -> $ParseError")
        }
    }

    [void]$Details.Add("PowerShell scripts checked: $($Scripts.Count)")
    $Status = if ($Findings.Count -gt 0) { "FAIL" } else { "PASS" }
    $Summary = if ($Status -eq "PASS") { "All PowerShell scripts parsed cleanly." } else { "One or more PowerShell scripts failed parser validation." }
    if ($Status -ne "PASS") { [void]$Recommendations.Add("Open the listed script and fix parser errors before release.") }
    return New-CheckResult -Name "All Script Syntax" -Status $Status -Summary $Summary -Details @($Details) -Findings @($Findings) -Recommendations @($Recommendations)
}

function Test-BackNavigationCoverage {
    $Details = New-Object System.Collections.ArrayList
    $Findings = New-Object System.Collections.ArrayList
    $Recommendations = New-Object System.Collections.ArrayList

    $Roots = @("Toolkit.ps1", "Framework", "Modules")
    $Files = New-Object System.Collections.ArrayList
    foreach ($RootName in $Roots) {
        $Path = Join-Path $ToolkitRoot $RootName
        if (-not (Test-Path $Path)) { continue }
        if ((Get-Item $Path).PSIsContainer) {
            Get-ChildItem -Path $Path -Recurse -Include *.ps1,*.bat,*.cmd -File -ErrorAction SilentlyContinue | ForEach-Object { [void]$Files.Add($_.FullName) }
        } else { [void]$Files.Add($Path) }
    }

    $MenuFiles = 0
    foreach ($FilePath in @($Files | Sort-Object -Unique)) {
        try { $Text = Get-Content $FilePath -Raw -ErrorAction Stop } catch { continue }
        if ($Text -notmatch '\[B\]\s*Back') { continue }
        $MenuFiles++
        $Rel = $FilePath.Substring($ToolkitRoot.Length).TrimStart('\','/')

        $HasHandler = $false
        if ($Text -match '(?i)["'']B["'']\s*\{') { $HasHandler = $true }
        if ($Text -match '(?i)\.ToUpper\(\)\s*-eq\s*["'']B["'']') { $HasHandler = $true }
        if ($Text -match '(?i)-eq\s*["'']B["'']') { $HasHandler = $true }
        if ($Text -match '(?i)switch\s*\(.*?\.ToUpper\(\).*?\)') { if ($Text -match '(?i)["'']B["'']\s*\{') { $HasHandler = $true } }
        if (-not $HasHandler) { [void]$Findings.Add("Back shown but handler not detected: $Rel") }
    }

    [void]$Details.Add("Files showing [B] Back: $MenuFiles")
    $Status = if ($Findings.Count -gt 0) { "WARNING" } else { "PASS" }
    $Summary = if ($Status -eq "PASS") { "Back handlers were detected for menus that show [B] Back." } else { "Some menus show [B] Back but a handler was not detected." }
    if ($Status -ne "PASS") { [void]$Recommendations.Add("Manually test the listed menus and add a B/back handler if missing.") }
    return New-CheckResult -Name "Back Navigation Coverage" -Status $Status -Summary $Summary -Details @($Details) -Findings @($Findings) -Recommendations @($Recommendations)
}

function Test-LegacyRepositoryPaths {
    $Details = New-Object System.Collections.ArrayList
    $Findings = New-Object System.Collections.ArrayList
    $Recommendations = New-Object System.Collections.ArrayList

    $LegacyPhysical = @(
        "Repository\ISO",
        "Repository\EXE",
        "Repository\MSI",
        "Repository\MSIX",
        "Repository\ZIP",
        "Repository\Portable",
        "Repository\Updates",
        "Repository\Software\ISO",
        "Repository\Software\Archives",
        "Repository\Software\Packages",
        "Repository\Software\GitHub"
    )
    foreach ($Rel in $LegacyPhysical) {
        if (Test-Path (Join-Path $ToolkitRoot $Rel)) { [void]$Findings.Add("Legacy repository folder exists: $Rel") }
    }

    $Patterns = @(
        'Repository\\ISO',
        'Repository\\EXE',
        'Repository\\MSI',
        'Repository\\MSIX',
        'Repository\\ZIP',
        'Repository\\Portable',
        'Repository\\Updates',
        'Repository\\Software\\ISO',
        'Repository\\Software\\Archives',
        'Repository\\Software\\Packages',
        'Repository\\Software\\GitHub'
    )
    $ScanRoots = @("Toolkit.ps1", "Core", "Framework", "Modules")
    $Hits = New-Object System.Collections.ArrayList
    foreach ($RootName in $ScanRoots) {
        $Root = Join-Path $ToolkitRoot $RootName
        if (-not (Test-Path $Root)) { continue }
        $Items = if ((Get-Item $Root).PSIsContainer) { Get-ChildItem -Path $Root -Recurse -Include *.ps1,*.bat,*.cmd,*.json,*.txt,*.md -File -ErrorAction SilentlyContinue } else { @(Get-Item $Root) }
        foreach ($Item in $Items) {
            try { $Text = Get-Content $Item.FullName -Raw -ErrorAction Stop } catch { continue }
            foreach ($Pattern in $Patterns) {
                if ($Text -match $Pattern) {
                    $Rel = $Item.FullName.Substring($ToolkitRoot.Length).TrimStart('\','/')
                    [void]$Hits.Add("$Rel -> $Pattern")
                }
            }
        }
    }
    $UniqueHits = @($Hits | Sort-Object -Unique)
    [void]$Details.Add("Legacy code/doc path references found: $($UniqueHits.Count)")
    foreach ($Hit in @($UniqueHits | Select-Object -First 15)) { [void]$Findings.Add("Legacy path reference: $Hit") }
    if ($UniqueHits.Count -gt 15) { [void]$Findings.Add("Additional legacy references omitted from summary; export report for full list.") }

    $Status = if ($Findings.Count -gt 0) { "WARNING" } else { "PASS" }
    $Summary = if ($Status -eq "PASS") { "No legacy repository paths were found." } else { "Legacy repository paths need review before RC." }
    if ($Status -ne "PASS") { [void]$Recommendations.Add("Replace legacy paths with Repository\Software, Repository\Packages, Repository\Archives, Repository\Disk Images, Repository\Documents, Repository\Scripts, or Repository\Custom.") }
    return New-CheckResult -Name "Legacy Repository Paths" -Status $Status -Summary $Summary -Details @($Details) -Findings @($Findings) -Recommendations @($Recommendations)
}

function Test-LibraryHealth {
    $Details = New-Object System.Collections.ArrayList
    $Findings = New-Object System.Collections.ArrayList
    $Recommendations = New-Object System.Collections.ArrayList

    $Libraries = @(
        "Config\metadata.library.json",
        "Config\repository.formats.library.json",
        "Config\detection.library.json",
        "Config\metadata.core.json",
        "Config\repository.formats.core.json",
        "Config\detection.core.json"
    )
    foreach ($Rel in $Libraries) {
        $Path = Join-Path $ToolkitRoot $Rel
        if (-not (Test-Path $Path)) { [void]$Findings.Add("Missing library: $Rel"); continue }
        try {
            $null = Get-Content $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            [void]$Details.Add("JSON OK: $Rel")
        } catch { [void]$Findings.Add("Invalid JSON: $Rel -> $($_.Exception.Message)") }

        if ($Rel -like "*.library.json") {
            $Bak1 = "$Path.bak1"
            $Bak2 = "$Path.bak2"
            if (Test-Path $Bak1) { [void]$Details.Add("Backup 1 present: $Rel.bak1") } else { [void]$Findings.Add("Missing backup 1 for $Rel") }
            if (Test-Path $Bak2) { [void]$Details.Add("Backup 2 present: $Rel.bak2") } else { [void]$Findings.Add("Missing backup 2 for $Rel") }
        }
    }

    $Status = if ($Findings.Count -gt 0) { "WARNING" } else { "PASS" }
    $Summary = if ($Status -eq "PASS") { "Framework libraries and backups are healthy." } else { "Library or backup issues were detected." }
    if ($Status -ne "PASS") { [void]$Recommendations.Add("Use Library Recovery to create backups or restore corrupted libraries.") }
    return New-CheckResult -Name "Library Health" -Status $Status -Summary $Summary -Details @($Details) -Findings @($Findings) -Recommendations @($Recommendations)
}

function Test-ReleaseReadinessState {
    $Details = New-Object System.Collections.ArrayList
    $Findings = New-Object System.Collections.ArrayList
    $Recommendations = New-Object System.Collections.ArrayList

    $Incoming = Join-Path $ToolkitRoot "Incoming"
    if (Test-Path $Incoming) {
        $QaIncoming = @(Get-ChildItem -Path $Incoming -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "QA_*" -or $_.Name -like "QA.*" })
        [void]$Details.Add("QA files in Incoming: $($QaIncoming.Count)")
        if ($QaIncoming.Count -gt 0) { [void]$Findings.Add("QA test files still exist in Incoming.") }
    }

    $Config = Join-Path $ToolkitRoot "Config"
    $RecordFiles = @("software.records.json","package.records.json","document.records.json","archive.records.json","diskimage.records.json","script.records.json","custom.records.json")
    foreach ($File in $RecordFiles) {
        $Path = Join-Path $Config $File
        if (-not (Test-Path $Path)) { continue }
        try {
            $JsonText = Get-Content $Path -Raw -ErrorAction Stop
            if ($JsonText -match 'QA_Test|QA_Detect|QA_Project') { [void]$Findings.Add("QA records present in Config\$File") }
        } catch {}
    }

    $Errors = Join-Path $ToolkitRoot "Logs\errors.log"
    if (Test-Path $Errors) {
        $Content = Get-Content $Errors -Raw -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($Content)) { [void]$Findings.Add("Logs\errors.log is not empty.") }
        else { [void]$Details.Add("errors.log present and empty") }
    } else { [void]$Details.Add("errors.log not present") }

    $Status = if ($Findings.Count -gt 0) { "WARNING" } else { "PASS" }
    $Summary = if ($Status -eq "PASS") { "No obvious QA leftovers or error logs were found." } else { "QA leftovers or error logs need review before public release." }
    if ($Status -ne "PASS") { [void]$Recommendations.Add("Use Development Tools > Clear Repository Test Data before publishing a public build.") }
    return New-CheckResult -Name "Release Readiness State" -Status $Status -Summary $Summary -Details @($Details) -Findings @($Findings) -Recommendations @($Recommendations)
}

function Invoke-RCValidation {
    $Start = Get-Date
    $Results = @(
        Test-CoreIntegrity
        Test-FrameworkIntegrity
        Test-AllScriptSyntax
        Test-NavigationIntegrity
        Test-BackNavigationCoverage
        Test-LegacyRepositoryPaths
        Test-LibraryHealth
        Test-ReleaseReadinessState
        Test-CompatibilityStatus
        Test-RepairStatus
        Test-DocumentationStatus
    )
    $End = Get-Date
    $Overall = Get-OverallStatus $Results
    $ToolCount = @(Get-ToolJsonObjects).Count
    $script:LastRCResults = [PSCustomObject]@{
        Generated = $End
        DurationSeconds = [Math]::Round(($End - $Start).TotalSeconds,2)
        ToolkitRoot = $ToolkitRoot
        FrameworkVersion = "2.0"
        OverallStatus = $Overall
        ComponentsChecked = $ToolCount
        Results = @($Results)
    }
    return $script:LastRCResults
}

function Show-RCSummary {
    param($Data)
    if (-not $Data) { $Data = Invoke-RCValidation }
    Show-LocalHeader "FRAMEWORK 2.0 RELEASE AUDIT"
    foreach ($Result in $Data.Results) {
        $Name = $Result.Name.PadRight(26,'.')
        Write-Host "$Name $($Result.Status)"
        Write-Host "  $($Result.Summary)"
    }
    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "Framework Version .......... $($Data.FrameworkVersion)"
    Write-Host "RC Status .................. $($Data.OverallStatus)"
    Write-Host "Validation Time ............ $($Data.DurationSeconds) sec"
    Write-Host "Components Checked ......... $($Data.ComponentsChecked)"
    Write-Host ""

    $Findings = @($Data.Results | ForEach-Object { $_.Findings } | Where-Object { $_ })
    if ($Findings.Count -gt 0) {
        Write-Host "Findings"
        Write-Host "--------"
        foreach ($Finding in $Findings | Select-Object -First 12) { Write-Host "- $Finding" }
        if ($Findings.Count -gt 12) { Write-Host "- Additional findings available in Detailed Results." }
        Write-Host ""
    }
    Wait-Back
}

function Show-RCDetails {
    if (-not $script:LastRCResults) { $script:LastRCResults = Invoke-RCValidation }
    $Data = $script:LastRCResults
    Show-LocalHeader "RELEASE AUDIT DETAILS"
    Write-Host "Generated: $($Data.Generated)"
    Write-Host "Toolkit Root: $($Data.ToolkitRoot)"
    Write-Host "Overall Status: $($Data.OverallStatus)"
    Write-Host ""

    foreach ($Result in $Data.Results) {
        Write-Host "------------------------------------------------------------"
        Write-Host $Result.Name
        Write-Host "Status : $($Result.Status)"
        Write-Host "Summary: $($Result.Summary)"
        Write-Host ""
        if ($Result.Details.Count -gt 0) {
            Write-Host "Details:"
            foreach ($Detail in $Result.Details) { Write-Host "  $Detail" }
            Write-Host ""
        }
        if ($Result.Findings.Count -gt 0) {
            Write-Host "Findings:"
            foreach ($Finding in $Result.Findings) { Write-Host "  - $Finding" }
            Write-Host ""
        }
        if ($Result.Recommendations.Count -gt 0) {
            Write-Host "Recommendations:"
            foreach ($Rec in $Result.Recommendations) { Write-Host "  - $Rec" }
            Write-Host ""
        }
    }
    Wait-Back
}

function Export-RCReport {
    if (-not $script:LastRCResults) { $script:LastRCResults = Invoke-RCValidation }
    $Data = $script:LastRCResults
    $ExportDir = Join-Path $ToolkitRoot "Exports"
    if (-not (Test-Path $ExportDir)) { New-Item -ItemType Directory -Path $ExportDir -Force | Out-Null }
    $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Report = Join-Path $ExportDir "Framework_2.0_RC1_Report_$Stamp.html"

    $Rows = New-Object System.Collections.ArrayList
    foreach ($Result in $Data.Results) {
        $DetailText = (($Result.Details + $Result.Findings + $Result.Recommendations) -join "`n")
        $DetailText = [System.Web.HttpUtility]::HtmlEncode($DetailText) -replace "`n", "<br>"
        [void]$Rows.Add("<tr><td>$([System.Web.HttpUtility]::HtmlEncode($Result.Name))</td><td>$($Result.Status)</td><td>$([System.Web.HttpUtility]::HtmlEncode($Result.Summary))</td><td>$DetailText</td></tr>")
    }

    $Html = @"
<html>
<head>
<title>Windows Modular Toolkit - Framework 2.0 RC1 Report</title>
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #ccc; padding: 8px; vertical-align: top; }
th { background: #f2f2f2; }
.status { font-size: 1.2em; font-weight: bold; }
</style>
</head>
<body>
<h1>Windows Modular Toolkit - Framework 2.0 RC1 Report</h1>
<p>Generated: $($Data.Generated)</p>
<p>Toolkit Root: $([System.Web.HttpUtility]::HtmlEncode($Data.ToolkitRoot))</p>
<p class="status">RC Status: $($Data.OverallStatus)</p>
<p>Validation Time: $($Data.DurationSeconds) seconds</p>
<p>Components Checked: $($Data.ComponentsChecked)</p>
<table>
<tr><th>Check</th><th>Status</th><th>Summary</th><th>Details / Findings / Recommendations</th></tr>
$($Rows -join "`n")
</table>
</body>
</html>
"@
    $Html | Set-Content -Path $Report -Encoding UTF8

    Show-LocalHeader "RC1 REPORT EXPORTED"
    Write-Host "Report created:"
    Write-Host $Report
    Write-Host ""
    Write-Host "[O] Open Report"
    Write-Host "[B] Back"
    $Choice = Read-Host "Selection"
    if ($Choice.ToUpper() -eq "O") { Start-Process $Report }
}

while ($true) {
    Show-LocalHeader "RELEASE CANDIDATE AUDIT"
    Write-Host "[1] Run Full RC Audit"
    Write-Host "[2] View Audit Results"
    Write-Host "[3] Export RC Audit Report"
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = Read-Host "Selection"
    switch ($Choice.ToUpper()) {
        "1" { $script:LastRCResults = Invoke-RCValidation; Show-RCSummary $script:LastRCResults }
        "2" { Show-RCDetails }
        "3" { Export-RCReport }
        "B" { return }
    }
}
