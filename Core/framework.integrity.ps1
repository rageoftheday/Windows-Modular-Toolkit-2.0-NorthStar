# ============================================================
# FRAMEWORK INTEGRITY ENGINE
# ============================================================

function Get-ToolkitIntegrityPropertyValue {
    param([object]$Item, [string]$Name, [object]$Default = $null)
    if ($null -eq $Item) { return $Default }
    if ($Item.PSObject.Properties.Name -contains $Name) {
        $Value = $Item.$Name
        if ($null -ne $Value) { return $Value }
    }
    return $Default
}

function Get-ToolkitIntegrityUserModules {
    param([array]$Registry)
    return @(
        $Registry | Where-Object {
            (Get-ToolkitIntegrityPropertyValue $_ 'module_scope' '') -ne 'Framework' -and
            (Get-ToolkitIntegrityPropertyValue $_ 'framework_protected' $false) -ne $true
        }
    )
}

function Get-ToolkitIntegrityUserCategories {
    param([array]$Registry)
    return @(
        Get-ToolkitIntegrityUserModules $Registry |
        ForEach-Object { [string](Get-ToolkitIntegrityPropertyValue $_ 'category' '') } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    )
}



function Get-ToolkitFrameworkRequiredFiles {
    @(
        "Toolkit.ps1",
        "Start.bat",
        "core\bootstrap.ps1",
        "core\toolkit.core.ps1",
        "core\settings.engine.ps1",
        "core\dependency.engine.ps1",
        "core\module.api.ps1",
        "core\module.loader.ps1",
        "core\menu.engine.ps1",
        "core\framework.integrity.ps1",
        "Framework\Toolkit_Registry\run.ps1",
        "Framework\Toolkit_Health_Center\run.ps1",
        "Framework\Enhanced_Add_Tool_Wizard\run.ps1",
        "Framework\Category_Browser\run.ps1",
        "Framework\Remove_Tool_Wizard\run.ps1",
        "Framework\Framework_Integrity_Check\run.ps1"
    )
}

function Test-ToolkitFrameworkIntegrity {
    param(
        [string]$Root = $Global:ToolkitRoot
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Resolve-Path "$PSScriptRoot\.."
    }

    $Missing = @()
    $Present = @()

    foreach ($Relative in Get-ToolkitFrameworkRequiredFiles) {
        $Path = Join-Path $Root $Relative
        if (Test-Path $Path) {
            $Present += $Relative
        }
        else {
            $Missing += $Relative
        }
    }

    [PSCustomObject]@{
        Root = $Root
        Present = $Present
        Missing = $Missing
        MissingCount = $Missing.Count
        Passed = ($Missing.Count -eq 0)
    }
}

function Show-ToolkitFrameworkStatus {
    param(
        [array]$Registry = @(),
        [switch]$Startup
    )

    $Integrity = Test-ToolkitFrameworkIntegrity

    $FrameworkCount = @($Registry | Where-Object { (Get-ToolkitIntegrityPropertyValue $_ 'module_scope' '') -eq "Framework" -or (Get-ToolkitIntegrityPropertyValue $_ 'framework_protected' $false) -eq $true }).Count
    $ModuleCount = @(Get-ToolkitIntegrityUserModules $Registry | Where-Object { (Get-ToolkitIntegrityPropertyValue $_ 'hidden' $false) -ne $true }).Count
    $CategoryCount = @(Get-ToolkitIntegrityUserCategories $Registry).Count

    Show-ToolkitHeader "FRAMEWORK STATUS"

    if ($Integrity.Passed) {
        Show-ToolkitStatus "PASS" "Framework files found"
    }
    else {
        Show-ToolkitStatus "FAIL" "Framework files missing"
        Write-Host ""
        foreach ($Item in $Integrity.Missing) {
            Write-Host "Missing: $Item" -ForegroundColor Red
        }
    }

    if ($Registry -and $Registry.Count -gt 0) {
        Show-ToolkitStatus "PASS" "Registry loaded"
    }
    else {
        Show-ToolkitStatus "WARN" "Registry empty or not loaded"
    }

    Write-Host ""
    Write-Host "Framework Components .. $FrameworkCount"
    Write-Host "User Modules .......... $ModuleCount"
    Write-Host "User Categories ....... $CategoryCount"
    Write-Host ""

    if ($Integrity.Passed) {
        Write-Host "Status: HEALTHY" -ForegroundColor Green
    }
    else {
        Write-Host "Status: ATTENTION REQUIRED" -ForegroundColor Yellow
    }

    Write-Host ""

    if ($Startup) {
        Write-Host "[1] Continue"
        Write-Host ""
        return Read-Host "Selection"
    }

    Write-Host "[1] Run Integrity Check"
    Write-Host "[2] Open Health Center"
    Write-Host "[B] Back"
    Write-Host ""
    return Read-Host "Selection"
}
