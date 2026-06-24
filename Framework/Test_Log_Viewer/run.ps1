# Test Log Viewer - Build 34B navigation fix
$Root = Resolve-Path "$PSScriptRoot\..\.."
$LogPath = Join-Path $Root "Logs\framework_test.log"

function Show-Header($Title) {
    Clear-Host
    Write-Host "============================================================"
    Write-Host " $Title"
    Write-Host "============================================================"
    Write-Host ""
}

function Pause-Viewer { Write-Host ""; Read-Host "Press Enter to continue" | Out-Null }

while ($true) {
    Show-Header "FRAMEWORK TEST LOG"
    Write-Host "Log file: $LogPath"
    Write-Host ""
    if (Test-Path $LogPath) { Get-Content $LogPath -Tail 60 } else { Write-Host "No test log found yet." }
    Write-Host ""
    Write-Host "[O] Open Log"
    Write-Host "[C] Clear Log"
    Write-Host "[F] Open Logs Folder"
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = Read-Host "Selection"
    switch ($Choice.ToUpper()) {
        "O" { if (Test-Path $LogPath) { Start-Process $LogPath } else { Write-Host "Log file does not exist."; Pause-Viewer } }
        "C" { "# Windows Modular Toolkit Framework 2.0 - Test Log" | Set-Content $LogPath -Encoding UTF8; Write-Host "Log cleared."; Pause-Viewer }
        "F" { $Folder = Split-Path $LogPath; if (!(Test-Path $Folder)) { New-Item -ItemType Directory -Path $Folder -Force | Out-Null }; Start-Process $Folder }
        "B" { return }
    }
}
