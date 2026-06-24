param()


$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FrameworkDir = Split-Path -Parent $ScriptDir
$ToolkitRoot = Split-Path -Parent $FrameworkDir
$ConfigDir = Join-Path $ToolkitRoot "Config"
$LogsDir = Join-Path $ToolkitRoot "Logs"
$DocsDir = Join-Path $ToolkitRoot "Docs"
$ArchDir = Join-Path $DocsDir "Architecture"
$ReportPath = Join-Path $ArchDir "Framework_Consolidation_Report.md"
$JsonPath = Join-Path $ConfigDir "capability_audit.json"
$LogPath = Join-Path $LogsDir "framework_test.log"

foreach ($Dir in @($ConfigDir,$LogsDir,$DocsDir,$ArchDir)) {
    if (!(Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir | Out-Null }
}

function Write-TestLogLocal {
    param([string]$Area,[string]$Status,[string]$Message)
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    Add-Content -Path $LogPath -Value "$Stamp | $Status | $Area | $Message" -Encoding UTF8
}

function Show-Header {
    param([string]$Title)
    Clear-Host
    Write-Host "============================================================"
    Write-Host " $Title"
    Write-Host "============================================================"
    Write-Host ""
}

function Get-ToolJsonObjects {
    $Files = @(Get-ChildItem -Path $FrameworkDir -Recurse -Filter "tool.json" -ErrorAction SilentlyContinue)
    $Items = @()
    foreach ($File in $Files) {
        try {
            $Obj = Get-Content $File.FullName -Raw | ConvertFrom-Json
            $Name = [string]$Obj.name
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = Split-Path (Split-Path $File.FullName -Parent) -Leaf }
            $Items += [PSCustomObject]@{
                name = $Name
                description = [string]$Obj.description
                category = [string]$Obj.category
                framework_category = [string]$Obj.framework_category
                keywords = @($Obj.keywords)
                path = (Split-Path $File.FullName -Parent)
                folder = (Split-Path (Split-Path $File.FullName -Parent) -Leaf)
            }
        } catch {
            $Items += [PSCustomObject]@{
                name = Split-Path (Split-Path $File.FullName -Parent) -Leaf
                description = "Could not read tool.json"
                category = "Unknown"
                framework_category = "Unknown"
                keywords = @()
                path = (Split-Path $File.FullName -Parent)
                folder = (Split-Path (Split-Path $File.FullName -Parent) -Leaf)
            }
        }
    }
    return @($Items | Sort-Object name)
}

function Get-CapabilityFamily {
    param($Tool)
    $Text = (($Tool.name, $Tool.description, $Tool.folder, ($Tool.keywords -join ' ')) -join ' ').ToLower()
    if ($Text -match 'search|find|category browser|launcher') { return 'Search Family' }
    if ($Text -match 'metadata|risk|modifier|description fixer') { return 'Metadata Family' }
    if ($Text -match 'validat|analyz|static|runtime|dry run|health|compatibility|integrity') { return 'Validation / Health Family' }
    if ($Text -match 'dashboard|recommendation|status|snapshot') { return 'Dashboard Family' }
    if ($Text -match 'category') { return 'Category Family' }
    if ($Text -match 'installer|install|download|winget|package') { return 'Installer Family' }
    if ($Text -match 'workspace') { return 'Workspace Family' }
    if ($Text -match 'backup|restore|import|export') { return 'Backup / Export Family' }
    if ($Text -match 'registry|cache|repair|upgrade|bootstrap|core|framework') { return 'Framework Maintenance Family' }
    if ($Text -match 'support|guide|docs|documentation|release notes') { return 'Documentation / Support Family' }
    return 'General / Review Family'
}

function Get-Recommendation {
    param($Tool, [string]$Family)
    $Name = [string]$Tool.name
    $Folder = [string]$Tool.folder

    switch ($Family) {
        'Search Family' {
            if ($Name -eq 'Search Foundation') { return @('KEEP','Search Center','Primary visible search capability.') }
            return @('MERGE','Search Center','Search/browse/launcher behavior should become a Search Center mode.')
        }
        'Metadata Family' {
            if ($Name -eq 'Metadata Engine') { return @('KEEP','Metadata Center','Foundation service and center owner for metadata.') }
            return @('MERGE','Metadata Center','Metadata repair/edit/risk functions should become metadata modes.')
        }
        'Validation / Health Family' {
            if ($Name -eq 'Validation Center') { return @('KEEP','Validation Center','Primary validation center.') }
            if ($Name -match 'Health Center|Compatibility|Integrity') { return @('REVIEW','Validation Center / Dashboard Center','Health-style tools may belong under Validation or Dashboard depending on UI.') }
            return @('MERGE','Validation Center','Validation modes should live inside Validation Center.')
        }
        'Dashboard Family' {
            if ($Folder -eq 'Dashboard_Health_Center' -or $Name -match 'Dashboard.*Health|Dashboard') { return @('KEEP','Dashboard Center','Best candidate for primary dashboard center; verify against Enhanced Dashboard.') }
            if ($Folder -eq 'Enhanced_Dashboard') { return @('MERGE','Dashboard Center','Enhanced view should be a Dashboard Center mode.') }
            return @('REVIEW','Dashboard Center','Compare with Dashboard Center before retire/merge.')
        }
        'Category Family' {
            if ($Name -eq 'Category Manager') { return @('KEEP','Category Center','Primary category management capability.') }
            return @('MERGE','Category Center / Search Center','Category browsing/search/architecture should become modes.')
        }
        'Installer Family' {
            if ($Name -eq 'Repository Manager') { return @('KEEP','Repository','Primary repository management capability.') }
            return @('MERGE','Installer Center','Installer/download/package helpers should become installer modes.')
        }
        'Workspace Family' {
            if ($Name -eq 'Workspace') { return @('KEEP','Workspace Center','Primary workspace capability.') }
            return @('MERGE','Workspace Center','Workspace helper behavior should become workspace modes.')
        }
        'Backup / Export Family' {
            if ($Name -match 'Export Center') { return @('KEEP','Backup / Export Center','Primary export capability.') }
            return @('MERGE','Backup / Export Center','Backup/export cleanup should become modes.')
        }
        'Framework Maintenance Family' {
            if ($Name -match 'Registry Manager|Framework Repair') { return @('KEEP','Framework Center','Core maintenance capability.') }
            return @('REVIEW','Framework Center','May be a framework maintenance mode or development-only helper.')
        }
        'Documentation / Support Family' {
            return @('KEEP','Support Center','Documentation/support is user-facing and should remain accessible.')
        }
        default { return @('REVIEW','Unknown','Needs human review before merge or retire.') }
    }
}

function Invoke-CapabilityAudit {
    $Tools = @(Get-ToolJsonObjects)
    $Rows = @()
    foreach ($Tool in $Tools) {
        $Family = Get-CapabilityFamily $Tool
        $Rec = Get-Recommendation $Tool $Family
        $Rows += [PSCustomObject]@{
            name = $Tool.name
            folder = $Tool.folder
            family = $Family
            action = $Rec[0]
            destination = $Rec[1]
            reason = $Rec[2]
            path = $Tool.path
        }
    }

    $Rows | ConvertTo-Json -Depth 8 | Set-Content -Path $JsonPath -Encoding UTF8
    New-CapabilityAuditReport -Rows $Rows -Path $ReportPath
    Write-TestLogLocal "Capability Audit" "PASS" "Reviewed $($Rows.Count) framework tools"
    return @($Rows)
}

function New-CapabilityAuditReport {
    param([array]$Rows,[string]$Path)
    $Lines = @()
    $Lines += "# Framework Consolidation Report"
    $Lines += ""
    $Lines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $Lines += ""
    $Lines += "## Framework Rule"
    $Lines += ""
    $Lines += "One capability = one visible tool. Additional behavior should become a mode, view, filter, or submenu inside the matching center."
    $Lines += ""
    $Lines += "## Summary"
    $Lines += ""
    foreach ($Action in @('KEEP','MERGE','RETIRE','REVIEW')) {
        $Count = @($Rows | Where-Object { $_.action -eq $Action }).Count
        $Lines += "- ${Action}: $Count"
    }
    $Lines += "- Total framework tools reviewed: $($Rows.Count)"
    $Lines += ""

    foreach ($Family in @($Rows.family | Sort-Object -Unique)) {
        $Lines += "## $Family"
        $Lines += ""
        $FamilyRows = @($Rows | Where-Object { $_.family -eq $Family } | Sort-Object action,name)
        foreach ($Row in $FamilyRows) {
            $Lines += "### $($Row.name)"
            $Lines += ""
            $Lines += "- Action: $($Row.action)"
            $Lines += "- Destination: $($Row.destination)"
            $Lines += "- Reason: $($Row.reason)"
            $Lines += "- Folder: $($Row.folder)"
            $Lines += ""
        }
    }
    $Lines | Set-Content -Path $Path -Encoding UTF8
}

function Show-AuditSummary {
    $Rows = @()
    if (Test-Path $JsonPath) {
        $Rows = @(Get-Content $JsonPath -Raw | ConvertFrom-Json)
    } else {
        $Rows = @(Invoke-CapabilityAudit)
    }
    Show-Header "CAPABILITY AUDIT SUMMARY"
    Write-Host "Total reviewed: $($Rows.Count)"
    Write-Host ""
    foreach ($Action in @('KEEP','MERGE','RETIRE','REVIEW')) {
        $Count = @($Rows | Where-Object { $_.action -eq $Action }).Count
        Write-Host ($Action.PadRight(8) + ": " + $Count)
    }
    Write-Host ""
    Write-Host "Families"
    Write-Host "--------"
    foreach ($Family in @($Rows.family | Sort-Object -Unique)) {
        $Count = @($Rows | Where-Object { $_.family -eq $Family }).Count
        Write-Host "$Family ($Count)"
    }
    Write-Host ""
    Write-Host "Report: $ReportPath"
    Write-Host "Index : $JsonPath"
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Show-FamilyReview {
    $Rows = @()
    if (Test-Path $JsonPath) { $Rows = @(Get-Content $JsonPath -Raw | ConvertFrom-Json) } else { $Rows = @(Invoke-CapabilityAudit) }
    $Families = @($Rows.family | Sort-Object -Unique)
    while ($true) {
        Show-Header "CAPABILITY FAMILY REVIEW"
        for ($i=0; $i -lt $Families.Count; $i++) { Write-Host "[$($i+1)] $($Families[$i])" }
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = Read-Host "Selection"
        if ($Choice.ToUpper() -eq 'B') { return }
        $Num = 0
        if ([int]::TryParse($Choice, [ref]$Num) -and $Num -ge 1 -and $Num -le $Families.Count) {
            $Fam = $Families[$Num-1]
            Show-Header $Fam.ToUpper()
            $FRows = @($Rows | Where-Object { $_.family -eq $Fam } | Sort-Object action,name)
            foreach ($Row in $FRows) {
                Write-Host "$($Row.action): $($Row.name)" -ForegroundColor Cyan
                Write-Host "  Destination: $($Row.destination)"
                Write-Host "  Reason     : $($Row.reason)" -ForegroundColor DarkGray
                Write-Host ""
            }
            Read-Host "Press Enter to continue"
        }
    }
}

function Open-Report {
    if (!(Test-Path $ReportPath)) { Invoke-CapabilityAudit | Out-Null }
    Start-Process notepad.exe $ReportPath
}

while ($true) {
    Show-Header "CAPABILITY AUDIT"
    Write-Host "Framework consolidation review."
    Write-Host ""
    Write-Host "Goal: identify what should KEEP, MERGE, RETIRE, or REVIEW."
    Write-Host ""
    Write-Host "[1] Run Capability Audit"
    Write-Host "[2] View Summary"
    Write-Host "[3] Review Families"
    Write-Host "[4] Open Consolidation Report"
    Write-Host "[5] Open Audit JSON"
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = Read-Host "Selection"
    switch ($Choice.ToUpper()) {
        '1' {
            Show-Header "RUN CAPABILITY AUDIT"
            try {
                $Rows = @(Invoke-CapabilityAudit)
                Write-Host "Capability audit complete." -ForegroundColor Green
                Write-Host "Reviewed: $($Rows.Count) framework tools"
                Write-Host "Report  : $ReportPath"
                Write-Host "JSON    : $JsonPath"
            } catch {
                Write-Host "[FAIL] Capability audit failed." -ForegroundColor Red
                Write-Host $_.Exception.Message -ForegroundColor Red
                Write-TestLogLocal "Capability Audit" "FAIL" $_.Exception.Message
            }
            Read-Host "Press Enter to continue"
        }
        '2' { Show-AuditSummary }
        '3' { Show-FamilyReview }
        '4' { Open-Report }
        '5' { if (!(Test-Path $JsonPath)) { Invoke-CapabilityAudit | Out-Null }; Start-Process notepad.exe $JsonPath }
        'B' { return }
    }
}
