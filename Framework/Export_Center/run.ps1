# ============================================================
# EXPORT CENTER
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "EXPORT CENTER" `
    -RequiresAdmin $false `
    -ScriptBlock {

    Show-ToolkitHeader "EXPORT CENTER"

    $ExportDir = Join-Path $Root "exports"

    if (!(Test-Path $ExportDir)) {
        New-Item -ItemType Directory -Path $ExportDir | Out-Null
    }

    $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Out = Join-Path $ExportDir "Toolkit_Snapshot_$Stamp.txt"

    "WINDOWS MODULAR TOOLKIT EXPORT SNAPSHOT" | Out-File $Out -Encoding UTF8
    "Generated: $(Get-Date)" | Out-File $Out -Append
    "" | Out-File $Out -Append

    "=== TOOLKIT REGISTRY SUMMARY ===" | Out-File $Out -Append

    $RegistryPath = Join-Path $Root "cache\toolkit_registry.json"

    if (Test-Path $RegistryPath) {
        $Registry = @(Get-ToolkitRegistry $RegistryPath)

        $FrameworkItems = @($Registry | Where-Object { ($_.PSObject.Properties.Name -contains "module_scope" -and $_.module_scope -eq "Framework") -or ($_.PSObject.Properties.Name -contains "framework_protected" -and $_.framework_protected -eq $true) })
        $UserItems = @($Registry | Where-Object { !(($_.PSObject.Properties.Name -contains "module_scope" -and $_.module_scope -eq "Framework") -or ($_.PSObject.Properties.Name -contains "framework_protected" -and $_.framework_protected -eq $true)) })
        $VisibleUserItems = @($UserItems | Where-Object { !($_.PSObject.Properties.Name -contains "hidden" -and $_.hidden -eq $true) })
        $UserCategories = @($UserItems | ForEach-Object { if ($_.PSObject.Properties.Name -contains "category") { [string]$_.category } } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

        "Framework Components : $($FrameworkItems.Count)" | Out-File $Out -Append
        "User Modules          : $($VisibleUserItems.Count)" | Out-File $Out -Append
        "User Categories       : $($UserCategories.Count)" | Out-File $Out -Append
        "Total Registry Items  : $($Registry.Count)" | Out-File $Out -Append
        "" | Out-File $Out -Append

        $Registry |
            Select-Object name, module_scope, category, risk, requires_admin, hidden, folder |
            Sort-Object category, name |
            Format-Table -AutoSize |
            Out-String |
            Out-File $Out -Append
    }
    else {
        "Registry missing." | Out-File $Out -Append
    }

    Write-Host "Snapshot exported:"
    Write-Host $Out
    Write-Host ""
}
