# ============================================================
# CATEGORY BROWSER
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "CATEGORY BROWSER" `
    -RequiresAdmin $false `
    -ScriptBlock {

    function Convert-ToolkitBooleanLocal {
        param($Value, [bool]$Default = $false)
        if ($null -eq $Value) { return $Default }
        if ($Value -is [bool]) { return [bool]$Value }
        $Text = ([string]$Value).Trim()
        if ([string]::IsNullOrWhiteSpace($Text)) { return $Default }
        switch -Regex ($Text) {
            '^(true|yes|y|1|on)$'  { return $true }
            '^(false|no|n|0|off)$' { return $false }
            default { return $Default }
        }
    }

    function Get-LiveModuleRegistryLocal {
        $ModulesRoot = Join-Path $Root "Modules"
        if (-not (Test-Path $ModulesRoot)) { return @() }

        $Results = @()
        foreach ($FolderItem in @(Get-ChildItem -Path $ModulesRoot -Directory -ErrorAction SilentlyContinue)) {
            $JsonPath = Join-Path $FolderItem.FullName "tool.json"
            if (-not (Test-Path $JsonPath)) { continue }

            try {
                $Json = Get-Content -Path $JsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            }
            catch { continue }

            $Hidden = $false
            if ($Json.PSObject.Properties.Name -contains 'hidden') { $Hidden = Convert-ToolkitBooleanLocal $Json.hidden $false }
            if ($Hidden) { continue }

            $Name = $FolderItem.Name
            if ($Json.PSObject.Properties.Name -contains 'name' -and -not [string]::IsNullOrWhiteSpace([string]$Json.name)) { $Name = [string]$Json.name }

            $Category = "Uncategorized"
            if ($Json.PSObject.Properties.Name -contains 'category' -and -not [string]::IsNullOrWhiteSpace([string]$Json.category)) { $Category = [string]$Json.category }

            $Subcategory = ""
            if ($Json.PSObject.Properties.Name -contains 'subcategory' -and $null -ne $Json.subcategory) { $Subcategory = [string]$Json.subcategory }

            $Description = ""
            if ($Json.PSObject.Properties.Name -contains 'description' -and $null -ne $Json.description) { $Description = [string]$Json.description }

            $Risk = "Safe"
            if ($Json.PSObject.Properties.Name -contains 'risk' -and -not [string]::IsNullOrWhiteSpace([string]$Json.risk)) { $Risk = [string]$Json.risk }

            $RequiresAdmin = $false
            if ($Json.PSObject.Properties.Name -contains 'requires_admin') { $RequiresAdmin = Convert-ToolkitBooleanLocal $Json.requires_admin $false }

            $SupportsLogs = $false
            if ($Json.PSObject.Properties.Name -contains 'supports_logs') { $SupportsLogs = Convert-ToolkitBooleanLocal $Json.supports_logs $false }

            $SupportsExport = $false
            if ($Json.PSObject.Properties.Name -contains 'supports_export') { $SupportsExport = Convert-ToolkitBooleanLocal $Json.supports_export $false }

            $Entry = "run.bat"
            if ($Json.PSObject.Properties.Name -contains 'entry' -and -not [string]::IsNullOrWhiteSpace([string]$Json.entry)) { $Entry = [string]$Json.entry }

            $Keywords = @()
            if ($Json.PSObject.Properties.Name -contains 'keywords' -and $null -ne $Json.keywords) { $Keywords = @($Json.keywords) }

            $Dependencies = @()
            if ($Json.PSObject.Properties.Name -contains 'dependencies' -and $null -ne $Json.dependencies) { $Dependencies = @($Json.dependencies) }

            $Results += [PSCustomObject]@{
                name = $Name
                folder = $FolderItem.Name
                path = $FolderItem.FullName
                category = $Category
                subcategory = $Subcategory
                description = $Description
                keywords = $Keywords
                risk = $Risk
                requires_admin = $RequiresAdmin
                supports_logs = $SupportsLogs
                supports_export = $SupportsExport
                entry = $Entry
                dependencies = $Dependencies
                important = $false
                hidden = $Hidden
                module_scope = "User"
                framework_protected = $false
            }
        }
        return @($Results)
    }

    while ($true) {

        # Live scan Modules\ each time so removed/imported modules update immediately.
        $VisibleModules = @(Get-LiveModuleRegistryLocal)

        $CategoryGroups = @(
            $VisibleModules |
            Where-Object { ![string]::IsNullOrWhiteSpace($_.category) } |
            Group-Object category |
            Sort-Object Name
        )

        Show-ToolkitHeader "BROWSE MODULES"

        if (!$CategoryGroups -or $CategoryGroups.Count -eq 0) {
            Write-Host "No user modules found." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "The framework remains operational with an empty Modules folder."
            Write-Host "Add modules manually, create one with Module Tool Manager, or import the optional module pack."
            Write-Host ""
        }
        else {
            Show-ToolkitCategoryList $CategoryGroups
        }

        Write-Host "[B] Back"
        Write-Host ""

        $Selection = Read-Host "Select category"

        if ($Selection.ToUpper() -eq "B") { return }
        if ($Selection.ToUpper() -eq "Q") { return }
        if ($Selection -notmatch '^\d+$') { continue }

        $SelectedGroup = $CategoryGroups[[int]$Selection - 1]

        if (!$SelectedGroup) { continue }

        while ($true) {

            Show-ToolkitHeader $SelectedGroup.Name

            $Modules = @(
                $SelectedGroup.Group |
                Sort-Object name
            )

            Show-ToolkitModuleList $Modules

            Write-Host "[B] Back"
            Write-Host ""

            $ModuleSelection = Read-Host "Select module"

            if ($ModuleSelection.ToUpper() -eq "B") { break }
            if ($ModuleSelection.ToUpper() -eq "Q") { break }
            if ($ModuleSelection -notmatch '^\d+$') { continue }

            $SelectedModule = $Modules[[int]$ModuleSelection - 1]

            if ($SelectedModule) {
                Start-ToolkitModule $SelectedModule
            }
        }
    }
}
