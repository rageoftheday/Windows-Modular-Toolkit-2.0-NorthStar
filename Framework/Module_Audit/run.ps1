# ============================================================
# WINDOWS MODULAR TOOLKIT
# Module Audit
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
$ModulesRoot = Join-Path $Root "Modules"
$ReportRoot = Join-Path $Root "Logs\module-audit"
if (!(Test-Path $ReportRoot)) { New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null }
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$CsvPath = Join-Path $ReportRoot "module_audit_$Stamp.csv"

function Write-StatusLine {
    param([string]$Status, [string]$Message)
    switch ($Status) {
        "PASS" { Write-Host "[PASS] $Message" -ForegroundColor Green }
        "WARN" { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
        "FAIL" { Write-Host "[FAIL] $Message" -ForegroundColor Red }
        default { Write-Host "[$Status] $Message" }
    }
}

function Get-JsonValue {
    param([object]$Json, [string]$Name, [object]$Default = $null)
    if ($null -eq $Json) { return $Default }
    if ($Json.PSObject.Properties.Name -contains $Name) { return $Json.$Name }
    return $Default
}

function Test-PowerShellSyntax {
    param([string]$Path)
    if (!(Test-Path $Path)) { return @('Missing run.ps1') }
    try {
        $content = Get-Content -Path $Path -Raw -ErrorAction Stop
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors -and $errors.Count -gt 0) {
            return @($errors | ForEach-Object { "PowerShell syntax error line $($_.Extent.StartLineNumber), column $($_.Extent.StartColumnNumber): $($_.Message)" })
        }
        return @()
    } catch {
        return @("Could not parse run.ps1: $($_.Exception.Message)")
    }
}


function Test-PowerShellScriptQuality {
    param([string]$Path)
    $warnings = @()
    if (!(Test-Path $Path)) { return $warnings }
    $lines = @(Get-Content -Path $Path -ErrorAction SilentlyContinue)
    $commandPattern = '(?i)\b(Write-Host|Start-Process|Invoke-Item|Remove-Item|Set-Item|New-Item|Get-ChildItem|Get-Item|Copy-Item|Move-Item|Restart-Computer|Stop-Computer)\b'
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $matches = [regex]::Matches($line, $commandPattern)
        if ($matches.Count -gt 1) {
            $warnings += "Suspicious line $($i+1): multiple PowerShell commands appear on one line. Possible pasted commands ran together."
        }
    }
    return $warnings
}



function Select-FailedModuleForRepair {
    param([object[]]$Rows)
    $failed = @($Rows | Where-Object { $_.Status -eq 'FAIL' })
    if ($failed.Count -eq 0) { return }
    Write-Host ""
    Write-Host "Repair options:" -ForegroundColor Yellow
    Write-Host "[E] Edit failed module run.ps1 in Notepad"
    Write-Host "[F] Open failed module folder"
    Write-Host "[Enter] Continue"
    $action = (Read-Host "Selection").Trim().ToUpper()
    if ([string]::IsNullOrWhiteSpace($action)) { return }
    if ($action -notin @('E','F')) { return }
    Write-Host ""
    Write-Host "Failed modules:" -ForegroundColor Yellow
    for ($i=0; $i -lt $failed.Count; $i++) { Write-Host "[$($i+1)] $($failed[$i].Module)" }
    Write-Host "[B] Back"
    $raw = (Read-Host "Selection").Trim().ToUpper()
    if ($raw -eq 'B') { return }
    $n = 0
    if ([int]::TryParse($raw, [ref]$n) -and $n -ge 1 -and $n -le $failed.Count) {
        $folder = Join-Path $ModulesRoot $failed[$n-1].Folder
        if ($action -eq 'E') {
            $ps1 = Join-Path $folder 'run.ps1'
            if (Test-Path $ps1) { Start-Process notepad.exe $ps1 }
            else { Write-Host "run.ps1 not found: $ps1" -ForegroundColor Red; Read-Host "Press Enter to continue" | Out-Null }
        }
        elseif ($action -eq 'F') {
            if (Test-Path $folder) { Start-Process explorer.exe $folder }
        }
    }
}

Clear-Host
Write-Host "============================================================"
Write-Host " MODULE AUDIT"
Write-Host "============================================================"
Write-Host ""
Write-Host "Audits modules for legacy/deprecated patterns, weak metadata, duplicate names, and BAT syntax inside PS1 files."
Write-Host ""

$Rows = @()
$AllNames = @{}
$DeprecatedFields = @('author','estimated_time','important')
$BatchSyntaxPatterns = @(
    'cmd\.exe\s+/c\s+"if\s+',
    '\berrorlevel\b',
    '^\s*setlocal\b',
    '^\s*endlocal\b',
    '^\s*goto\b',
    '^\s*:\w+',
    '\bif\s+exist\b',
    '%~dp0',
    '%errorlevel%'
)
$RiskWords = @('Remove-Item','Format-Volume','diskpart','reg delete','bcdedit','Reset-','Stop-Computer','Restart-Computer','Clear-Disk','Remove-Partition')

if (!(Test-Path $ModulesRoot)) {
    Write-StatusLine "FAIL" "Modules folder not found: $ModulesRoot"
    Read-Host "Press Enter to continue"
    return
}

$ModuleFolders = @(Get-ChildItem -Path $ModulesRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
foreach ($Folder in $ModuleFolders) {
    $JsonPath = Join-Path $Folder.FullName 'tool.json'
    if (!(Test-Path $JsonPath)) { continue }
    try { $Json = Get-Content $JsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
    catch { continue }
    $Name = [string](Get-JsonValue $Json 'name' $Folder.Name)
    $Key = $Name.ToLowerInvariant().Trim()
    if (!$AllNames.ContainsKey($Key)) { $AllNames[$Key] = New-Object System.Collections.Generic.List[string] }
    $AllNames[$Key].Add($Folder.Name)
}

$PassCount = 0
$WarnCount = 0
$FailCount = 0

foreach ($Folder in $ModuleFolders) {
    $Findings = New-Object System.Collections.Generic.List[string]
    $Warnings = New-Object System.Collections.Generic.List[string]
    $Json = $null
    $JsonPath = Join-Path $Folder.FullName 'tool.json'
    $Ps1Path = Join-Path $Folder.FullName 'run.ps1'

    if (Test-Path $JsonPath) {
        try { $Json = Get-Content $JsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
        catch { $Findings.Add("Invalid JSON: $($_.Exception.Message)") }
    } else {
        $Findings.Add('Missing tool.json')
    }

    $Name = $Folder.Name
    if ($Json -and $Json.name) { $Name = [string]$Json.name }

    if ($Json) {
        foreach ($Field in $DeprecatedFields) {
            if ($Json.PSObject.Properties.Name -contains $Field) { $Warnings.Add("Deprecated JSON field: $Field") }
        }

        if ([string]::IsNullOrWhiteSpace([string](Get-JsonValue $Json 'category' ''))) { $Warnings.Add('Missing category') }
        if ([string]::IsNullOrWhiteSpace([string](Get-JsonValue $Json 'description' ''))) { $Warnings.Add('Missing description') }
        if ([string](Get-JsonValue $Json 'description' '') -match '^(test|todo|description|runs\s+test\.?|needs\s+)') { $Warnings.Add('Weak placeholder description') }

        $Key = $Name.ToLowerInvariant().Trim()
        if ($AllNames.ContainsKey($Key) -and $AllNames[$Key].Count -gt 1) { $Warnings.Add("Duplicate display name: $Name") }
    }

    if (Test-Path $Ps1Path) {
        foreach ($syntaxIssue in (Test-PowerShellSyntax -Path $Ps1Path)) { $Findings.Add($syntaxIssue) }
        foreach ($qualityWarning in (Test-PowerShellScriptQuality -Path $Ps1Path)) { $Warnings.Add($qualityWarning) }
        $Content = Get-Content $Ps1Path -Raw -ErrorAction SilentlyContinue
        foreach ($Pattern in $BatchSyntaxPatterns) {
            if ($Content -match $Pattern) { $Warnings.Add("Possible BAT syntax in PS1: $Pattern") }
        }
        foreach ($Word in $RiskWords) {
            if ($Content -match [regex]::Escape($Word)) { $Warnings.Add("Risk keyword detected: $Word") }
        }
    } else {
        $Findings.Add('Missing run.ps1')
    }

    if ($Findings.Count -gt 0) { $Status='FAIL'; $FailCount++ }
    elseif ($Warnings.Count -gt 0) { $Status='WARN'; $WarnCount++ }
    else { $Status='PASS'; $PassCount++ }

    Write-StatusLine $Status $Name
    foreach ($Finding in $Findings) { Write-Host "       - $Finding" -ForegroundColor Red }
    foreach ($Warning in $Warnings) { Write-Host "       - $Warning" -ForegroundColor Yellow }

    $Rows += [pscustomobject]@{
        Module = $Name
        Folder = $Folder.Name
        Status = $Status
        Findings = ($Findings -join '; ')
        Warnings = ($Warnings -join '; ')
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host " AUDIT SUMMARY"
Write-Host "============================================================"
Write-Host "PASS : $PassCount" -ForegroundColor Green
Write-Host "WARN : $WarnCount" -ForegroundColor Yellow
Write-Host "FAIL : $FailCount" -ForegroundColor Red
Write-Host ""
Write-Host "Notes:"
Write-Host " - Health Check asks: Is the module structurally healthy?"
Write-Host " - Module Audit asks: Is the module modern and clean?"
Write-Host ""
$Rows | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
Write-Host "Report saved: $CsvPath"
Select-FailedModuleForRepair -Rows $Rows
Write-Host ""
Read-Host "Press Enter to continue"
