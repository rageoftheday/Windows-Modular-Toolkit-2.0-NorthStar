# ============================================================
# MIGRATED MODULE CLEANUP MANAGER
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "MIGRATED MODULE CLEANUP MANAGER" `
    -RequiresAdmin $false `
    -ScriptBlock {

    $ModulesPath = Join-Path $Root "modules"
    $ExportsPath = Join-Path $Root "exports"

    if (!(Test-Path $ExportsPath)) {
        New-Item -ItemType Directory -Path $ExportsPath | Out-Null
    }

    while ($true) {

        Clear-Host

        Write-Host "============================================================"
        Write-Host "          MIGRATED MODULE CLEANUP MANAGER"
        Write-Host "============================================================"
        Write-Host ""
        Write-Host "[1] Audit Migrated Modules"
        Write-Host "[2] Export Cleanup Report"
        Write-Host "[3] Apply Safe Metadata Fixes"
        Write-Host "[4] Show Weak Metadata Summary"
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        Write-Host "============================================================"
        Write-Host ""

        $Choice = Read-Host "Selection"

        switch ($Choice.ToUpper()) {

            "1" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "              AUDITING MIGRATED MODULES"
                Write-Host "============================================================"
                Write-Host ""

                $Issues = @()

                Get-ChildItem $ModulesPath -Directory | ForEach-Object {

                    $Module = $_
                    $JsonPath = Join-Path $Module.FullName "tool.json"

                    if (Test-Path $JsonPath) {

                        try {

                            $Json = Get-Content $JsonPath -Raw | ConvertFrom-Json
                            $ModuleIssues = @()

                            if ($Json.subcategory -eq "Migrated Modules") {
                                $ModuleIssues += "Migrated subcategory"
                            }

                            if ($Json.risk -eq "Unknown") {
                                $ModuleIssues += "Unknown risk"
                            }

                            if ($Json.estimated_time -eq "Unknown") {
                                $ModuleIssues += "Unknown estimated_time"
                            }

                            if ($Json.description -like "Portable toolkit module for*") {
                                $ModuleIssues += "Generic description"
                            }

                            if (($Json.keywords -join ",") -eq "portable,toolkit,maintenance") {
                                $ModuleIssues += "Generic keywords"
                            }

                            if ($ModuleIssues.Count -gt 0) {

                                Write-Host "Module: $($Module.Name)" -ForegroundColor Yellow

                                foreach ($Issue in $ModuleIssues) {
                                    Write-Host "  - $Issue"
                                }

                                Write-Host ""

                                $Issues += [PSCustomObject]@{
                                    Module = $Module.Name
                                    Name = $Json.name
                                    Category = $Json.category
                                    Issues = ($ModuleIssues -join "; ")
                                }
                            }
                        }
                        catch {

                            Write-Host "[FAIL] Invalid JSON: $($Module.Name)" -ForegroundColor Red

                            $Issues += [PSCustomObject]@{
                                Module = $Module.Name
                                Name = "-"
                                Category = "-"
                                Issues = "Invalid JSON"
                            }
                        }
                    }
                }

                Write-Host "============================================================"
                Write-Host "Audit Complete"
                Write-Host "Modules With Weak Metadata: $($Issues.Count)"
                Write-Host "============================================================"
                Write-Host ""

                Pause-Toolkit
            }

            "2" {

                Clear-Host

                $Report = @()

                Get-ChildItem $ModulesPath -Directory | ForEach-Object {

                    $Module = $_
                    $JsonPath = Join-Path $Module.FullName "tool.json"

                    if (Test-Path $JsonPath) {

                        try {

                            $Json = Get-Content $JsonPath -Raw | ConvertFrom-Json
                            $ModuleIssues = @()

                            if ($Json.subcategory -eq "Migrated Modules") {
                                $ModuleIssues += "Migrated subcategory"
                            }

                            if ($Json.risk -eq "Unknown") {
                                $ModuleIssues += "Unknown risk"
                            }

                            if ($Json.estimated_time -eq "Unknown") {
                                $ModuleIssues += "Unknown estimated_time"
                            }

                            if ($Json.description -like "Portable toolkit module for*") {
                                $ModuleIssues += "Generic description"
                            }

                            if (($Json.keywords -join ",") -eq "portable,toolkit,maintenance") {
                                $ModuleIssues += "Generic keywords"
                            }

                            if ($ModuleIssues.Count -gt 0) {

                                $Report += [PSCustomObject]@{
                                    Folder = $Module.Name
                                    Name = $Json.name
                                    Category = $Json.category
                                    Subcategory = $Json.subcategory
                                    Risk = $Json.risk
                                    EstimatedTime = $Json.estimated_time
                                    Issues = ($ModuleIssues -join "; ")
                                }
                            }
                        }
                        catch {

                            $Report += [PSCustomObject]@{
                                Folder = $Module.Name
                                Name = "-"
                                Category = "-"
                                Subcategory = "-"
                                Risk = "-"
                                EstimatedTime = "-"
                                Issues = "Invalid JSON"
                            }
                        }
                    }
                }

                $ReportPath = Join-Path $ExportsPath "migrated_module_cleanup_report.csv"

                $Report |
                    Export-Csv `
                        -Path $ReportPath `
                        -NoTypeInformation `
                        -Encoding UTF8

                Write-Host ""
                Write-Host "[PASS] Report exported:"
                Write-Host $ReportPath
                Write-Host ""

                Pause-Toolkit
            }

            "3" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "             APPLYING SAFE METADATA FIXES"
                Write-Host "============================================================"
                Write-Host ""

                Write-Host "This will safely update:"
                Write-Host "- Generic keywords"
                Write-Host "- Generic migrated descriptions"
                Write-Host "- Unknown estimated_time to 1-5 Minutes"
                Write-Host ""
                Write-Host "It will NOT change risk or admin settings."
                Write-Host ""

                $Confirm = Read-Host "Type FIX to continue"

                if ($Confirm -ne "FIX") {
                    Write-Host ""
                    Write-Host "Cancelled."
                    Pause-Toolkit
                    continue
                }

                $Fixed = 0

                Get-ChildItem $ModulesPath -Directory | ForEach-Object {

                    $Module = $_
                    $JsonPath = Join-Path $Module.FullName "tool.json"

                    if (Test-Path $JsonPath) {

                        try {

                            $Json = Get-Content $JsonPath -Raw | ConvertFrom-Json
                            $Changed = $false

                            if (($Json.keywords -join ",") -eq "portable,toolkit,maintenance") {

                                $Json.keywords = @(
                                    ($Module.Name -replace "_", " ").ToLower(),
                                    "toolkit",
                                    "windows",
                                    "utility"
                                )

                                $Changed = $true
                            }

                            if ($Json.description -like "Portable toolkit module for*") {

                                $CleanName = $Module.Name -replace "_", " "

                                $Json.description = "Runs the $CleanName toolkit utility."

                                $Changed = $true
                            }

                            if ($Json.estimated_time -eq "Unknown") {

                                $Json.estimated_time = "1-5 Minutes"

                                $Changed = $true
                            }

                            if ($Changed) {

                                $Json |
                                    ConvertTo-Json -Depth 10 |
                                    Set-Content `
                                        $JsonPath `
                                        -Encoding UTF8

                                Write-Host "[FIXED] $($Module.Name)" -ForegroundColor Green

                                $Fixed++
                            }
                        }
                        catch {

                            Write-Host "[FAIL] $($Module.Name)" -ForegroundColor Red
                        }
                    }
                }

                Write-Host ""
                Write-Host "Safe Fixes Applied: $Fixed"
                Write-Host ""

                Pause-Toolkit
            }

            "4" {

                Clear-Host

                $Migrated = 0
                $UnknownRisk = 0
                $UnknownTime = 0
                $GenericDescription = 0
                $GenericKeywords = 0

                Get-ChildItem $ModulesPath -Directory | ForEach-Object {

                    $JsonPath = Join-Path $_.FullName "tool.json"

                    if (Test-Path $JsonPath) {

                        try {

                            $Json = Get-Content $JsonPath -Raw | ConvertFrom-Json

                            if ($Json.subcategory -eq "Migrated Modules") {
                                $Migrated++
                            }

                            if ($Json.risk -eq "Unknown") {
                                $UnknownRisk++
                            }

                            if ($Json.estimated_time -eq "Unknown") {
                                $UnknownTime++
                            }

                            if ($Json.description -like "Portable toolkit module for*") {
                                $GenericDescription++
                            }

                            if (($Json.keywords -join ",") -eq "portable,toolkit,maintenance") {
                                $GenericKeywords++
                            }
                        }
                        catch {}
                    }
                }

                Write-Host "============================================================"
                Write-Host "             WEAK METADATA SUMMARY"
                Write-Host "============================================================"
                Write-Host ""

                Write-Host "Migrated Subcategory : $Migrated"
                Write-Host "Unknown Risk         : $UnknownRisk"
                Write-Host "Unknown Time         : $UnknownTime"
                Write-Host "Generic Description  : $GenericDescription"
                Write-Host "Generic Keywords     : $GenericKeywords"

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