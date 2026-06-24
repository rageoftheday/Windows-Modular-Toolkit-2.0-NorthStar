# ============================================================
# TOOLKIT MENU ENGINE
# ============================================================

function Get-ToolkitCategoryIcon {

    param([string]$Category)

    switch -Regex ($Category) {
        "Activation"              { return "[ACT]" }
        "Boot|Recovery"           { return "[BOOT]" }
        "Cleanup"                 { return "[CLEAN]" }
        "Disk|Storage"            { return "[DISK]" }
        "Driver|Kernel"           { return "[DRV]" }
        "Network"                 { return "[NET]" }
        "Printer"                 { return "[PRINT]" }
        "Process|Services"        { return "[PROC]" }
        "Security"                { return "[SEC]" }
        "Setup|Dependencies"      { return "[SETUP]" }
        "System Information"      { return "[INFO]" }
        "Toolkit Management"      { return "[MGMT]" }
        "Toolkit Operations"      { return "[OPS]" }
        "Windows Features"        { return "[FEAT]" }
        "Windows Repair"          { return "[REPAIR]" }
        default                   { return "[TOOL]" }
    }
}

function Get-ToolkitRiskColor {

    param([string]$Risk)

    switch ($Risk) {
        "Safe"      { return "Green" }
        "Moderate"  { return "Yellow" }
        "Dangerous" { return "Red" }
        default     { return "White" }
    }
}

function Show-ToolkitMenu {

    param(
        [array]$Menu
    )

    foreach ($Item in $Menu) {
        Write-Host "[$($Item.Key)] $($Item.Label)"

        # Optional purpose text helps users find the right place without opening help.
        # Do not show purpose text for obvious navigation actions.
        $NavigationKeys = @("B","Q","X","N","P","R")
        if ($Item.PSObject.Properties.Name -contains "Purpose" -and
            $NavigationKeys -notcontains ([string]$Item.Key).ToUpper() -and
            -not [string]::IsNullOrWhiteSpace([string]$Item.Purpose)) {
            Write-Host "    $($Item.Purpose)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
}

function Show-ToolkitCategoryList {

    param(
        [array]$CategoryGroups
    )

    $Index = 1

    foreach ($Group in $CategoryGroups) {
        $Icon = Get-ToolkitCategoryIcon $Group.Name
        Write-Host "[$Index] $Icon $($Group.Name) ($($Group.Count))"
        $Index++
    }

    Write-Host ""
}

function Show-ToolkitModuleList {

    param(
        [array]$Modules
    )

    $Index = 1

    foreach ($Module in $Modules) {

        $AdminIcon = ""

        if ($Module.requires_admin -eq $true) {
            $AdminIcon = " [ADMIN]"
        }

        $DisplayName = $Module.name

        if ([string]::IsNullOrWhiteSpace($DisplayName)) {
            $DisplayName = $Module.Label
        }

        $RiskColor = Get-ToolkitRiskColor $Module.risk

        Write-Host "[$Index] $DisplayName$AdminIcon" -ForegroundColor $RiskColor

        if ($Module.description) {
            Write-Host "     $($Module.description)"
        }

        if ($Module.risk) {
            Write-Host "     Risk : $($Module.risk)" -ForegroundColor $RiskColor
        }

        if ($Module.requires_admin -eq $true) {
            Write-Host "     Admin: Yes" -ForegroundColor Yellow
        }
        else {
            Write-Host "     Admin: No"
        }

        Write-Host ""
        $Index++
    }
}
