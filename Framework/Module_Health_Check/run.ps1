# ============================================================
# WINDOWS MODULAR TOOLKIT
# Module Health Check
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
$ModulesRoot = Join-Path $Root "Modules"
$ReportRoot = Join-Path $Root "Logs\module-health"
if (!(Test-Path $ReportRoot)) { New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null }
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$CsvPath = Join-Path $ReportRoot "module_health_$Stamp.csv"

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
Write-Host " MODULE HEALTH CHECK"
Write-Host "============================================================"
Write-Host ""
Write-Host "Checks user modules for required files, valid JSON, current schema, and entry targets."
Write-Host ""

$RequiredFields = @('name','category','subcategory','description','keywords','risk','requires_admin','supports_logs','supports_export','entry','dependencies','hidden')
$DeprecatedFields = @('author','estimated_time','important')
$Rows = @()
$PassCount = 0
$WarnCount = 0
$FailCount = 0

if (!(Test-Path $ModulesRoot)) {
    Write-StatusLine "FAIL" "Modules folder not found: $ModulesRoot"
    Read-Host "Press Enter to continue"
    return
}

$ModuleFolders = @(Get-ChildItem -Path $ModulesRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
if ($ModuleFolders.Count -eq 0) {
    Write-StatusLine "WARN" "No module folders found."
    Read-Host "Press Enter to continue"
    return
}

foreach ($Folder in $ModuleFolders) {
    $Issues = New-Object System.Collections.Generic.List[string]
    $Warnings = New-Object System.Collections.Generic.List[string]
    $Json = $null
    $JsonPath = Join-Path $Folder.FullName 'tool.json'
    $Ps1Path = Join-Path $Folder.FullName 'run.ps1'
    $BatPath = Join-Path $Folder.FullName 'run.bat'

    if (!(Test-Path $JsonPath)) { $Issues.Add('Missing tool.json') }
    else {
        try { $Json = Get-Content $JsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
        catch { $Issues.Add("Invalid JSON: $($_.Exception.Message)") }
    }

    if (!(Test-Path $Ps1Path)) { $Issues.Add('Missing run.ps1') }
    else {
        foreach ($syntaxIssue in (Test-PowerShellSyntax -Path $Ps1Path)) { $Issues.Add($syntaxIssue) }
        foreach ($qualityWarning in (Test-PowerShellScriptQuality -Path $Ps1Path)) { $Warnings.Add($qualityWarning) }
    }
    if (!(Test-Path $BatPath)) { $Warnings.Add('Missing run.bat') }

    if ($Json) {
        foreach ($Field in $RequiredFields) {
            if (!($Json.PSObject.Properties.Name -contains $Field)) { $Issues.Add("Missing field: $Field") }
        }
        foreach ($Field in $DeprecatedFields) {
            if ($Json.PSObject.Properties.Name -contains $Field) { $Warnings.Add("Deprecated field present: $Field") }
        }

        $Entry = [string](Get-JsonValue $Json 'entry' 'run.bat')
        if ([string]::IsNullOrWhiteSpace($Entry)) { $Issues.Add('Entry is blank') }
        else {
            $EntryPath = Join-Path $Folder.FullName $Entry
            if (!(Test-Path $EntryPath)) { $Issues.Add("Entry file missing: $Entry") }
        }

        $Keywords = Get-JsonValue $Json 'keywords' @()
        if ($null -ne $Keywords -and $Keywords -isnot [System.Array]) { $Warnings.Add('keywords should be an array') }
        $Dependencies = Get-JsonValue $Json 'dependencies' @()
        if ($null -ne $Dependencies -and $Dependencies -isnot [System.Array]) { $Warnings.Add('dependencies should be an array') }

        foreach ($BoolField in @('requires_admin','supports_logs','supports_export','hidden')) {
            $Value = Get-JsonValue $Json $BoolField $null
            if ($null -ne $Value -and $Value -isnot [bool]) { $Warnings.Add("$BoolField should be true/false") }
        }
    }

    if ($Issues.Count -gt 0) {
        $Status = 'FAIL'; $FailCount++
    } elseif ($Warnings.Count -gt 0) {
        $Status = 'WARN'; $WarnCount++
    } else {
        $Status = 'PASS'; $PassCount++
    }

    $Name = $Folder.Name
    if ($Json -and $Json.name) { $Name = [string]$Json.name }
    Write-StatusLine $Status $Name
    foreach ($Issue in $Issues) { Write-Host "       - $Issue" -ForegroundColor Red }
    foreach ($Warning in $Warnings) { Write-Host "       - $Warning" -ForegroundColor Yellow }

    $Rows += [pscustomobject]@{
        Module = $Name
        Folder = $Folder.Name
        Status = $Status
        Issues = ($Issues -join '; ')
        Warnings = ($Warnings -join '; ')
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host " HEALTH SUMMARY"
Write-Host "============================================================"
Write-Host "PASS : $PassCount" -ForegroundColor Green
Write-Host "WARN : $WarnCount" -ForegroundColor Yellow
Write-Host "FAIL : $FailCount" -ForegroundColor Red
Write-Host ""
$Rows | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
Write-Host "Report saved: $CsvPath"
Select-FailedModuleForRepair -Rows $Rows
Write-Host ""
Read-Host "Press Enter to continue"
