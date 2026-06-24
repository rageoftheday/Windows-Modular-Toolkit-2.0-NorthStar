# ============================================================
# MODULE RATIONALIZATION ENGINE
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "MODULE RATIONALIZATION ENGINE" `
    -RequiresAdmin $false `
    -ScriptBlock {

    $ModulesPath = Join-Path $Root "modules"
    $ExportsPath = Join-Path $Root "exports"

    if (!(Test-Path $ExportsPath)) {

        New-Item `
            -ItemType Directory `
            -Path $ExportsPath | Out-Null
    }

    # ========================================================
    # CLASSIFICATION ENGINE
    # ========================================================

    function Get-ModuleClassification {

        param(
            [string]$Folder,
            [object]$Json
        )

        $Text = (
            "$Folder " +
            "$($Json.name) " +
            "$($Json.description) " +
            "$($Json.category) " +
            "$($Json.subcategory)"
        ).ToLower()

        # ----------------------------------------------------
        # KEEP
        # ----------------------------------------------------

        if (
            $Text -match
            "registry|validator|search|dependency|engine|browser|repair|network|security|system|disk|storage|info|diagnostic"
        ) {

            return "KEEP"
        }

        # ----------------------------------------------------
        # REMOVE
        # ----------------------------------------------------

        if (
            $Text -match
            "legacy menu|submenu|advancedmenu|mainmenu|compatibility shim|wrapper"
        ) {

            return "REMOVE"
        }

        if (
            $Folder -match
            "_menu$"
        ) {

            return "REMOVE"
        }

        # ----------------------------------------------------
        # REBUILD
        # ----------------------------------------------------

        if (
            $Text -match
            "launcher|manager|dashboard|hub|orchestrator|dynamic toolkit"
        ) {

            return "REBUILD"
        }

        # ----------------------------------------------------
        # REVIEW
        # ----------------------------------------------------

        return "REVIEW"
    }

    # ========================================================
    # MENU LOOP
    # ========================================================

    while ($true) {

        Clear-Host

        Write-Host "============================================================"
        Write-Host "          MODULE RATIONALIZATION ENGINE"
        Write-Host "============================================================"
        Write-Host ""
        Write-Host "[1] Full Classification Audit"
        Write-Host "[2] Show KEEP Modules"
        Write-Host "[3] Show REMOVE Candidates"
        Write-Host "[4] Show REBUILD Candidates"
        Write-Host "[5] Show REVIEW Candidates"
        Write-Host "[6] Export Classification Report"
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        Write-Host "============================================================"
        Write-Host ""

        $Choice = Read-Host "Selection"

        # ----------------------------------------------------
        # BUILD RESULTS
        # ----------------------------------------------------

        $Results = @()

        Get-ChildItem $ModulesPath -Directory | ForEach-Object {

            $JsonPath = Join-Path $_.FullName "tool.json"

            if (Test-Path $JsonPath) {

                try {

                    $Json = Get-Content `
                        $JsonPath `
                        -Raw | ConvertFrom-Json

                    $Class = Get-ModuleClassification `
                        -Folder $_.Name `
                        -Json $Json

                    $Results += [PSCustomObject]@{

                        Folder = $_.Name
                        Name = $Json.name
                        Category = $Json.category
                        Classification = $Class
                    }
                }
                catch {}
            }
        }

        switch ($Choice.ToUpper()) {

            # =================================================
            # FULL AUDIT
            # =================================================

            "1" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "            FULL CLASSIFICATION AUDIT"
                Write-Host "============================================================"
                Write-Host ""

                $Results |
                    Sort-Object Classification, Folder |
                    ForEach-Object {

                        switch ($_.Classification) {

                            "KEEP" {
                                $Color = "Green"
                            }

                            "REMOVE" {
                                $Color = "Red"
                            }

                            "REBUILD" {
                                $Color = "Yellow"
                            }

                            default {
                                $Color = "Gray"
                            }
                        }

                        Write-Host "$($_.Folder)" `
                            -ForegroundColor $Color

                        Write-Host "  Classification : $($_.Classification)"
                        Write-Host "  Category       : $($_.Category)"
                        Write-Host ""
                    }

                Pause-Toolkit
            }

            # =================================================
            # FILTERS
            # =================================================

            "2" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "                 KEEP MODULES"
                Write-Host "============================================================"
                Write-Host ""

                $Results |
                    Where-Object {
                        $_.Classification -eq "KEEP"
                    } |
                    Sort-Object Folder |
                    ForEach-Object {

                        Write-Host $_.Folder `
                            -ForegroundColor Green
                    }

                Write-Host ""
                Pause-Toolkit
            }

            "3" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "              REMOVE CANDIDATES"
                Write-Host "============================================================"
                Write-Host ""

                $Results |
                    Where-Object {
                        $_.Classification -eq "REMOVE"
                    } |
                    Sort-Object Folder |
                    ForEach-Object {

                        Write-Host $_.Folder `
                            -ForegroundColor Red
                    }

                Write-Host ""
                Pause-Toolkit
            }

            "4" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "              REBUILD CANDIDATES"
                Write-Host "============================================================"
                Write-Host ""

                $Results |
                    Where-Object {
                        $_.Classification -eq "REBUILD"
                    } |
                    Sort-Object Folder |
                    ForEach-Object {

                        Write-Host $_.Folder `
                            -ForegroundColor Yellow
                    }

                Write-Host ""
                Pause-Toolkit
            }

            "5" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "               REVIEW CANDIDATES"
                Write-Host "============================================================"
                Write-Host ""

                $Results |
                    Where-Object {
                        $_.Classification -eq "REVIEW"
                    } |
                    Sort-Object Folder |
                    ForEach-Object {

                        Write-Host $_.Folder `
                            -ForegroundColor Gray
                    }

                Write-Host ""
                Pause-Toolkit
            }

            # =================================================
            # EXPORT REPORT
            # =================================================

            "6" {

                Clear-Host

                $ExportPath = Join-Path `
                    $ExportsPath `
                    "module_rationalization_report.csv"

                $Results |
                    Export-Csv `
                        -Path $ExportPath `
                        -NoTypeInformation `
                        -Encoding UTF8

                Write-Host ""
                Write-Host "[PASS] Report exported:"
                Write-Host $ExportPath
                Write-Host ""

                Pause-Toolkit
            }

            "B" {
                $Global:ToolkitSuppressCompletion = $true
                return
            }
            "Q" {
                $Global:ToolkitSuppressCompletion = $true
                return
            }
        }
    }
}