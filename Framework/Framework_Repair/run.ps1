# ============================================================
# WINDOWS MODULAR TOOLKIT - FRAMEWORK REPAIR
# Framework Edition 2.0
# ============================================================

$ErrorActionPreference = "Continue"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolkitRoot = Resolve-Path (Join-Path $ScriptRoot "..\..")
$ToolkitRoot = $ToolkitRoot.Path
$script:LastRepairResults = $null

function Show-LocalHeader {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "============================================================"
    Write-Host " $Title"
    Write-Host "============================================================"
    Write-Host ""
}

function Wait-Back {
    Write-Host ""
    Write-Host "[B] Back"
    do { $Choice = Read-Host "Selection" } while ($Choice.ToUpper() -ne "B")
}

function Save-JsonFile {
    param([string]$Path, $Data)
    $Folder = Split-Path -Parent $Path
    if (-not (Test-Path $Folder)) { New-Item -ItemType Directory -Path $Folder -Force | Out-Null }
    $Data | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding UTF8
}

function Get-ToolJsonObjects {
    $Items = New-Object System.Collections.ArrayList
    $Roots = @(
        @{ Scope = "Modules"; Base = Join-Path $ToolkitRoot "Modules" },
        @{ Scope = "Framework"; Base = Join-Path $ToolkitRoot "Framework" }
    )

    foreach ($RootItem in $Roots) {
        $Base = $RootItem.Base
        if (-not (Test-Path $Base)) { continue }
        Get-ChildItem -Path $Base -Recurse -Filter "tool.json" -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $Json = Get-Content $_.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
                $FolderPath = Split-Path -Parent $_.FullName
                $FolderName = Split-Path -Leaf $FolderPath
                $RelPath = $FolderPath.Substring($ToolkitRoot.Length).TrimStart('\','/') -replace '\\','/'

                if (-not ($Json.PSObject.Properties.Name -contains 'folder')) {
                    Add-Member -InputObject $Json -MemberType NoteProperty -Name folder -Value $FolderName -Force
                } else { $Json.folder = $FolderName }

                if (-not ($Json.PSObject.Properties.Name -contains 'path')) {
                    Add-Member -InputObject $Json -MemberType NoteProperty -Name path -Value $RelPath -Force
                } else { $Json.path = $RelPath }

                if ($RootItem.Scope -eq "Framework") {
                    if (-not ($Json.PSObject.Properties.Name -contains 'module_scope')) {
                        Add-Member -InputObject $Json -MemberType NoteProperty -Name module_scope -Value "Framework" -Force
                    }
                    if (-not ($Json.PSObject.Properties.Name -contains 'framework_protected')) {
                        Add-Member -InputObject $Json -MemberType NoteProperty -Name framework_protected -Value $true -Force
                    }
                }

                [void]$Items.Add($Json)
            } catch {
                # Registry repair should not fail because one bad tool.json exists.
            }
        }
    }

    return @($Items | Sort-Object category, name)
}

function Test-RequiredPaths {
    param([switch]$Repair)
    $Actions = New-Object System.Collections.ArrayList
    $Warnings = New-Object System.Collections.ArrayList
    $Required = @("Core","Framework","Modules","Config","Cache","Logs","Exports","Docs")
    foreach ($Name in $Required) {
        $Path = Join-Path $ToolkitRoot $Name
        if (Test-Path $Path) {
            [void]$Actions.Add("Present: $Name")
        } elseif ($Repair) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            [void]$Actions.Add("Created missing folder: $Name")
        } else {
            [void]$Warnings.Add("Missing folder: $Name")
        }
    }
    return [PSCustomObject]@{ Name="Required Paths"; Status=$(if ($Warnings.Count -eq 0) {"PASS"} else {"WARNING"}); Actions=@($Actions); Warnings=@($Warnings) }
}

function Repair-Registry {
    param([switch]$Repair)
    $Actions = New-Object System.Collections.ArrayList
    $Warnings = New-Object System.Collections.ArrayList
    $Cache = Join-Path $ToolkitRoot "Cache"
    $RegistryPath = Join-Path $Cache "toolkit_registry.json"
    if ($Repair -and -not (Test-Path $Cache)) { New-Item -ItemType Directory -Path $Cache -Force | Out-Null }
    $Items = @(Get-ToolJsonObjects)
    if ($Items.Count -eq 0) {
        [void]$Warnings.Add("No tool.json files were discovered.")
    } else {
        [void]$Actions.Add("Discovered registry items: $($Items.Count)")
        if ($Repair) {
            Save-JsonFile -Path $RegistryPath -Data $Items
            [void]$Actions.Add("Rebuilt registry: Cache\toolkit_registry.json")
        } else {
            if (Test-Path $RegistryPath) { [void]$Actions.Add("Registry exists: Cache\toolkit_registry.json") }
            else { [void]$Warnings.Add("Registry missing: Cache\toolkit_registry.json") }
        }
    }
    return [PSCustomObject]@{ Name="Registry"; Status=$(if ($Warnings.Count -eq 0) {"PASS"} else {"WARNING"}); Actions=@($Actions); Warnings=@($Warnings) }
}

function Repair-ConfigDefaults {
    param([switch]$Repair)
    $Actions = New-Object System.Collections.ArrayList
    $Warnings = New-Object System.Collections.ArrayList
    $Config = Join-Path $ToolkitRoot "Config"
    $CategoryRecords = Join-Path $Config "category_records.json"
    if ($Repair -and -not (Test-Path $Config)) { New-Item -ItemType Directory -Path $Config -Force | Out-Null }

    foreach ($File in @($CategoryRecords)) {
        $Name = Split-Path -Leaf $File
        if (Test-Path $File) {
            try { $null = Get-Content $File -Raw | ConvertFrom-Json -ErrorAction Stop; [void]$Actions.Add("Valid JSON: Config\$Name") }
            catch { [void]$Warnings.Add("Invalid JSON: Config\$Name") }
        } elseif ($Repair) {
            Save-JsonFile -Path $File -Data @()
            [void]$Actions.Add("Created default config: Config\$Name")
        } else {
            [void]$Warnings.Add("Missing required config: Config\$Name")
        }
    }

    # Legacy note:
    # favorites.json is no longer part of Framework Edition 2.0 and is intentionally not checked.
    # Root Backups\ is also not required; Config\Backups may exist for config/metadata backups.
    return [PSCustomObject]@{ Name="Config Defaults"; Status=$(if ($Warnings.Count -eq 0) {"PASS"} else {"WARNING"}); Actions=@($Actions); Warnings=@($Warnings) }
}

function Test-PublicContract {
    $Actions = New-Object System.Collections.ArrayList
    $Warnings = New-Object System.Collections.ArrayList
    $ModulesRoot = Join-Path $ToolkitRoot "Modules"
    if (-not (Test-Path $ModulesRoot)) {
        [void]$Warnings.Add("Modules folder missing.")
    } else {
        $ModuleFolders = @(Get-ChildItem -Path $ModulesRoot -Directory -ErrorAction SilentlyContinue)
        foreach ($Folder in $ModuleFolders) {
            $ToolJson = Join-Path $Folder.FullName "tool.json"
            $RunPs1 = Join-Path $Folder.FullName "run.ps1"
            $RunBat = Join-Path $Folder.FullName "run.bat"
            if (-not (Test-Path $ToolJson)) { [void]$Warnings.Add("Missing tool.json: $($Folder.Name)") }
            if (-not ((Test-Path $RunPs1) -or (Test-Path $RunBat))) { [void]$Warnings.Add("Missing run.ps1/run.bat: $($Folder.Name)") }
        }
        [void]$Actions.Add("Checked module contract for $($ModuleFolders.Count) module folders.")
    }
    return [PSCustomObject]@{ Name="Public Module Contract"; Status=$(if ($Warnings.Count -eq 0) {"PASS"} else {"WARNING"}); Actions=@($Actions); Warnings=@($Warnings) }
}

function Invoke-FrameworkRepairScan {
    param([switch]$Repair)
    $Results = @()
    $Results += Test-RequiredPaths -Repair:$Repair
    $Results += Repair-Registry -Repair:$Repair
    $Results += Repair-ConfigDefaults -Repair:$Repair
    $Results += Test-PublicContract
    $Overall = "PASS"
    if (@($Results | Where-Object { $_.Status -eq "WARNING" }).Count -gt 0) { $Overall = "WARNING" }
    if (@($Results | Where-Object { $_.Status -eq "FAIL" }).Count -gt 0) { $Overall = "FAIL" }

    $script:LastRepairResults = [PSCustomObject]@{
        Generated = Get-Date
        ToolkitRoot = $ToolkitRoot
        Mode = $(if ($Repair) { "Repair" } else { "Check Only" })
        OverallStatus = $Overall
        Results = $Results
    }
    return $script:LastRepairResults
}

function Show-RepairResults {
    param($Data)
    Show-LocalHeader "FRAMEWORK REPAIR RESULTS"
    Write-Host "Mode ............... $($Data.Mode)"
    Write-Host "Overall Status ..... $($Data.OverallStatus)"
    Write-Host "Toolkit Root ....... $($Data.ToolkitRoot)"
    Write-Host ""
    foreach ($Item in $Data.Results) {
        Write-Host "$($Item.Name) ..... $($Item.Status)"
        foreach ($Action in @($Item.Actions)) { Write-Host "  $Action" }
        foreach ($Warning in @($Item.Warnings)) { Write-Host "  [!] $Warning" }
        Write-Host ""
    }
    Wait-Back
}

function Export-RepairReport {
    if (-not $script:LastRepairResults) { $null = Invoke-FrameworkRepairScan }
    $Exports = Join-Path $ToolkitRoot "Exports"
    if (-not (Test-Path $Exports)) { New-Item -ItemType Directory -Path $Exports -Force | Out-Null }
    $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Path = Join-Path $Exports "Framework_Repair_Report_$Stamp.html"
    $Rows = ""
    foreach ($Item in $script:LastRepairResults.Results) {
        $Details = @($Item.Actions + $Item.Warnings) -join "<br/>"
        $Rows += "<tr><td>$($Item.Name)</td><td>$($Item.Status)</td><td>$Details</td></tr>`n"
    }
    $Html = @"
<html><head><title>Framework Repair Report</title>
<style>body{font-family:Segoe UI,Arial,sans-serif;margin:24px;}table{border-collapse:collapse;width:100%;}td,th{border:1px solid #ccc;padding:6px;}th{background:#eee;}</style>
</head><body>
<h1>Windows Modular Toolkit - Framework Repair Report</h1>
<p><b>Generated:</b> $($script:LastRepairResults.Generated)</p>
<p><b>Mode:</b> $($script:LastRepairResults.Mode)</p>
<p><b>Overall Status:</b> $($script:LastRepairResults.OverallStatus)</p>
<p><b>Toolkit Root:</b> $($script:LastRepairResults.ToolkitRoot)</p>
<table><tr><th>Check</th><th>Status</th><th>Details</th></tr>
$Rows
</table>
</body></html>
"@
    $Html | Set-Content -Path $Path -Encoding UTF8
    Show-LocalHeader "FRAMEWORK REPAIR REPORT EXPORTED"
    Write-Host "Report created:"
    Write-Host $Path
    Write-Host ""
    Write-Host "[O] Open Report"
    Write-Host "[B] Back"
    $Choice = Read-Host "Selection"
    if ($Choice.ToUpper() -eq "O") { Start-Process $Path }
}

while ($true) {
    Show-LocalHeader "FRAMEWORK REPAIR"
    Write-Host "Repairs framework-owned state only."
    Write-Host "It does not modify user module scripts, installers, packs, or downloads."
    Write-Host ""
    Write-Host "[1] Run Framework Repair"
    Write-Host "[2] Check Only"
    Write-Host "[3] Detailed Results"
    Write-Host "[4] Generate Repair Report"
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = Read-Host "Selection"
    switch ($Choice.ToUpper()) {
        "1" {
            Show-LocalHeader "CONFIRM FRAMEWORK REPAIR"
            Write-Host "This will repair framework-owned state:"
            Write-Host "- Required framework folders"
            Write-Host "- Cache\toolkit_registry.json"
            Write-Host "- Required Config JSON files"
            Write-Host ""
            Write-Host "It will NOT modify user module scripts or delete user content."
            Write-Host ""
            Write-Host "[Y] Yes, run repair"
            Write-Host "[B] Back"
            $Confirm = Read-Host "Selection"
            if ($Confirm.ToUpper() -eq "Y") { Show-RepairResults (Invoke-FrameworkRepairScan -Repair) }
        }
        "2" { Show-RepairResults (Invoke-FrameworkRepairScan) }
        "3" {
            if (-not $script:LastRepairResults) { $null = Invoke-FrameworkRepairScan }
            Show-RepairResults $script:LastRepairResults
        }
        "4" { Export-RepairReport }
        "B" { return }
        default { }
    }
}
