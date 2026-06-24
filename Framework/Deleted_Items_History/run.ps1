# ============================================================
# DELETED ITEMS HISTORY
# Informational history only. No restore system.
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

$HistoryPath = Join-Path $Root "logs\deleted_items_history.log"

while ($true) {
    Show-ToolkitHeader "DELETED ITEMS HISTORY"

    if (!(Test-Path $HistoryPath)) {
        Write-Host "No deleted items history found."
        Write-Host ""
    }
    else {
        $Lines = @(Get-Content $HistoryPath -ErrorAction SilentlyContinue)
        if (!$Lines -or $Lines.Count -eq 0) {
            Write-Host "Deleted items history is empty."
            Write-Host ""
        }
        else {
            $Index = 1
            foreach ($Line in ($Lines | Select-Object -Last 100)) {
                Write-Host "[$Index] $Line"
                $Index++
            }
            Write-Host ""
            Write-Host "Showing latest 100 entries."
            Write-Host "This history is informational only. Deleted modules must be recreated if needed."
            Write-Host ""
        }
    }

    Write-Host "[C] Clear History"
    Write-Host "[B] Back"
    Write-Host ""

    $Choice = Read-Host "Selection"

    switch ($Choice.ToUpper()) {
        "C" {
            if (Test-Path $HistoryPath) {
                $Confirm = Read-Host "[Y] Clear deleted-items history  [N] Cancel"
                if ($Confirm.ToUpper() -eq "Y") {
                    Clear-Content $HistoryPath
                    Show-ToolkitStatus "PASS" "Deleted-items history cleared."
                    Pause-Toolkit
                }
            }
        }
        "B" { return }
        "Q" { return }
    }
}
