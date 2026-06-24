# ============================================================
# TOOLKIT DEPENDENCY ENGINE
# ============================================================

function Test-ToolkitDependency {

    param(
        [string]$Dependency
    )

    switch ($Dependency.ToLower()) {

        "winget" {
            return [bool](Get-Command winget -ErrorAction SilentlyContinue)
        }

        "git" {
            return [bool](Get-Command git -ErrorAction SilentlyContinue)
        }

        "powershell" {
            return [bool](Get-Command powershell -ErrorAction SilentlyContinue)
        }

        "rsat" {
            $rsat = Get-WindowsCapability -Online -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Name -like "*RSAT*" -and
                    $_.State -eq "Installed"
                }

            return [bool]$rsat
        }

        default {
            return $false
        }
    }
}

function Test-ToolkitDependencies {

    param(
        $Module
    )

    # Normalize dependencies. Some older/generated modules may contain
    # "None" as a literal value. That means no dependencies and must not
    # block module launch.
    $Dependencies = @()

    if ($Module.dependencies) {
        foreach ($Dependency in @($Module.dependencies)) {
            $depText = [string]$Dependency
            if ([string]::IsNullOrWhiteSpace($depText)) { continue }
            if ($depText.Trim().ToLowerInvariant() -in @("none", "n/a", "na", "no dependencies")) { continue }
            $Dependencies += $depText.Trim()
        }
    }

    if ($Dependencies.Count -eq 0) {
        return $true
    }

    $Missing = @()

    foreach ($Dependency in $Dependencies) {

        $Installed = Test-ToolkitDependency $Dependency

        if (!$Installed) {
            $Missing += $Dependency
        }
    }

    if ($Missing.Count -gt 0) {

        Write-Host ""
        Write-Host "============================================================"
        Write-Host " MISSING DEPENDENCIES"
        Write-Host "============================================================"
        Write-Host ""

        foreach ($Item in $Missing) {
            Write-Host " - $Item" -ForegroundColor Red
        }

        Write-Host ""

        return $false
    }

    return $true
}