$ErrorActionPreference = "Continue"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Show-CenterHeader {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "============================================================"
    Write-Host (" " + $Title)
    Write-Host "============================================================"
    Write-Host ""
}

function Invoke-FrameworkTool {
    param([string]$Folder)
    $ToolPath = Join-Path $Root "Framework\$Folder"
    $PS1 = Join-Path $ToolPath "run.ps1"
    $BAT = Join-Path $ToolPath "run.bat"
    if (Test-Path $PS1) {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PS1
        return
    }
    if (Test-Path $BAT) {
        cmd /c "`"$BAT`""
        return
    }
    Write-Host "[FAIL] Framework tool not found: $Folder" -ForegroundColor Red
    Read-Host "Press Enter to continue"
}

function Read-Choice {
    param([string]$Prompt = "Selection")
    return (Read-Host $Prompt).Trim()
}

while ($true) {
    Show-CenterHeader "VALIDATION CENTER"
    Write-Host "All validation tools are grouped here."
    Write-Host ""
    Write-Host "[1] Quick Validation"
    Write-Host "    Fast metadata and structure check."
    Write-Host "[2] Dry Run Validation"
    Write-Host "    Checks modules safely without running tools."
    Write-Host "[3] Runtime Validation"
    Write-Host "    Checks runtime/framework behavior."
    Write-Host "[4] Smart Validation"
    Write-Host "    Advisor-style validation and cleanup suggestions."
    Write-Host "[5] Static Code Analysis"
    Write-Host "    Checks PowerShell/script patterns without execution."
    Write-Host "[6] Framework Integrity Check"
    Write-Host "    Checks protected framework files and structure."
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = Read-Choice
    switch ($Choice.ToUpper()) {
        "1" { Invoke-FrameworkTool "Validate_Modules" }
        "2" { Invoke-FrameworkTool "Dry_Run_Module_Validator" }
        "3" { Invoke-FrameworkTool "Runtime_Validator" }
        "4" { Invoke-FrameworkTool "Smart_Module_Validator" }
        "5" { Invoke-FrameworkTool "Static_Code_Analyzer" }
        "6" { Invoke-FrameworkTool "Framework_Integrity_Check" }
        "B" { return }
    }
}
