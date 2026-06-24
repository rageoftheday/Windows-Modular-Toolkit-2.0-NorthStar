# ============================================================
# QUICK ACTIONS HUB
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "QUICK ACTIONS HUB" `
    -RequiresAdmin $false `
    -ScriptBlock {

    function Get-Registry {
        $RegistryPath = Join-Path $Root "cache\toolkit_registry.json"

        if (!(Test-Path $RegistryPath)) {
            return @()
        }

        return @(Get-ToolkitRegistry $RegistryPath)
    }

    function Start-ToolByName {
        param(
            [array]$Registry,
            [string[]]$Names
        )

        foreach ($Name in $Names) {

            $Tool = $Registry |
                Where-Object {
                    $_.name -eq $Name -or
                    $_.folder -eq $Name
                } |
                Select-Object -First 1

            if ($Tool) {
                Start-ToolkitModule $Tool
                return
            }
        }

        Write-Host "Tool not found:" -ForegroundColor Red
        $Names | ForEach-Object {
            Write-Host " - $_"
        }
    }

    while ($true) {

        Show-ToolkitHeader "QUICK ACTIONS HUB"

        Write-Host "[1] Post-change validation"
        Write-Host "    Runs Validate Modules and Toolkit Health Center."
        Write-Host ""

        Write-Host "[2] Stability check"
        Write-Host "    Runs Dry Run Module Validator and Toolkit Health Center."
        Write-Host ""

        Write-Host "[3] Usage review"
        Write-Host "    Opens Usage Statistics."
        Write-Host ""

        Write-Host "[4] Export snapshot"
        Write-Host "    Opens Export Center."
        Write-Host ""

        Write-Host "[5] Smart Recommendations"
        Write-Host "    Runs Smart Recommendations Engine."
        Write-Host ""

        Write-Host "[6] Tool Chain Runner"
        Write-Host "    Runs repair, cleanup, network, and toolkit health packs."
        Write-Host ""

        Write-Host "[B] Back"
        Write-Host ""

        $Choice = Read-Host "Selection"
        $Registry = Get-Registry

        if ($Choice.ToUpper() -eq "B") {
            return
        }

        if ($Choice.ToUpper() -eq "Q") {
            return
        }

        switch ($Choice) {

            "1" {
                Start-ToolByName `
                    -Registry $Registry `
                    -Names @(
                        "Validate Modules",
                        "Module Validator",
                        "Smart Module Validator"
                    )

                Start-ToolByName `
                    -Registry $Registry `
                    -Names @(
                        "Toolkit Health Center"
                    )
            }

            "2" {
                Start-ToolByName `
                    -Registry $Registry `
                    -Names @(
                        "Dry Run Module Validator",
                        "Dry_Run_Module_Validator"
                    )

                Start-ToolByName `
                    -Registry $Registry `
                    -Names @(
                        "Toolkit Health Center"
                    )
            }

            "3" {
                Start-ToolByName `
                    -Registry $Registry `
                    -Names @(
                        "Usage Statistics",
                        "Usage_Statistics"
                    )
            }

            "4" {
                Start-ToolByName `
                    -Registry $Registry `
                    -Names @(
                        "Export Center",
                        "Export_Center"
                    )
            }

            "5" {
                Start-ToolByName `
                    -Registry $Registry `
                    -Names @(
                        "Smart Recommendations Engine",
                        "Smart_Recommendations_Engine"
                    )
            }

            "6" {
                Start-ToolByName `
                    -Registry $Registry `
                    -Names @(
                        "Tool Chain Runner",
                        "Tool_Chain_Runner"
                    )
            }
        }
    }
}
