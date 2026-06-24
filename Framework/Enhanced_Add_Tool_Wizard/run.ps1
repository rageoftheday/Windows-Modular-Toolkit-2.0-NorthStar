# ============================================================
# ENHANCED ADD TOOL WIZARD
# Windows Modular Toolkit - Framework Edition 2.0
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\Core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "ENHANCED ADD TOOL WIZARD" `
    -RequiresAdmin $false `
    -ScriptBlock {

    function Convert-ToSafeFolderName {
        param([string]$Name)
        $Safe = $Name.Trim()
        $Safe = $Safe -replace '[^\w\s-]', ''
        $Safe = $Safe -replace '\s+', '_'
        return $Safe
    }

    function Read-WizardInput {
        param(
            [string]$Prompt,
            [switch]$AllowBlank,
            [int]$MinLength = 0,
            [int]$MaxLength = 0
        )

        while ($true) {
            Write-Host ""
            Write-Host "[B] Back / Cancel"
            $Value = Read-Host $Prompt

            if ($null -eq $Value) { $Value = "" }
            $Value = $Value.Trim()

            if ($Value.ToUpper() -eq "B") { return $null }

            if (!$AllowBlank -and [string]::IsNullOrWhiteSpace($Value)) {
                Write-Host "Value required." -ForegroundColor Yellow
                continue
            }

            if ($MinLength -gt 0 -and $Value.Length -lt $MinLength -and !$AllowBlank) {
                Write-Host "Minimum length is $MinLength characters." -ForegroundColor Yellow
                continue
            }

            if ($MaxLength -gt 0 -and $Value.Length -gt $MaxLength) {
                Write-Host "Maximum length is $MaxLength characters." -ForegroundColor Yellow
                continue
            }

            return $Value
        }
    }

    function Get-ExistingUserCategories {
        $ModulesRoot = Join-Path $Root "Modules"
        $Categories = @()

        if (Test-Path $ModulesRoot) {
            Get-ChildItem $ModulesRoot -Directory | ForEach-Object {
                Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                    $JsonPath = Join-Path $_.FullName "tool.json"
                    if (Test-Path $JsonPath) {
                        try {
                            $Json = Get-Content $JsonPath -Raw | ConvertFrom-Json
                            if ($Json.category) { $Categories += [string]$Json.category }
                        } catch {}
                    }
                }
            }
        }

        $Defaults = @(
            "Network Tools",
            "Printer Tools",
            "System Information",
            "Windows Repair",
            "Setup and Dependencies",
            "Cleanup Tools",
            "Security Tools",
            "Custom Tools"
        )

        return @($Defaults + $Categories | Where-Object { $_ } | Sort-Object -Unique)
    }

    function Select-Category {
        while ($true) {
            Show-ToolkitHeader "SELECT CATEGORY"
            $Categories = @(Get-ExistingUserCategories)

            for ($i = 0; $i -lt $Categories.Count; $i++) {
                Write-Host "[$($i+1)] $($Categories[$i])"
            }

            Write-Host ""
            Write-Host "[N] New Category"
            Write-Host "[B] Back / Cancel"
            Write-Host ""
            $Choice = (Read-Host "Selection").Trim()

            if ($Choice.ToUpper() -eq "B") { return $null }
            if ($Choice.ToUpper() -eq "N") {
                $NewCategory = Read-WizardInput -Prompt "New category name" -MinLength 1 -MaxLength 35
                return $NewCategory
            }

            $Number = 0
            if ([int]::TryParse($Choice, [ref]$Number)) {
                if ($Number -ge 1 -and $Number -le $Categories.Count) {
                    return $Categories[$Number - 1]
                }
            }

            Write-Host "Invalid selection." -ForegroundColor Yellow
            Pause-Toolkit
        }
    }

    function Select-Risk {
        while ($true) {
            Show-ToolkitHeader "SELECT RISK LEVEL"
            Write-Host "[1] Safe"
            Write-Host "    Read-only or low impact."
            Write-Host "[2] Moderate"
            Write-Host "    May change settings, clear cache, restart services, or install something."
            Write-Host "[3] High Impact"
            Write-Host "    Repairs, deletes, resets, disables, or makes major system changes."
            Write-Host ""
            Write-Host "[B] Back / Cancel"
            Write-Host ""
            $Choice = (Read-Host "Selection").Trim().ToUpper()
            switch ($Choice) {
                "1" { return "Safe" }
                "2" { return "Moderate" }
                "3" { return "High Impact" }
                "B" { return $null }
            }
        }
    }

    function Read-BooleanChoice {
        param([string]$Title)
        while ($true) {
            Write-Host ""
            Write-Host "$Title"
            Write-Host "[Y] True"
            Write-Host "[N] False"
            Write-Host "[B] Back / Cancel"
            $Choice = (Read-Host "Selection").Trim().ToUpper()
            switch ($Choice) {
                "Y" { return $true }
                "N" { return $false }
                "B" { return $null }
            }
        }
    }

    function Normalize-ListItem {
        param([string]$Value)
        $v = $Value.Trim()
        if (!$v) { return $null }
        switch -Regex ($v.ToLower()) {
            '^(ps|pwsh|powershell)$' { return "PowerShell" }
            '^(ad|active directory|activedirectory)$' { return "Active Directory" }
            '^(7zip|7z|7-zip)$' { return "7-Zip" }
            '^(import excel|importexcel)$' { return "ImportExcel" }
            '^(winget|windows package manager)$' { return "Winget" }
            default { return $v }
        }
    }

    function Read-KeywordList {
        while ($true) {
            Show-ToolkitHeader "KEYWORDS"
            Write-Host "Keywords are required for search."
            Write-Host "Minimum: 1 | Maximum: 10"
            Write-Host "Example: dns, network, cache"
            Write-Host ""
            Write-Host "[B] Back / Cancel"
            $Raw = Read-Host "Keywords comma separated"
            if ($Raw.Trim().ToUpper() -eq "B") { return $null }

            $Items = @($Raw -split "," | ForEach-Object { Normalize-ListItem $_ } | Where-Object { $_ } | Select-Object -Unique)

            if ($Items.Count -lt 1) {
                Write-Host "At least 1 keyword is required." -ForegroundColor Yellow
                Pause-Toolkit
                continue
            }
            if ($Items.Count -gt 10) {
                Write-Host "Maximum 10 keywords allowed." -ForegroundColor Yellow
                Pause-Toolkit
                continue
            }
            return $Items
        }
    }

    function Read-DependencyList {
        Show-ToolkitHeader "DEPENDENCIES"
        Write-Host "Dependencies are optional."
        Write-Host "Maximum: 15"
        Write-Host "Examples: PowerShell, Winget, RSAT, ImportExcel, Git, 7-Zip"
        Write-Host ""
        Write-Host "[B] Back / Cancel"
        $Raw = Read-Host "Dependencies comma separated, or blank for none"
        if ($Raw.Trim().ToUpper() -eq "B") { return $null }

        if ([string]::IsNullOrWhiteSpace($Raw)) { return @() }

        $Items = @($Raw -split "," | ForEach-Object { Normalize-ListItem $_ } | Where-Object { $_ } | Select-Object -Unique)
        if ($Items.Count -gt 15) {
            Write-Host "Maximum 15 dependencies allowed. Extra entries were ignored." -ForegroundColor Yellow
            $Items = @($Items | Select-Object -First 15)
            Pause-Toolkit
        }
        return $Items
    }

    function Start-ExternalModule {
        param([string]$Folder)

        $ToolPath = Join-Path $Root "Framework\$Folder"
        $RunPath = Join-Path $ToolPath "run.ps1"

        if (!(Test-Path $RunPath)) {
            Write-Host "run.ps1 not found for: $Folder" -ForegroundColor Red
            Pause-Toolkit
            return
        }

        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RunPath
    }

    function New-ToolkitModule {
        Show-ToolkitHeader "CREATE NEW TOOL"
        Write-Host "Every prompt supports [B] Back / Cancel."

        $ToolName = Read-WizardInput -Prompt "Tool name" -MinLength 3 -MaxLength 40
        if ($null -eq $ToolName) { return }

        $FolderName = Convert-ToSafeFolderName $ToolName
        $Category = Select-Category
        if ($null -eq $Category) { return }

        $ModuleDir  = Join-Path (Join-Path $Root "Modules") (Convert-ToSafeFolderName $Category)
        $ModuleDir  = Join-Path $ModuleDir $FolderName

        if (Test-Path $ModuleDir) {
            Write-Host "Module already exists:" -ForegroundColor Red
            Write-Host $ModuleDir
            Pause-Toolkit
            return
        }

        $Subcategory = Read-WizardInput -Prompt "Subcategory (optional)" -AllowBlank -MaxLength 35
        if ($null -eq $Subcategory) { return }

        $Description = Read-WizardInput -Prompt "Description (optional, max 250)" -AllowBlank -MaxLength 250
        if ($null -eq $Description) { return }

        $Keywords = Read-KeywordList
        if ($null -eq $Keywords) { return }

        $Risk = Select-Risk
        if ($null -eq $Risk) { return }

        $RequiresAdmin = Read-BooleanChoice "Requires Admin?"
        if ($null -eq $RequiresAdmin) { return }

        $SupportsLogs = Read-BooleanChoice "Supports Logs?"
        if ($null -eq $SupportsLogs) { return }

        $SupportsExport = Read-BooleanChoice "Supports Export?"
        if ($null -eq $SupportsExport) { return }

        $Dependencies = Read-DependencyList
        if ($null -eq $Dependencies) { return }

        Show-ToolkitHeader "CONFIRM NEW TOOL"
        Write-Host "Name        : $ToolName"
        Write-Host "Category    : $Category"
        Write-Host "Subcategory : $Subcategory"
        Write-Host "Risk        : $Risk"
        Write-Host "Admin       : $RequiresAdmin"
        Write-Host "Keywords    : $($Keywords -join ', ')"
        Write-Host "Dependencies: $($Dependencies -join ', ')"
        Write-Host ""
        Write-Host "[Y] Create Tool"
        Write-Host "[B] Back / Cancel"
        $Confirm = (Read-Host "Selection").Trim().ToUpper()
        if ($Confirm -ne "Y") { return }

        New-Item -ItemType Directory -Path $ModuleDir -Force | Out-Null

        $RunPs1 = Join-Path $ModuleDir "run.ps1"
        $RunBat = Join-Path $ModuleDir "run.bat"
        $ToolJson = Join-Path $ModuleDir "tool.json"

@"
# ============================================================
# $($ToolName.ToUpper())
# ============================================================

`$Root = Resolve-Path "`$PSScriptRoot\..\..\.."
. "`$Root\Core\bootstrap.ps1"

Invoke-ToolkitModule ``
    -ModuleName "$ToolName" ``
    -RequiresAdmin `$$RequiresAdmin ``
    -ScriptBlock {

    Write-Host "$ToolName"
    Write-Host "$Description"
    Write-Host ""
    Write-Host "Replace this section with your tool logic."
    Write-Host ""
    Write-Host "Output note: the toolkit launcher pauses after this script returns."
}
"@ | Set-Content $RunPs1

@"
@echo off
setlocal
cd /d `"%~dp0`"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0run.ps1`"
set `"TOOLKIT_MODULE_EXITCODE=%ERRORLEVEL%`"

REM If launched from inside the toolkit, the framework pauses after return.
REM If double-clicked or run directly, pause here so output stays visible.
if /I not `"%TOOLKIT_LAUNCHED%`"==`"1`" (
    echo.
    pause
)

endlocal & exit /b %TOOLKIT_MODULE_EXITCODE%
"@ | Set-Content $RunBat

        [PSCustomObject]@{
            name            = $ToolName
            category        = $Category
            subcategory     = $Subcategory
            description     = $Description
            keywords        = $Keywords
            risk            = $Risk
            requires_admin  = $RequiresAdmin
            supports_logs   = $SupportsLogs
            supports_export = $SupportsExport
            entry           = "run.bat"
            dependencies    = $Dependencies
            hidden          = $false
        } | ConvertTo-Json -Depth 5 | Set-Content $ToolJson

        Write-Host ""
        Write-Host "[CREATED] $ToolName" -ForegroundColor Green
        Write-Host $ModuleDir
        Write-Host ""
        Write-Host "Run Registry Manager after adding or changing tools."
        Pause-Toolkit
    }

    while ($true) {
        Show-ToolkitHeader "ENHANCED ADD TOOL WIZARD"
        Write-Host "Create new user modules without manually editing JSON."
        Write-Host ""
        Write-Host "[1] Create New Tool"
        Write-Host "[2] Open Toolkit Registry Builder"
        Write-Host "[3] Open Dry Run Validator"
        Write-Host "[4] Open Modules Folder"
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""

        $Choice = (Read-Host "Selection").Trim().ToUpper()

        switch ($Choice) {
            "1" { New-ToolkitModule }
            "2" { Start-ExternalModule "Toolkit_Registry" }
            "3" { Start-ExternalModule "Dry_Run_Module_Validator" }
            "4" { explorer.exe (Join-Path $Root "Modules") }
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
