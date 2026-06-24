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
    Show-CenterHeader "REGISTRY MANAGER"
    Write-Host "Registry, cache, bootstrap, and framework integrity tools."
    Write-Host ""
    Write-Host "[1] Toolkit Registry Builder"
    Write-Host "[2] Rebuild Toolkit Cache"
    Write-Host "[3] Bootstrap Integration Manager"
    Write-Host "[4] Core Integration Manager"
    Write-Host "[5] Framework Integrity Check"
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = Read-Choice
    switch ($Choice.ToUpper()) {
        "1" { Invoke-FrameworkTool "Toolkit_Registry" }
        "2" { Invoke-FrameworkTool "Rebuild_Toolkit_Cache" }
        "3" { Invoke-FrameworkTool "Bootstrap_Integration_Manager" }
        "4" { Invoke-FrameworkTool "Core_Integration_Manager" }
        "5" { Invoke-FrameworkTool "Framework_Integrity_Check" }
        "B" { return }
    }
}
