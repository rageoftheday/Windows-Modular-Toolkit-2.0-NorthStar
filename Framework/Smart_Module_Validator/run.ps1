$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"
# ============================================================
# SMART MODULE VALIDATOR
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
Invoke-ToolkitModule `
    -ModuleName "SMART MODULE VALIDATOR" `
    -RequiresAdmin $false `
    -ScriptBlock {

    $ModulesPath = Join-Path $Root "modules"

    $Modules = Get-ChildItem $ModulesPath -Directory

    $Passed = 0
    $Failed = 0

    foreach ($Module in $Modules) {

        Write-Host "Checking: $($Module.Name)"

        $Json = Join-Path $Module.FullName "tool.json"

        if (Test-Path $Json) {

            Write-Host "  [PASS] tool.json found" -ForegroundColor Green
            $Passed++
        }
        else {

            Write-Host "  [FAIL] Missing tool.json" -ForegroundColor Red

            Write-ToolkitLog "Missing tool.json: $($Module.Name)" "validator.log"

            $Failed++
        }
    }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " VALIDATION COMPLETE"
    Write-Host "============================================================"
    Write-Host ""

    Write-Host "Passed : $Passed"
    Write-Host "Failed : $Failed"


    # 39D_STANDARD_BACK_PAUSE
    Write-Host ""
    Write-Host "[B] Back"
    do { $BackChoice = (Read-Host "Selection").Trim().ToUpper() } until ($BackChoice -eq "B")
}



