# ============================================================
# DYNAMIC HUB ENGINE
# ============================================================

function Invoke-ToolkitHub {

    param(

        [string]$Title,

        [string]$Category,

        [string]$Subcategory,

        [string]$Keyword
    )

    $Root = Resolve-Path "$PSScriptRoot\.."

    $RegistryPath = Join-Path `
        $Root `
        "cache\toolkit_registry.json"

    if (!(Test-Path $RegistryPath)) {

        Write-Host ""
        Write-Host "Toolkit registry not found." `
            -ForegroundColor Red

        Pause-Toolkit
        return
    }

    $Registry = Get-Content `
        $RegistryPath `
        -Raw | ConvertFrom-Json

    # ========================================================
    # FILTER MODULES
    # ========================================================

    $Modules = $Registry | Where-Object {

        $Match = $false

        # ----------------------------------------------------
        # CATEGORY
        # ----------------------------------------------------

        if (
            $Category -and
            $_.category -eq $Category
        ) {

            $Match = $true
        }

        # ----------------------------------------------------
        # SUBCATEGORY
        # ----------------------------------------------------

        if (
            $Subcategory -and
            $_.subcategory -eq $Subcategory
        ) {

            $Match = $true
        }

        # ----------------------------------------------------
        # KEYWORD
        # ----------------------------------------------------

        if (
            $Keyword -and
            $_.keywords -contains $Keyword
        ) {

            $Match = $true
        }

        return $Match
    }

    # ========================================================
    # SORT
    # ========================================================

    $Modules = $Modules |
        Sort-Object name

    # ========================================================
    # MENU LOOP
    # ========================================================

    while ($true) {

        Clear-Host

        Write-Host "============================================================"
        Write-Host " $Title"
        Write-Host "============================================================"
        Write-Host ""

        if (!$Modules) {

            Write-Host "No matching modules found." `
                -ForegroundColor Yellow

            Write-Host ""
            Pause-Toolkit
            return
        }

        $Index = 1

        foreach ($Module in $Modules) {

            Write-Host "[$Index] $($Module.name)"

            Write-Host "     Risk  : $($Module.risk)"
            Write-Host "     Admin : $($Module.requires_admin)"

            Write-Host ""

            $Index++
        }

        Write-Host "[BACK] Return"
        Write-Host "[EXIT] Exit Toolkit"
        Write-Host ""

        $Selection = Read-Host "Select module"

        if ($Selection.ToUpper() -eq "BACK") {
            return
        }

        if ($Selection.ToUpper() -eq "EXIT") {
            exit
        }

        if ($Selection -notmatch '^\d+$') {
            continue
        }

        $SelectedModule = $Modules[[int]$Selection - 1]

        if (!$SelectedModule) {
            continue
        }

        Start-ToolkitModule $SelectedModule
    }
}