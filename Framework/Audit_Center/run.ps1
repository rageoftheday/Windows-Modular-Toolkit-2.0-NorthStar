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
    Show-CenterHeader "AUDIT CENTER"
    Write-Host "Audit, inventory, duplicate detection, and framework cleanup reports."
    Write-Host ""
    Write-Host "[1] Module Inventory Report"
    Write-Host "[2] Deleted Items History"
    Write-Host "[3] Duplicate Tool Scanner"
    Write-Host "[4] Legacy Menu Auditor"
    Write-Host "[5] Module Rationalization Engine"
    Write-Host "[6] Migrated Module Cleanup Manager"
    Write-Host "[7] Export Center"
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = Read-Choice
    switch ($Choice.ToUpper()) {
        "1" { Invoke-FrameworkTool "Module_Inventory_Report" }
        "2" { Invoke-FrameworkTool "Deleted_Items_History" }
        "3" { Invoke-FrameworkTool "Duplicate_Tool_Scanner" }
        "4" { Invoke-FrameworkTool "Legacy_Menu_Auditor" }
        "5" { Invoke-FrameworkTool "Module_Rationalization_Engine" }
        "6" { Invoke-FrameworkTool "Migrated_Module_Cleanup_Manager" }
        "7" { Invoke-FrameworkTool "Export_Center" }
        "B" { return }
    }
}
