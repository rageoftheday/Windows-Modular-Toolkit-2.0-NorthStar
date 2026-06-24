$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"
# ============================================================
# TOOLKIT DASHBOARD
# ============================================================

$RegistryPath = Join-Path $Root "cache\toolkit_registry.json"

Invoke-ToolkitModule `
    -ModuleName "TOOLKIT DASHBOARD" `
    -RequiresAdmin $false `
    -ScriptBlock {

    while ($true) {
        Clear-Host

        $Registry = @()
        if (Test-Path $RegistryPath) {
            $Registry = @(Get-ToolkitRegistry $RegistryPath)
        }

        $FrameworkItems = @($Registry | Where-Object { $_.module_scope -eq "Framework" -or $_.framework_protected -eq $true })
        $UserModules = @($Registry | Where-Object { $_.module_scope -ne "Framework" -and $_.framework_protected -ne $true })
        $VisibleUserModules = @($UserModules | Where-Object { $_.hidden -ne $true })

        $UserCategories = @($VisibleUserModules | ForEach-Object {
            if ($_.PSObject.Properties.Name -contains "category" -and -not [string]::IsNullOrWhiteSpace([string]$_.category)) {
                [string]$_.category
            }
        } | Sort-Object -Unique)

        $AdminModules = @($VisibleUserModules | Where-Object { $_.PSObject.Properties.Name -contains "requires_admin" -and $_.requires_admin -eq $true })
        $SafeModules = @($VisibleUserModules | Where-Object { $_.PSObject.Properties.Name -contains "risk" -and $_.risk -eq "Safe" })
        $DangerousModules = @($VisibleUserModules | Where-Object { $_.PSObject.Properties.Name -contains "risk" -and $_.risk -eq "Dangerous" })
        $LogModules = @($VisibleUserModules | Where-Object { $_.PSObject.Properties.Name -contains "supports_logs" -and $_.supports_logs -eq $true })
        $ExportModules = @($VisibleUserModules | Where-Object { $_.PSObject.Properties.Name -contains "supports_export" -and $_.supports_export -eq $true })

        Write-Host ""
        Write-Host "============================================================"
        Write-Host " TOOLKIT DASHBOARD"
        Write-Host "============================================================"
        Write-Host ""
        Write-Host "Framework Components : $($FrameworkItems.Count)"
        Write-Host "User Modules         : $($VisibleUserModules.Count)"
        Write-Host "User Categories      : $($UserCategories.Count)"
        Write-Host "Total Registry Items : $($Registry.Count)"
        Write-Host ""
        Write-Host "User Module Details"
        Write-Host "-------------------"
        Write-Host "Admin Modules        : $($AdminModules.Count)"
        Write-Host "Safe Modules         : $($SafeModules.Count)"
        Write-Host "Dangerous Modules    : $($DangerousModules.Count)"
        Write-Host "Logging Enabled      : $($LogModules.Count)"
        Write-Host "Export Enabled       : $($ExportModules.Count)"
        Write-Host ""
        Write-Host "============================================================"
        Write-Host ""
        Write-Host "[R] Refresh"
        Write-Host "[B] Back"
        Write-Host ""

        $Choice = Read-Host "Selection"
        switch ($Choice.ToUpper()) {
            "R" { continue }
            "B" { return }
        }
    }
}
