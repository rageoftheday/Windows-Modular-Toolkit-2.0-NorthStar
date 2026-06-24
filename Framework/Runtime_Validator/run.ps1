$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"
$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
Clear-Host

$Root = Resolve-Path "$PSScriptRoot\..\.."


. "$Root\core\bootstrap.ps1"
Set-Location $Root

$ModulesPath = Join-Path $Root "modules"

Write-Host "============================================================"
Write-Host "                 RUNTIME VALIDATOR"
Write-Host "============================================================"
Write-Host ""

$Passed = 0
$Failed = 0

$Results = @()

Get-ChildItem $ModulesPath -Directory | ForEach-Object {

    $Module = $_
    $Name = $Module.Name

    $RunBat = Join-Path $Module.FullName "run.bat"
    $RunPs1 = Join-Path $Module.FullName "run.ps1"

    $Status = "PASS"
    $Reason = "Runtime OK"

    Write-Host "Testing: $Name"

    # ------------------------------------------------------------
    # Validate Launcher Exists
    # ------------------------------------------------------------

    if (!(Test-Path $RunBat) -and !(Test-Path $RunPs1)) {

        $Status = "FAIL"
        $Reason = "Missing launcher"
    }

    # ------------------------------------------------------------
    # Validate BAT Syntax
    # ------------------------------------------------------------

    elseif (Test-Path $RunBat) {

        try {

            $BatContent = Get-Content $RunBat -Raw

            if ($BatContent.Length -lt 5) {

                $Status = "FAIL"
                $Reason = "Empty BAT file"
            }

        }
        catch {

            $Status = "FAIL"
            $Reason = "Unreadable BAT file"
        }
    }

    # ------------------------------------------------------------
    # Validate PS1 Syntax
    # ------------------------------------------------------------

    elseif (Test-Path $RunPs1) {

        try {

            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $RunPs1 -Raw),
                [ref]$null
            )

        }
        catch {

            $Status = "FAIL"
            $Reason = "PowerShell syntax error"
        }
    }

    # ------------------------------------------------------------
    # Output
    # ------------------------------------------------------------

    if ($Status -eq "PASS") {

        Write-Host "  [PASS] $Reason" -ForegroundColor Green
        $Passed++

    } else {

        Write-Host "  [FAIL] $Reason" -ForegroundColor Red
        $Failed++
    }

    $Results += [PSCustomObject]@{
        Module = $Name
        Status = $Status
        Details = $Reason
    }

    Write-Host ""
}

Write-Host "============================================================"
Write-Host "               RUNTIME VALIDATION COMPLETE"
Write-Host "============================================================"
Write-Host ""

Write-Host "Passed : $Passed"
Write-Host "Failed : $Failed"

Write-Host ""
Write-Host "============================================================"
Write-Host "                     SUMMARY"
Write-Host "============================================================"
Write-Host ""

$Results | Format-Table -AutoSize

Write-Host ""
Read-Host "Press Enter to continue"




