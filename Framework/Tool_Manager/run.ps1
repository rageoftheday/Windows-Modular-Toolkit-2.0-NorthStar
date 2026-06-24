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
    Show-CenterHeader "TOOL MANAGER"
    Write-Host "Create, modify, organize, clone, hide, and remove user modules."
    Write-Host "Framework components remain protected."
    Write-Host ""
    Write-Host "[1] Add Module Builder"
    Write-Host "[2] Modify Tool Metadata"
    Write-Host "[3] Category Manager"
    Write-Host "[4] Module Manager"
    Write-Host "[5] Remove/Delete Module"
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = Read-Choice
    switch ($Choice.ToUpper()) {
        "1" { Invoke-FrameworkTool "Add_Module_Builder" }
        "2" { Invoke-FrameworkTool "Tool_Modifier" }
        "3" { Invoke-FrameworkTool "Category_Manager" }
        "4" { Invoke-FrameworkTool "Module_Manager" }
        "5" { Invoke-FrameworkTool "Remove_Tool_Wizard" }
        "B" { return }
    }
}
