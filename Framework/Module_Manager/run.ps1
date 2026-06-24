# ============================================================
# MODULE MANAGER
# User module management only. Framework components are protected.
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

$ModulesRoot = Join-Path $Root "Modules"
$RegistryPath = Join-Path $Root "Cache\toolkit_registry.json"
$DeletedHistoryPath = Join-Path $Root "Logs\deleted_items_history.log"
$ChangeHistoryPath = Join-Path $Root "Logs\module_manager_history.log"

function Write-ModuleManagerHistory {
    param([string]$Message)
    $Dir = Split-Path $ChangeHistoryPath
    if (!(Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir | Out-Null }
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $ChangeHistoryPath "[$Time] $Message"
}

function Get-SafeProperty {
    param([object]$Item, [string]$Name, [object]$Default = $null)
    if ($null -eq $Item) { return $Default }
    if ($Item.PSObject.Properties.Name -contains $Name) {
        $Value = $Item.$Name
        if ($null -ne $Value) { return $Value }
    }
    return $Default
}

function ConvertTo-SafeFolderName {
    param([string]$Name)
    $Safe = [string]$Name
    $Safe = $Safe.Trim()
    $Safe = $Safe -replace '[\\/:*?"<>|]', ''
    $Safe = $Safe -replace '\s+', '_'
    $Safe = $Safe -replace '[^A-Za-z0-9_\-.]', ''
    if ([string]::IsNullOrWhiteSpace($Safe)) { $Safe = "Custom_Module" }
    return $Safe
}

function Get-UniqueFolderPath {
    param([string]$BaseFolderName)
    $FolderName = ConvertTo-SafeFolderName $BaseFolderName
    $Path = Join-Path $ModulesRoot $FolderName
    if (!(Test-Path $Path)) { return $Path }
    $i = 2
    while ($true) {
        $Candidate = Join-Path $ModulesRoot "$FolderName`_$i"
        if (!(Test-Path $Candidate)) { return $Candidate }
        $i++
    }
}

function Save-ToolJson {
    param([string]$ToolJsonPath, [object]$Meta)
    $Meta | ConvertTo-Json -Depth 10 | Set-Content $ToolJsonPath -Encoding UTF8
}

function Get-UserModulesLive {
    if (!(Test-Path $ModulesRoot)) { return @() }
    $Found = @()
    foreach ($ToolJson in @(Get-ChildItem -Path $ModulesRoot -Filter "tool.json" -Recurse -File -ErrorAction SilentlyContinue)) {
        try { $Meta = Get-Content $ToolJson.FullName -Raw | ConvertFrom-Json }
        catch { continue }

        if ((Get-SafeProperty $Meta 'module_scope' '') -eq 'Framework' -or (Get-SafeProperty $Meta 'framework_protected' $false) -eq $true) { continue }

        $FolderPath = Split-Path $ToolJson.FullName -Parent
        $RelPath = Resolve-Path $FolderPath -Relative
        $RelPath = $RelPath.TrimStart('.\')
        $Found += [pscustomobject]@{
            name = if (Get-SafeProperty $Meta 'name' '') { [string](Get-SafeProperty $Meta 'name' '') } else { Split-Path $FolderPath -Leaf }
            category = if (Get-SafeProperty $Meta 'category' '') { [string](Get-SafeProperty $Meta 'category' '') } else { 'Uncategorized' }
            subcategory = if (Get-SafeProperty $Meta 'subcategory' '') { [string](Get-SafeProperty $Meta 'subcategory' '') } else { '' }
            description = if (Get-SafeProperty $Meta 'description' '') { [string](Get-SafeProperty $Meta 'description' '') } else { '' }
            keywords = @(Get-SafeProperty $Meta 'keywords' @())
            risk = if (Get-SafeProperty $Meta 'risk' '') { [string](Get-SafeProperty $Meta 'risk' '') } else { 'Unknown' }
            requires_admin = [bool](Get-SafeProperty $Meta 'requires_admin' $false)
            hidden = [bool](Get-SafeProperty $Meta 'hidden' $false)
            folder = Split-Path $FolderPath -Leaf
            path = $RelPath
            full_path = $FolderPath
            tool_json = $ToolJson.FullName
            entry = if (Get-SafeProperty $Meta 'entry' '') { [string](Get-SafeProperty $Meta 'entry' '') } else { 'run.ps1' }
            module_scope = 'User'
            framework_protected = $false
        }
    }
    return @($Found | Sort-Object category, name)
}

function Find-UserModules {
    param([array]$Modules, [string]$Query)
    $Q = ($Query -replace '^\s+|\s+$','')
    if ([string]::IsNullOrWhiteSpace($Q)) { return @() }
    $Terms = @($Q -split '\s+' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    return @(
        $Modules | Where-Object {
            $KeywordText = if ($_.keywords) { ($_.keywords -join ' ') } else { '' }
            $Haystack = @($_.name,$_.folder,$_.category,$_.subcategory,$_.description,$KeywordText) -join ' '
            if ($Haystack -like "*$Q*") { return $true }
            foreach ($Term in $Terms) {
                if ($Haystack -notlike "*$Term*") { return $false }
            }
            return $true
        } | Sort-Object name
    )
}

function Rebuild-ToolkitRegistrySilent {
    $FrameworkDir = Join-Path $Root 'Framework'
    $CacheDir = Join-Path $Root 'Cache'
    if (!(Test-Path $CacheDir)) { New-Item -ItemType Directory -Path $CacheDir | Out-Null }
    $Results = @()
    $ScanRoots = @(
        [pscustomobject]@{ Path = $FrameworkDir; Scope = 'Framework'; RelativeRoot = 'Framework' },
        [pscustomobject]@{ Path = $ModulesRoot; Scope = 'User'; RelativeRoot = 'Modules' }
    )
    foreach ($ScanRoot in $ScanRoots) {
        if (!(Test-Path $ScanRoot.Path)) { continue }
        foreach ($Dir in @(Get-ChildItem $ScanRoot.Path -Directory -ErrorAction SilentlyContinue)) {
            $ToolJson = Join-Path $Dir.FullName 'tool.json'
            if (!(Test-Path $ToolJson)) { continue }
            try { $Json = Get-Content $ToolJson -Raw | ConvertFrom-Json }
            catch { continue }
            if ($null -eq (Get-SafeProperty $Json 'dependencies' $null)) { $Json | Add-Member dependencies @() -MemberType NoteProperty -Force }
            if ($null -eq (Get-SafeProperty $Json 'entry' $null)) { $Json | Add-Member entry 'run.bat' -MemberType NoteProperty -Force }
            if ($ScanRoot.Scope -eq 'Framework') {
                $Json | Add-Member module_scope 'Framework' -MemberType NoteProperty -Force
                $Json | Add-Member framework_protected $true -MemberType NoteProperty -Force
                $Json | Add-Member allow_delete $false -MemberType NoteProperty -Force
                $Json | Add-Member allow_rename $false -MemberType NoteProperty -Force
                $Json | Add-Member allow_move $false -MemberType NoteProperty -Force
            } else {
                $Json | Add-Member module_scope 'User' -MemberType NoteProperty -Force
                $Json | Add-Member framework_protected $false -MemberType NoteProperty -Force
            }
            $Json | Add-Member folder $Dir.Name -MemberType NoteProperty -Force
            $Json | Add-Member path (Join-Path $ScanRoot.RelativeRoot $Dir.Name) -MemberType NoteProperty -Force
            $Results += $Json
        }
    }
    $Results | ConvertTo-Json -Depth 10 | Set-Content $RegistryPath -Encoding UTF8
}

function Select-UserModuleFromList {
    param([array]$Modules, [string]$Title = 'SELECT USER MODULE')
    while ($true) {
        Show-ToolkitHeader $Title
        if (!$Modules -or $Modules.Count -eq 0) {
            Write-Host 'No matching user modules found.'
            Write-Host ''
            Write-Host '[B] Back'
                $EmptyChoice = Read-Host 'Selection'
            if ($EmptyChoice.ToUpper() -eq 'B') { return $null }
            if ($EmptyChoice.ToUpper() -eq 'Q') { return }
            continue
        }
        Show-ToolkitModuleList $Modules
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Select module'
        if ($Choice.ToUpper() -eq 'B') { return $null }
        if ($Choice.ToUpper() -eq 'Q') { return }
        if ($Choice -notmatch '^\d+$') { continue }
        $Index = [int]$Choice - 1
        if ($Index -lt 0 -or $Index -ge $Modules.Count) { continue }
        return $Modules[$Index]
    }
}

function Select-UserModuleBySearch {
    param([array]$Modules, [string]$ActionName = 'MODULE SEARCH')
    $LastNoResult = $null
    while ($true) {
        Show-ToolkitHeader $ActionName
        if ($LastNoResult) {
            Write-Host 'No matching user modules found for:'
            Write-Host ''
            Write-Host $LastNoResult -ForegroundColor Yellow
            Write-Host ''
            $LastNoResult = $null
        }
        Write-Host '[B] Back'
        Write-Host ''
        $Query = Read-Host 'Search'
        if ($Query.ToUpper() -eq 'B') { return $null }
        if ($Query.ToUpper() -eq 'Q') { return }
        if ([string]::IsNullOrWhiteSpace($Query)) { continue }
        $Results = @(Find-UserModules -Modules $Modules -Query $Query)
        $Title = "$ActionName - RESULTS"
        if (!$Results -or $Results.Count -eq 0) {
            $Suggestions = @()
            if (Get-Command Get-ToolkitSmartSuggestions -ErrorAction SilentlyContinue) {
                $Suggestions = @(Get-ToolkitSmartSuggestions -Query $Query -Registry $Modules -MaxResults 8)
            }
            if (!$Suggestions -or $Suggestions.Count -eq 0) { $LastNoResult = $Query; continue }
            $Results = $Suggestions
            $Title = "$ActionName - SUGGESTIONS"
        }
        $Selected = Select-UserModuleFromList -Modules $Results -Title $Title
        if ($Selected) { return $Selected }
    }
}

function Select-UserModuleByCategory {
    param([array]$Modules, [string]$Title = 'BROWSE USER MODULES')
    while ($true) {
        $Groups = @($Modules | Group-Object category | Sort-Object Name | ForEach-Object {
            [pscustomobject]@{ Name = if ([string]::IsNullOrWhiteSpace($_.Name)) { 'Uncategorized' } else { $_.Name }; Count = $_.Count; Group = $_.Group }
        })
        Show-ToolkitHeader $Title
        Write-Host 'Choose a category to narrow the module list.'
        Write-Host ''
        $i = 1
        foreach ($Group in $Groups) {
            $Icon = Get-ToolkitCategoryIcon $Group.Name
            Write-Host "[$i] $Icon $($Group.Name) ($($Group.Count))"
            $i++
        }
        Write-Host ''
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return $null }
        if ($Choice.ToUpper() -eq 'Q') { return }
        if ($Choice -notmatch '^\d+$') { continue }
        $Index = [int]$Choice - 1
        if ($Index -lt 0 -or $Index -ge $Groups.Count) { continue }
        return Select-UserModuleFromList -Modules (@($Groups[$Index].Group | Sort-Object name)) -Title "$Title - $($Groups[$Index].Name)"
    }
}

function Select-UserModule {
    param([string]$Purpose = 'SELECT USER MODULE')
    $Modules = @(Get-UserModulesLive)
    if (!$Modules -or $Modules.Count -eq 0) {
        Show-ToolkitHeader $Purpose
        Write-Host 'No user modules found.'
        Write-Host ''
        Write-Host '[B] Back'
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'Q') { return }
        return $null
    }
    while ($true) {
        Show-ToolkitHeader $Purpose
        Write-Host "User Modules Found: $($Modules.Count)"
        Write-Host ''
        Write-Host '[1] Browse By Category'
        Write-Host '[2] Search Modules'
        Write-Host '[3] List All Modules'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch ($Choice.ToUpper()) {
            '1' { return Select-UserModuleByCategory -Modules $Modules -Title $Purpose }
            '2' { return Select-UserModuleBySearch -Modules $Modules -ActionName $Purpose }
            '3' { return Select-UserModuleFromList -Modules (@($Modules | Sort-Object name)) -Title "$Purpose - ALL USER MODULES" }
            'B' { return $null }
            'Q' { exit }
        }
    }
}

function Rename-UserModule {
    $Selected = Select-UserModule -Purpose 'RENAME MODULE'
    if (!$Selected) { return }
    Show-ToolkitHeader 'RENAME MODULE'
    Write-Host "Current Name  : $($Selected.name)"
    Write-Host "Current Folder: $($Selected.folder)"
    Write-Host ''
    Write-Host '[B] Back'
    Write-Host ''
    $NewName = Read-Host 'New module name'
    if ($NewName.ToUpper() -eq 'B') { return }
    if ($NewName.ToUpper() -eq 'Q') { return }
    if ([string]::IsNullOrWhiteSpace($NewName)) { return }
    $NewFolderPath = Get-UniqueFolderPath $NewName
    $Meta = Get-Content $Selected.tool_json -Raw | ConvertFrom-Json
    $OldName = [string](Get-SafeProperty $Meta 'name' $Selected.name)
    $Meta | Add-Member name $NewName -MemberType NoteProperty -Force
    Save-ToolJson -ToolJsonPath $Selected.tool_json -Meta $Meta
    Rename-Item -Path $Selected.full_path -NewName (Split-Path $NewFolderPath -Leaf)
    Write-ModuleManagerHistory "Renamed Module: $OldName -> $NewName"
    Rebuild-ToolkitRegistrySilent
    Show-ToolkitStatus 'PASS' 'Module renamed and registry rebuilt.'
    Pause-Toolkit
}


function Get-DefaultModuleCategories {
    return @(
        'Network Tools',
        'Printer Tools',
        'System Information',
        'Windows Repair',
        'Setup and Dependencies',
        'Cleanup Tools',
        'Security Tools',
        'Disk and Storage',
        'Boot and Recovery',
        'Drivers and Kernel',
        'Process and Services',
        'Windows Features',
        'Custom Tools'
    )
}

function Get-ExistingModuleCategories {
    param([array]$Modules)
    return @($Modules | ForEach-Object { $_.category } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}

function Select-ModuleCategory {
    param(
        [string]$CurrentCategory = '',
        [array]$Modules = @()
    )

    $DefaultCategories = @(Get-DefaultModuleCategories)
    $ExistingCategories = @(Get-ExistingModuleCategories -Modules $Modules)
    $AllCategories = @()

    foreach ($Category in $DefaultCategories) {
        if ($AllCategories -notcontains $Category) { $AllCategories += $Category }
    }
    foreach ($Category in $ExistingCategories) {
        if ($AllCategories -notcontains $Category) { $AllCategories += $Category }
    }

    while ($true) {
        Show-ToolkitHeader 'SELECT DESTINATION CATEGORY'
        if (-not [string]::IsNullOrWhiteSpace($CurrentCategory)) {
            Write-Host "Current Category: $CurrentCategory"
            Write-Host ''
        }

        if ($AllCategories.Count -gt 0) {
            Write-Host 'Available Categories'
            Write-Host '--------------------'
            for ($i = 0; $i -lt $AllCategories.Count; $i++) {
                $Number = $i + 1
                $Label = $AllCategories[$i]
                if ($Label -eq $CurrentCategory) {
                    Write-Host "[$Number] $Label (Current)"
                } else {
                    Write-Host "[$Number] $Label"
                }
            }
            Write-Host ''
        }

        Write-Host '[C] Create New Category'
        Write-Host '[S] Search Categories'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return $null }
        if ($Choice.ToUpper() -eq 'Q') { return }

        if ($Choice.ToUpper() -eq 'C') {
            Show-ToolkitHeader 'CREATE NEW CATEGORY'
            Write-Host 'Any category name is allowed.'
            Write-Host ''
            Write-Host '[B] Back'
                Write-Host ''
            $NewCategory = Read-Host 'New category name'
            if ($NewCategory.ToUpper() -eq 'B') { continue }
            if ($NewCategory.ToUpper() -eq 'Q') { return }
            if ([string]::IsNullOrWhiteSpace($NewCategory)) { continue }
            return $NewCategory.Trim()
        }

        if ($Choice.ToUpper() -eq 'S') {
            Show-ToolkitHeader 'SEARCH CATEGORIES'
            Write-Host '[B] Back'
                Write-Host ''
            $Query = Read-Host 'Search category'
            if ($Query.ToUpper() -eq 'B') { continue }
            if ($Query.ToUpper() -eq 'Q') { return }
            if ([string]::IsNullOrWhiteSpace($Query)) { continue }
            $Matches = @($AllCategories | Where-Object { $_ -like "*$Query*" })
            if (!$Matches -or $Matches.Count -eq 0) {
                Show-ToolkitHeader 'SEARCH CATEGORIES'
                Write-Host "No categories found for:"
                Write-Host ''
                Write-Host $Query -ForegroundColor Yellow
                Write-Host ''
                Write-Host '[C] Create New Category With This Name'
                Write-Host '[B] Back'
                        Write-Host ''
                $NoMatchChoice = Read-Host 'Selection'
                if ($NoMatchChoice.ToUpper() -eq 'C') { return $Query.Trim() }
                if ($NoMatchChoice.ToUpper() -eq 'Q') { return }
                continue
            }
            while ($true) {
                Show-ToolkitHeader 'CATEGORY SEARCH RESULTS'
                for ($i = 0; $i -lt $Matches.Count; $i++) {
                    $Number = $i + 1
                    Write-Host "[$Number] $($Matches[$i])"
                }
                Write-Host ''
                Write-Host '[B] Back'
                        Write-Host ''
                $MatchChoice = Read-Host 'Selection'
                if ($MatchChoice.ToUpper() -eq 'B') { break }
                if ($MatchChoice.ToUpper() -eq 'Q') { return }
                if ($MatchChoice -notmatch '^\d+$') { continue }
                $Index = [int]$MatchChoice - 1
                if ($Index -lt 0 -or $Index -ge $Matches.Count) { continue }
                return $Matches[$Index]
            }
            continue
        }

        if ($Choice -match '^\d+$') {
            $Index = [int]$Choice - 1
            if ($Index -ge 0 -and $Index -lt $AllCategories.Count) {
                return $AllCategories[$Index]
            }
        }
    }
}

function Move-UserModule {
    $Selected = Select-UserModule -Purpose 'MOVE MODULE'
    if (!$Selected) { return }
    $AllModules = @(Get-UserModulesLive)
    $DestinationCategory = Select-ModuleCategory -CurrentCategory $Selected.category -Modules $AllModules
    if ([string]::IsNullOrWhiteSpace($DestinationCategory)) { return }

    Show-ToolkitHeader 'MOVE MODULE'
    Write-Host "Module          : $($Selected.name)"
    Write-Host "Current Category: $($Selected.category)"
    Write-Host "New Category    : $DestinationCategory"
    Write-Host ''
    Write-Host '[Y] Move Module'
    Write-Host '[N] Cancel'
    Write-Host '[B] Back'
    Write-Host ''
    $Confirm = Read-Host 'Selection'
    if ($Confirm.ToUpper() -eq 'Q') { return }
    if ($Confirm.ToUpper() -ne 'Y') { return }

    $Meta = Get-Content $Selected.tool_json -Raw | ConvertFrom-Json
    $OldCategory = [string](Get-SafeProperty $Meta 'category' $Selected.category)
    $Meta | Add-Member category $DestinationCategory.Trim() -MemberType NoteProperty -Force
    Save-ToolJson -ToolJsonPath $Selected.tool_json -Meta $Meta
    Write-ModuleManagerHistory "Moved Module: $($Selected.name) | $OldCategory -> $DestinationCategory"
    Rebuild-ToolkitRegistrySilent
    Show-ToolkitStatus 'PASS' 'Module moved and registry rebuilt.'
    Pause-Toolkit
}

function Hide-UnhideUserModule {
    $Selected = Select-UserModule -Purpose 'HIDE / UNHIDE MODULE'
    if (!$Selected) { return }
    $Meta = Get-Content $Selected.tool_json -Raw | ConvertFrom-Json
    $CurrentlyHidden = [bool](Get-SafeProperty $Meta 'hidden' $false)
    Show-ToolkitHeader 'HIDE / UNHIDE MODULE'
    Write-Host "Module : $($Selected.name)"
    Write-Host "Hidden : $CurrentlyHidden"
    Write-Host ''
    if ($CurrentlyHidden) { Write-Host '[Y] Unhide module' } else { Write-Host '[Y] Hide module' }
    Write-Host '[N] Cancel'
    Write-Host ''
    $Confirm = Read-Host 'Selection'
    if ($Confirm.ToUpper() -ne 'Y') { return }
    $Meta | Add-Member hidden (-not $CurrentlyHidden) -MemberType NoteProperty -Force
    Save-ToolJson -ToolJsonPath $Selected.tool_json -Meta $Meta
    Write-ModuleManagerHistory "Updated Hidden State: $($Selected.name) | $CurrentlyHidden -> $(-not $CurrentlyHidden)"
    Rebuild-ToolkitRegistrySilent
    Show-ToolkitStatus 'PASS' 'Module visibility updated and registry rebuilt.'
    Pause-Toolkit
}

function Clone-UserModule {
    $Selected = Select-UserModule -Purpose 'CLONE MODULE'
    if (!$Selected) { return }
    Show-ToolkitHeader 'CLONE MODULE'
    Write-Host "Source Module: $($Selected.name)"
    Write-Host ''
    Write-Host '[B] Back'
    Write-Host ''
    $NewName = Read-Host 'New module name'
    if ($NewName.ToUpper() -eq 'B') { return }
    if ($NewName.ToUpper() -eq 'Q') { return }
    if ([string]::IsNullOrWhiteSpace($NewName)) { return }
    $NewFolderPath = Get-UniqueFolderPath $NewName
    Copy-Item -Path $Selected.full_path -Destination $NewFolderPath -Recurse -Force
    $NewToolJson = Join-Path $NewFolderPath 'tool.json'
    if (Test-Path $NewToolJson) {
        $Meta = Get-Content $NewToolJson -Raw | ConvertFrom-Json
        foreach ($Field in @('author','version','estimated_time','important','module_scope','framework_protected','allow_delete','allow_rename','allow_move','framework_priority','framework_category')) {
            if ($Meta.PSObject.Properties.Name -contains $Field) { $Meta.PSObject.Properties.Remove($Field) }
        }
        $Meta | Add-Member name $NewName -MemberType NoteProperty -Force
        $Meta | Add-Member hidden $false -MemberType NoteProperty -Force
        if ($null -eq (Get-SafeProperty $Meta 'entry' $null)) { $Meta | Add-Member entry 'run.bat' -MemberType NoteProperty -Force }
        Save-ToolJson -ToolJsonPath $NewToolJson -Meta $Meta
    }
    Write-ModuleManagerHistory "Cloned Module: $($Selected.name) -> $NewName"
    Rebuild-ToolkitRegistrySilent
    Show-ToolkitStatus 'PASS' 'Module cloned and registry rebuilt.'
    Pause-Toolkit
}

function Delete-UserModule {
    $Selected = Select-UserModule -Purpose 'DELETE MODULE'
    if (!$Selected) { return }
    Show-ToolkitHeader 'DELETE MODULE'
    Write-Host "Module  : $($Selected.name)"
    Write-Host "Folder  : $($Selected.folder)"
    Write-Host "Category: $($Selected.category)"
    Write-Host "Path    : $($Selected.full_path)"
    Write-Host ''
    Write-Host 'WARNING: This deletes the module folder.' -ForegroundColor Yellow
    Write-Host 'The framework keeps a deleted-items history entry only.'
    Write-Host ''
    $Confirm = Read-Host '[Y] Delete  [N] Cancel'
    if ($Confirm.ToUpper() -ne 'Y') { return }
    if ((Get-SafeProperty $Selected 'module_scope' '') -eq 'Framework' -or (Get-SafeProperty $Selected 'framework_protected' $false) -eq $true) {
        Show-ToolkitStatus 'FAIL' 'Framework tools cannot be deleted through the toolkit.'
        Pause-Toolkit
        return
    }
    if (Test-Path $Selected.full_path) {
        Remove-Item $Selected.full_path -Recurse -Force
        $Time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $Dir = Split-Path $DeletedHistoryPath
        if (!(Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir | Out-Null }
        Add-Content $DeletedHistoryPath "[$Time] Deleted Module: $($Selected.name) | Folder: $($Selected.folder) | Category: $($Selected.category) | Path: $($Selected.path)"
        Write-ModuleManagerHistory "Deleted Module: $($Selected.name) | Folder: $($Selected.folder)"
        Rebuild-ToolkitRegistrySilent
        Show-ToolkitStatus 'PASS' 'Module deleted and registry rebuilt.'
    } else {
        Show-ToolkitStatus 'FAIL' 'Module folder not found.'
    }
    Pause-Toolkit
}

function Show-ModuleSummary {
    $Modules = @(Get-UserModulesLive)
    Show-ToolkitHeader 'MODULE MANAGER - SUMMARY'
    Write-Host "User Modules    : $($Modules.Count)"
    $Categories = @($Modules | ForEach-Object { $_.category } | Where-Object { $_ } | Sort-Object -Unique)
    Write-Host "User Categories : $($Categories.Count)"
    Write-Host ''
    if ($Categories.Count -gt 0) {
        Write-Host 'Categories:'
        foreach ($Category in $Categories) { Write-Host " - $Category" }
    }
    Write-Host ''
    Write-Host '[B] Back'
    $Choice = Read-Host 'Selection'
    if ($Choice.ToUpper() -eq 'Q') { return }
}

while ($true) {
    Show-ToolkitHeader 'MODULE MANAGER'
    Write-Host 'Manage user modules only. Framework components are protected.'
    Write-Host ''
    Write-Host '[1] Rename Module'
    Write-Host '[2] Move Module To Category'
    Write-Host '[3] Hide / Unhide Module'
    Write-Host '[4] Clone Module'
    Write-Host '[5] Delete Module'
    Write-Host '[6] Module Summary'
    Write-Host '[B] Back'
    Write-Host ''
    $Choice = Read-Host 'Selection'
    switch ($Choice.ToUpper()) {
        '1' { Rename-UserModule }
        '2' { Move-UserModule }
        '3' { Hide-UnhideUserModule }
        '4' { Clone-UserModule }
        '5' { Delete-UserModule }
        '6' { Show-ModuleSummary }
        'B' { return }
        'Q' { exit }
    }
}
