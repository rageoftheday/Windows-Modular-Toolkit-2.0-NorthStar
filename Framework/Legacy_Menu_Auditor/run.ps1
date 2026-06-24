# ============================================================
# LEGACY MENU AUDITOR
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "LEGACY MENU AUDITOR" `
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
    # GET BAT FILES
    # ========================================================

    function Get-BatFiles {

        Get-ChildItem `
            $ModulesPath `
            -Recurse `
            -Filter "*.bat"
    }

    # ========================================================
    # ANALYZE BATCH FILE
    # ========================================================

    function Analyze-BatchFile {

        param(
            [string]$Path
        )

        $Lines = Get-Content $Path

        $Labels = @()
        $GotoTargets = @()
        $CallTargets = @()

        foreach ($Line in $Lines) {

            $Trim = $Line.Trim()

            # ------------------------------------------------
            # LABELS
            # ------------------------------------------------

            if ($Trim -match "^:[a-zA-Z0-9_\-]+") {

                $Label = $Trim.Substring(1)

                $Labels += $Label
            }

            # ------------------------------------------------
            # GOTO
            # ------------------------------------------------

            if ($Trim -match "^goto\s+([a-zA-Z0-9_\-]+)") {

                $GotoTargets += $Matches[1]
            }

            # ------------------------------------------------
            # CALL :
            # ------------------------------------------------

            if ($Trim -match "^call\s+:\s*([a-zA-Z0-9_\-]+)") {

                $CallTargets += $Matches[1]
            }
        }

        # ----------------------------------------------------
        # DEAD TARGETS
        # ----------------------------------------------------

        $DeadGoto = @()

        foreach ($Target in $GotoTargets) {

            if ($Labels -notcontains $Target) {

                $DeadGoto += $Target
            }
        }

        $DeadCalls = @()

        foreach ($Target in $CallTargets) {

            if ($Labels -notcontains $Target) {

                $DeadCalls += $Target
            }
        }

        # ----------------------------------------------------
        # MENU DETECTION
        # ----------------------------------------------------

        $LooksLikeMenu = $false

        if (
            $Lines -match "echo.*menu" -or
            $Lines -match "goto.*menu"
        ) {

            $LooksLikeMenu = $true
        }

        # ----------------------------------------------------
        # HUB DETECTION
        # ----------------------------------------------------

        $HubCandidate = $false

        if ($GotoTargets.Count -ge 5) {

            $HubCandidate = $true
        }

        # ----------------------------------------------------
        # RECURSION
        # ----------------------------------------------------

        $Recursive = $false

        foreach ($Label in $Labels) {

            if ($GotoTargets -contains $Label) {

                $Recursive = $true
            }
        }

        return [PSCustomObject]@{

            File = $Path
            Labels = $Labels.Count
            Gotos = $GotoTargets.Count
            Calls = $CallTargets.Count
            DeadGotoTargets = ($DeadGoto -join ", ")
            DeadCallTargets = ($DeadCalls -join ", ")
            Recursive = $Recursive
            LooksLikeMenu = $LooksLikeMenu
            HubCandidate = $HubCandidate
        }
    }

    # ========================================================
    # MENU LOOP
    # ========================================================

    while ($true) {

        Clear-Host

        Write-Host "============================================================"
        Write-Host "                LEGACY MENU AUDITOR"
        Write-Host "============================================================"
        Write-Host ""
        Write-Host "[1] Scan Legacy BAT Files"
        Write-Host "[2] Export Full Audit Report"
        Write-Host "[3] Show Hub Candidates"
        Write-Host "[4] Show Broken Menu References"
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        Write-Host "============================================================"
        Write-Host ""

        $Choice = Read-Host "Selection"

        switch ($Choice.ToUpper()) {

            # =================================================
            # FULL SCAN
            # =================================================

            "1" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "              SCANNING LEGACY MENUS"
                Write-Host "============================================================"
                Write-Host ""

                $Files = Get-BatFiles

                foreach ($File in $Files) {

                    try {

                        $Result = Analyze-BatchFile `
                            -Path $File.FullName

                        if (
                            $Result.LooksLikeMenu -or
                            $Result.Gotos -gt 0 -or
                            $Result.Calls -gt 0
                        ) {

                            $Relative = $File.FullName.Replace("$Root\", "")

                            Write-Host $Relative `
                                -ForegroundColor Yellow

                            Write-Host "  Labels        : $($Result.Labels)"
                            Write-Host "  Gotos         : $($Result.Gotos)"
                            Write-Host "  Calls         : $($Result.Calls)"
                            Write-Host "  Recursive     : $($Result.Recursive)"
                            Write-Host "  Hub Candidate : $($Result.HubCandidate)"

                            if ($Result.DeadGotoTargets) {

                                Write-Host "  Dead GOTO     : $($Result.DeadGotoTargets)" `
                                    -ForegroundColor Red
                            }

                            if ($Result.DeadCallTargets) {

                                Write-Host "  Dead CALL     : $($Result.DeadCallTargets)" `
                                    -ForegroundColor Red
                            }

                            Write-Host ""
                        }
                    }
                    catch {

                        $Relative = $File.FullName.Replace("$Root\", "")

                        Write-Host "[FAIL] $Relative" `
                            -ForegroundColor Red
                    }
                }

                Pause-Toolkit
            }

            # =================================================
            # EXPORT REPORT
            # =================================================

            "2" {

                Clear-Host

                $Report = @()

                Get-BatFiles | ForEach-Object {

                    try {

                        $Result = Analyze-BatchFile `
                            -Path $_.FullName

                        $Report += $Result
                    }
                    catch {}
                }

                $ReportPath = Join-Path `
                    $ExportsPath `
                    "legacy_menu_audit.csv"

                $Report |
                    Export-Csv `
                        -Path $ReportPath `
                        -NoTypeInformation `
                        -Encoding UTF8

                Write-Host ""
                Write-Host "[PASS] Audit report exported:"
                Write-Host $ReportPath
                Write-Host ""

                Pause-Toolkit
            }

            # =================================================
            # HUB CANDIDATES
            # =================================================

            "3" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "                 HUB CANDIDATES"
                Write-Host "============================================================"
                Write-Host ""

                Get-BatFiles | ForEach-Object {

                    try {

                        $Result = Analyze-BatchFile `
                            -Path $_.FullName

                        if ($Result.HubCandidate) {

                            $Relative = $_.FullName.Replace("$Root\", "")

                            Write-Host $Relative `
                                -ForegroundColor Green

                            Write-Host "  Suggested Action: Convert to Dynamic Hub"
                            Write-Host ""
                        }
                    }
                    catch {}
                }

                Pause-Toolkit
            }

            # =================================================
            # BROKEN REFERENCES
            # =================================================

            "4" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "              BROKEN MENU REFERENCES"
                Write-Host "============================================================"
                Write-Host ""

                Get-BatFiles | ForEach-Object {

                    try {

                        $Result = Analyze-BatchFile `
                            -Path $_.FullName

                        if (
                            $Result.DeadGotoTargets -or
                            $Result.DeadCallTargets
                        ) {

                            $Relative = $_.FullName.Replace("$Root\", "")

                            Write-Host $Relative `
                                -ForegroundColor Yellow

                            if ($Result.DeadGotoTargets) {

                                Write-Host "  Dead GOTO : $($Result.DeadGotoTargets)" `
                                    -ForegroundColor Red
                            }

                            if ($Result.DeadCallTargets) {

                                Write-Host "  Dead CALL : $($Result.DeadCallTargets)" `
                                    -ForegroundColor Red
                            }

                            Write-Host ""
                        }
                    }
                    catch {}
                }

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