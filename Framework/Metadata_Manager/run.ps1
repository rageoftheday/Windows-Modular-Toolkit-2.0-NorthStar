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
    Show-CenterHeader "METADATA MANAGER"
    Write-Host "Maintenance tools for module metadata quality."
    Write-Host "These are framework maintenance actions, not normal user tools."
    Write-Host ""
    Write-Host "[1] Metadata Repair Tool"
    Write-Host "[2] Fix / Improve Descriptions"
    Write-Host "[3] Review Risk Classification"
    Write-Host "[4] Normalize Headers"
    Write-Host "[5] Normalize Menu Consistency"
    Write-Host "[6] Category Architecture Review"
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = Read-Choice
    switch ($Choice.ToUpper()) {
        "1" { Invoke-FrameworkTool "Metadata_Repair_Tool" }
        "2" { Invoke-FrameworkTool "Metadata_Description_Fixer" }
        "3" { Invoke-FrameworkTool "Risk_Classification_Assistant" }
        "4" { Invoke-FrameworkTool "Header_Normalization_Manager" }
        "5" { Invoke-FrameworkTool "Menu_Consistency_Normalizer" }
        "6" { Invoke-FrameworkTool "Category_Architecture_Manager" }
        "B" { return }
    }
}
