# ============================================================
# FRAMEWORK INTEGRITY CHECK
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

while ($true) {
    $Result = Test-ToolkitFrameworkIntegrity $Root

    Show-ToolkitHeader "FRAMEWORK INTEGRITY CHECK"

    if ($Result.Passed) {
        Show-ToolkitStatus "PASS" "Required framework files found."
    }
    else {
        Show-ToolkitStatus "FAIL" "Required framework files are missing."
        Write-Host ""
        foreach ($Item in $Result.Missing) {
            Write-Host "Missing: $Item" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Checked Files: $($Result.Present.Count + $Result.Missing.Count)"
    Write-Host "Missing Files: $($Result.MissingCount)"
    Write-Host ""
    Write-Host "Framework components are required for toolkit operation."
    Write-Host "If a framework file is missing, restore it from the original release ZIP or re-download the toolkit."
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""

    $Choice = Read-Host "Selection"
    if ($Choice.ToUpper() -eq "B") { return }
    if ($Choice.ToUpper() -eq "Q") { return }
}
