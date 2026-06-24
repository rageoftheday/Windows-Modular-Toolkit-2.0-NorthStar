# ============================================================
# WINDOWS MODULAR TOOLKIT
# Module Validator
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
$ModulesPath = Join-Path $Root "Modules"

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

Clear-Host
Write-Host "============================================================"
Write-Host "                 MODULE VALIDATOR"
Write-Host "============================================================"
Write-Host ""

$ValidCount = 0
$IssueCount = 0
$WarnCount = 0
$Results = @()
$RequiredFields = @('name','category','subcategory','description','keywords','risk','requires_admin','supports_logs','supports_export','entry','dependencies','hidden')

Get-ChildItem $ModulesPath -Directory | ForEach-Object {
    $Module = $_
    $ModuleName = $Module.Name
    $ToolJson = Join-Path $Module.FullName "tool.json"
    $RunBat   = Join-Path $Module.FullName "run.bat"
    $RunPs1   = Join-Path $Module.FullName "run.ps1"
    $Issues = @()
    $Warnings = @()

    Write-Host "Checking: $ModuleName"

    if (!(Test-Path $ToolJson)) {
        $Issues += "Missing tool.json"
    } else {
        try {
            $JsonData = Get-Content $ToolJson -Raw | ConvertFrom-Json
            foreach ($field in $RequiredFields) {
                if ($JsonData.PSObject.Properties.Name -notcontains $field) { $Warnings += "Missing schema field: $field" }
            }
            if ([string]::IsNullOrWhiteSpace($JsonData.name)) { $Issues += "Missing metadata name" }
            if ([string]::IsNullOrWhiteSpace($JsonData.category)) { $Issues += "Missing category" }
            if ([string]::IsNullOrWhiteSpace($JsonData.description)) { $Issues += "Missing description" }
            if ($JsonData.keywords -isnot [System.Array]) { $Warnings += "keywords should be an array" }
            if ($JsonData.dependencies -isnot [System.Array]) { $Warnings += "dependencies should be an array" }
            $entry = if ($JsonData.entry) { [string]$JsonData.entry } else { 'run.bat' }
            $entryPath = Join-Path $Module.FullName $entry
            if (!(Test-Path $entryPath)) { $Issues += "Entry file missing: $entry" }
        } catch {
            $Issues += "Invalid JSON format"
        }
    }

    if (!(Test-Path $RunBat)) { $Warnings += "Missing run.bat" }
    if (!(Test-Path $RunPs1)) { $Issues += "Missing run.ps1" }
    else {
        $Issues += @(Test-PowerShellSyntax -Path $RunPs1)
        $Warnings += @(Test-PowerShellScriptQuality -Path $RunPs1)
    }

    if ($Issues.Count -eq 0 -and $Warnings.Count -eq 0) {
        Write-Host "  [PASS] Module Valid" -ForegroundColor Green
        $ValidCount++
        $status = "Valid"
    } elseif ($Issues.Count -eq 0) {
        foreach ($w in $Warnings) { Write-Host "  [WARN] $w" -ForegroundColor Yellow }
        $WarnCount++
        $status = "Warnings"
    } else {
        foreach ($Issue in $Issues) { Write-Host "  [FAIL] $Issue" -ForegroundColor Red }
        foreach ($w in $Warnings) { Write-Host "  [WARN] $w" -ForegroundColor Yellow }
        $IssueCount++
        $status = "Issues Found"
    }

    $Results += [PSCustomObject]@{
        Module = $ModuleName
        Status = $status
        Issues = if ($Issues.Count -gt 0) { $Issues -join "; " } elseif ($Warnings.Count -gt 0) { $Warnings -join "; " } else { "-" }
    }
    Write-Host ""
}

Write-Host "============================================================"
Write-Host "                VALIDATION COMPLETE"
Write-Host "============================================================"
Write-Host ""
Write-Host "Valid Modules : $ValidCount"
Write-Host "Warning Modules : $WarnCount"
Write-Host "Issue Modules : $IssueCount"
Write-Host ""
Write-Host "============================================================"
Write-Host "                    SUMMARY"
Write-Host "============================================================"
Write-Host ""
$Results | Format-Table -AutoSize
Write-Host ""
Read-Host "Press Enter to continue" | Out-Null
