# ============================================================
# REMOVE MODULE WIZARD
# Framework-safe delete tool. User modules only.
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

$RegistryPath = Join-Path $Root "cache\toolkit_registry.json"
$HistoryPath = Join-Path $Root "logs\deleted_items_history.log"

function Get-LocalRegistry {
    if (!(Test-Path $RegistryPath)) { return @() }
    try { return @(Get-Content $RegistryPath -Raw | ConvertFrom-Json) }
    catch { return @() }
}

function Get-UserModules {
    # Delete wizard should always read the live user module folder directly.
    # This avoids stale cache/registry results after folder-split changes.
    $ModulesRoot = Join-Path $Root "modules"
    if (!(Test-Path $ModulesRoot)) { return @() }

    $Found = @()
    foreach ($ToolJson in @(Get-ChildItem -Path $ModulesRoot -Filter "tool.json" -Recurse -File -ErrorAction SilentlyContinue)) {
        try {
            $Meta = Get-Content $ToolJson.FullName -Raw | ConvertFrom-Json
        }
        catch {
            continue
        }

        $FolderPath = Split-Path $ToolJson.FullName -Parent
        $RelPath = Resolve-Path $FolderPath -Relative
        $RelPath = $RelPath.TrimStart('.\\')

        # Anything physically under Modules is user content, unless metadata explicitly says protected/framework.
        if ($Meta.module_scope -eq "Framework" -or $Meta.framework_protected -eq $true) { continue }

        $Found += [pscustomobject]@{
            name = if ($Meta.name) { [string]$Meta.name } else { Split-Path $FolderPath -Leaf }
            category = if ($Meta.category) { [string]$Meta.category } else { "Uncategorized" }
            subcategory = if ($Meta.subcategory) { [string]$Meta.subcategory } else { "" }
            description = if ($Meta.description) { [string]$Meta.description } else { "" }
            keywords = if ($Meta.keywords) { @($Meta.keywords) } else { @() }
            risk = if ($Meta.risk) { [string]$Meta.risk } else { "Unknown" }
            requires_admin = [bool]$Meta.requires_admin
            folder = Split-Path $FolderPath -Leaf
            path = $RelPath
            entry = if ($Meta.entry) { [string]$Meta.entry } else { "run.ps1" }
            module_scope = "User"
            framework_protected = $false
        }
    }

    return @($Found | Sort-Object category, name)
}

function Find-Modules {
    param(
        [array]$Modules,
        [string]$Query
    )

    $Q = ($Query -replace '^\s+|\s+$','')
    if ([string]::IsNullOrWhiteSpace($Q)) { return @() }

    $Terms = @($Q -split '\s+' | Where-Object { $_ -and $_.Trim().Length -gt 0 })

    return @(
        $Modules | Where-Object {
            $KeywordText = ""
            if ($_.keywords) { $KeywordText = ($_.keywords -join " ") }

            $Haystack = @(
                $_.name,
                $_.folder,
                $_.category,
                $_.subcategory,
                $_.description,
                $KeywordText
            ) -join " "

            # Match exact/partial full query OR all space-separated terms.
            if ($Haystack -like "*$Q*") { return $true }

            $AllTermsMatch = $true
            foreach ($Term in $Terms) {
                if ($Haystack -notlike "*$Term*") {
                    $AllTermsMatch = $false
                    break
                }
            }
            return $AllTermsMatch
        } | Sort-Object name
    )
}

function Select-ModuleFromList {
    param(
        [array]$Modules,
        [string]$Title = "SELECT MODULE"
    )

    while ($true) {
        Show-ToolkitHeader $Title

        if (!$Modules -or $Modules.Count -eq 0) {
            Write-Host "No matching user modules found."
            Write-Host ""
            Write-Host "[B] Back"
            $EmptyChoice = Read-Host "Selection"
            if ($EmptyChoice.ToUpper() -eq "B") { return $null }
            continue
        }

        Show-ToolkitModuleList $Modules
        Write-Host "[B] Back"
        Write-Host ""

        $Choice = Read-Host "Select module to delete"
        if ($Choice.ToUpper() -eq "B") { return $null }
        if ($Choice.ToUpper() -eq "Q") { return }
        if ($Choice -notmatch '^\d+$') { continue }

        $Index = [int]$Choice - 1
        if ($Index -lt 0 -or $Index -ge $Modules.Count) { continue }
        return $Modules[$Index]
    }
}

function Select-ModuleByCategory {
    param([array]$Modules)

    while ($true) {
        $Groups = @(
            $Modules |
            Group-Object category |
            Sort-Object Name |
            ForEach-Object {
                [pscustomobject]@{
                    Name = if ([string]::IsNullOrWhiteSpace($_.Name)) { "Uncategorized" } else { $_.Name }
                    Count = $_.Count
                    Group = $_.Group
                }
            }
        )

        Show-ToolkitHeader "DELETE MODULE - CATEGORIES"
        Write-Host "Choose a category to narrow the module list."
        Write-Host ""

        $i = 1
        foreach ($Group in $Groups) {
            $Icon = Get-ToolkitCategoryIcon $Group.Name
            Write-Host "[$i] $Icon $($Group.Name) ($($Group.Count))"
            $i++
        }

        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""

        $Choice = Read-Host "Selection"
        if ($Choice.ToUpper() -eq "B") { return $null }
        if ($Choice.ToUpper() -eq "Q") { return }
        if ($Choice -notmatch '^\d+$') { continue }

        $Index = [int]$Choice - 1
        if ($Index -lt 0 -or $Index -ge $Groups.Count) { continue }

        return Select-ModuleFromList -Modules @($Groups[$Index].Group | Sort-Object name) -Title "DELETE MODULE - $($Groups[$Index].Name)"
    }
}

function Select-ModuleBySearch {
    param([array]$Modules)

    $LastNoResult = $null

    while ($true) {
        Show-ToolkitHeader "DELETE MODULE - SEARCH"
        Write-Host "Search user modules by name, folder, category, description, or keywords."
        Write-Host ""
        if ($LastNoResult) {
            Write-Host "No matching user modules found for:"
            Write-Host ""
            Write-Host $LastNoResult -ForegroundColor Yellow
            Write-Host ""
            $LastNoResult = $null
        }
        Write-Host "[B] Back"
        Write-Host ""

        $Query = Read-Host "Search"
        if ($Query.ToUpper() -eq "B") { return $null }
        if ($Query.ToUpper() -eq "Q") { return $null }
        if ([string]::IsNullOrWhiteSpace($Query)) { continue }

        $Results = @(Find-Modules -Modules $Modules -Query $Query)
        $Title = "DELETE MODULE - SEARCH RESULTS"

        if (!$Results -or $Results.Count -eq 0) {
            $Suggestions = @()
            if (Get-Command Get-ToolkitSmartSuggestions -ErrorAction SilentlyContinue) {
                $Suggestions = @(Get-ToolkitSmartSuggestions -Query $Query -Registry $Modules -MaxResults 8)
            }

            if (!$Suggestions -or $Suggestions.Count -eq 0) {
                $LastNoResult = $Query
                continue
            }

            $Results = $Suggestions
            $Title = "DELETE MODULE - SEARCH SUGGESTIONS"
        }

        $Selected = Select-ModuleFromList -Modules $Results -Title $Title
        if ($Selected) { return $Selected }
    }
}

function Confirm-AndDeleteModule {
    param($Selected)

    if (!$Selected) { return }

    $ModulePath = Join-Path $Root $Selected.path

    Show-ToolkitHeader "DELETE MODULE"
    Write-Host "Module: $($Selected.name)"
    Write-Host "Folder: $($Selected.folder)"
    Write-Host "Category: $($Selected.category)"
    Write-Host "Path  : $ModulePath"
    Write-Host ""
    Write-Host "WARNING: This deletes the module folder."
    Write-Host "The framework will keep a deleted-items history entry only."
    Write-Host ""
    $Confirm = Read-Host "[Y] Delete  [N] Cancel"

    if ($Confirm.ToUpper() -ne "Y") { return }

    if ($Selected.module_scope -eq "Framework" -or $Selected.framework_protected -eq $true) {
        Show-ToolkitStatus "FAIL" "Framework tools cannot be deleted through the toolkit."
        Pause-Toolkit
        return
    }

    if (Test-Path $ModulePath) {
        Remove-Item $ModulePath -Recurse -Force
        $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        if (!(Test-Path (Split-Path $HistoryPath))) { New-Item -ItemType Directory -Path (Split-Path $HistoryPath) | Out-Null }
        Add-Content $HistoryPath "[$Time] Deleted Module: $($Selected.name) | Folder: $($Selected.folder) | Category: $($Selected.category) | Path: $($Selected.path)"
        Show-ToolkitStatus "PASS" "Module deleted."
        Show-ToolkitStatus "WARN" "Rebuild the registry to remove it from menus."
    }
    else {
        Show-ToolkitStatus "FAIL" "Module folder not found."
    }

    Pause-Toolkit
}

while ($true) {
    $Modules = Get-UserModules

    Show-ToolkitHeader "REMOVE MODULE WIZARD"
    Write-Host "This tool can only delete user modules."
    Write-Host "Framework tools are protected and will not be shown here."
    Write-Host ""
    Write-Host "User Modules Found: $($Modules.Count)"
    Write-Host ""

    if (!$Modules -or $Modules.Count -eq 0) {
        Write-Host "No user modules found."
        Write-Host ""
        Write-Host "[B] Back"
        $Choice = Read-Host "Selection"
        if ($Choice.ToUpper() -eq "B") { return }
        if ($Choice.ToUpper() -eq "Q") { return }
        continue
    }

    Write-Host "[1] Browse By Category"
    Write-Host "[2] Search Modules"
    Write-Host "[3] List All Modules"
    Write-Host "[B] Back"
    Write-Host ""

    $Choice = Read-Host "Selection"

    switch ($Choice.ToUpper()) {
        "1" { $Selected = Select-ModuleByCategory -Modules $Modules; Confirm-AndDeleteModule $Selected }
        "2" { $Selected = Select-ModuleBySearch -Modules $Modules; Confirm-AndDeleteModule $Selected }
        "3" { $Selected = Select-ModuleFromList -Modules (@($Modules | Sort-Object name)) -Title "DELETE MODULE - ALL USER MODULES"; Confirm-AndDeleteModule $Selected }
        "B" { return }
        "Q" { return }
    }
}
