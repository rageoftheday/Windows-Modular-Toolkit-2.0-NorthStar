# ============================================================
# TOOL MODIFIER
# Guided editor for user module metadata only.
# Framework components are protected.
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\Core\bootstrap.ps1"

$ModulesRoot = Join-Path $Root "Modules"
$RegistryPath = Join-Path $Root "Cache\toolkit_registry.json"
$HistoryPath = Join-Path $Root "Logs\tool_modifier_history.log"

$NameMin = 3
$NameMax = 40
$CategoryMin = 1
$CategoryMax = 35
$SubcategoryMax = 35
$DescriptionMax = 250
$KeywordMin = 1
$KeywordMax = 10
$DependencyMax = 15

function New-ToolModifierNavAction {
    param([string]$Action)
    return [pscustomobject]@{ __tool_modifier_nav = $Action }
}

function Test-ToolModifierNavAction {
    param([object]$Value, [string]$Action = '')
    if ($null -eq $Value) { return $false }
    if ($Value.PSObject.Properties.Name -notcontains '__tool_modifier_nav') { return $false }
    if ([string]::IsNullOrWhiteSpace($Action)) { return $true }
    return ([string]$Value.__tool_modifier_nav -eq $Action)
}

function Write-ToolModifierHistory {
    param([string]$Message)
    $Dir = Split-Path $HistoryPath
    if (!(Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $HistoryPath -Value "[$Time] $Message"
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

function Save-ToolJson {
    param([string]$ToolJsonPath, [object]$Meta)
    $Meta | ConvertTo-Json -Depth 10 | Set-Content -Path $ToolJsonPath -Encoding UTF8
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
            category = if (Get-SafeProperty $Meta 'category' '') { [string](Get-SafeProperty $Meta 'category' '') } else { '' }
            subcategory = if (Get-SafeProperty $Meta 'subcategory' '') { [string](Get-SafeProperty $Meta 'subcategory' '') } else { '' }
            description = if (Get-SafeProperty $Meta 'description' '') { [string](Get-SafeProperty $Meta 'description' '') } else { '' }
            keywords = @(Get-SafeProperty $Meta 'keywords' @())
            dependencies = @(Get-SafeProperty $Meta 'dependencies' @())
            risk = if (Get-SafeProperty $Meta 'risk' '') { [string](Get-SafeProperty $Meta 'risk' '') } else { 'Safe' }
            requires_admin = [bool](Get-SafeProperty $Meta 'requires_admin' $false)
            supports_logs = [bool](Get-SafeProperty $Meta 'supports_logs' $false)
            supports_export = [bool](Get-SafeProperty $Meta 'supports_export' $false)
            hidden = [bool](Get-SafeProperty $Meta 'hidden' $false)
            folder = Split-Path $FolderPath -Leaf
            path = $RelPath
            full_path = $FolderPath
            tool_json = $ToolJson.FullName
            entry = if (Get-SafeProperty $Meta 'entry' '') { [string](Get-SafeProperty $Meta 'entry' '') } else { 'run.ps1' }
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
    if (!(Test-Path $CacheDir)) { New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null }
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

function Normalize-Keyword {
    param([string]$Value)
    $V = ([string]$Value).Trim().ToLower()
    $V = $V -replace '\s+', ' '
    return $V
}

function Normalize-Dependency {
    param([string]$Value)
    $V = ([string]$Value).Trim()
    $Key = ($V.ToLower() -replace '[\s_\-.]','')
    $Map = @{
        'ps'='PowerShell'; 'powershell'='PowerShell'; 'pwsh'='PowerShell';
        'activedirectory'='ActiveDirectory'; 'ad'='ActiveDirectory';
        'rsat'='RSAT'; 'remoteserveradministrationtools'='RSAT';
        'winget'='Winget'; 'windowsappinstaller'='Winget';
        'importexcel'='ImportExcel'; 'excel'='ImportExcel';
        '7zip'='7-Zip'; '7z'='7-Zip';
        'git'='Git';
        'hyperv'='Hyper-V';
        'wsl'='WSL'; 'windowssubsystemforlinux'='WSL';
        'dism'='DISM';
        'sfc'='SFC';
        'printmanagement'='PrintManagement';
        'internet'='Internet'; 'internetaccess'='Internet';
        'admin'='Administrator'; 'administrator'='Administrator'; 'administratorrights'='Administrator';
        'nuget'='NuGet';
        'pswindowsupdate'='PSWindowsUpdate';
        'carbon'='Carbon'
    }
    if ($Map.ContainsKey($Key)) { return $Map[$Key] }
    return ($V -replace '\s+', ' ')
}

function Normalize-List {
    param([array]$Values, [string]$Kind)
    $Out = @()
    foreach ($Raw in @($Values)) {
        if ($null -eq $Raw) { continue }
        foreach ($Part in @(([string]$Raw) -split ',')) {
            if ([string]::IsNullOrWhiteSpace($Part)) { continue }
            if ($Kind -eq 'Dependency') { $Clean = Normalize-Dependency $Part } else { $Clean = Normalize-Keyword $Part }
            if ([string]::IsNullOrWhiteSpace($Clean)) { continue }
            $Exists = $false
            foreach ($Existing in $Out) { if ($Existing.ToLower() -eq $Clean.ToLower()) { $Exists = $true; break } }
            if (!$Exists) { $Out += $Clean }
        }
    }
    return @($Out)
}

function Parse-NumberSelection {
    param([string]$Input, [int]$Max)
    $Selected = @()
    foreach ($Part in @($Input -split ',')) {
        $P = $Part.Trim()
        if ($P -match '^(\d+)\-(\d+)$') {
            $Start = [int]$Matches[1]
            $End = [int]$Matches[2]
            if ($Start -gt $End) { $Tmp = $Start; $Start = $End; $End = $Tmp }
            for ($i=$Start; $i -le $End; $i++) { if ($i -ge 1 -and $i -le $Max -and $Selected -notcontains $i) { $Selected += $i } }
        } elseif ($P -match '^\d+$') {
            $i = [int]$P
            if ($i -ge 1 -and $i -le $Max -and $Selected -notcontains $i) { $Selected += $i }
        }
    }
    return @($Selected)
}

function Select-UserModuleFromList {
    param([array]$Modules, [string]$Title = 'SELECT USER MODULE', [string]$BackAction = 'BackToSelector')
    while ($true) {
        Show-ToolkitHeader $Title
        if (!$Modules -or $Modules.Count -eq 0) {
            Write-Host 'No matching user modules found.'
            Write-Host ''
            Write-Host '[B] Back'
            $EmptyChoice = Read-Host 'Selection'
            if ($EmptyChoice.ToUpper() -eq 'B' -or $EmptyChoice.ToUpper() -eq 'Q') { return (New-ToolModifierNavAction $BackAction) }
            continue
        }
        Show-ToolkitModuleList $Modules
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Select module'
        if ($Choice.ToUpper() -eq 'B' -or $Choice.ToUpper() -eq 'Q') { return (New-ToolModifierNavAction $BackAction) }
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
        if ($Query.ToUpper() -eq 'B' -or $Query.ToUpper() -eq 'Q') { return (New-ToolModifierNavAction 'BackToSelector') }
        if ([string]::IsNullOrWhiteSpace($Query)) { continue }
        $Results = @(Find-UserModules -Modules $Modules -Query $Query)
        if (!$Results -or $Results.Count -eq 0) { $LastNoResult = $Query; continue }
        $Selected = Select-UserModuleFromList -Modules $Results -Title "$ActionName - RESULTS" -BackAction 'BackToSearch'
        if (Test-ToolModifierNavAction $Selected 'BackToSearch') { continue }
        if ($Selected) { return $Selected }
    }
}

function Select-UserModuleByCategory {
    param([array]$Modules, [string]$Title = 'BROWSE USER MODULES')
    while ($true) {
        $Groups = @($Modules | Group-Object category | Sort-Object Name | ForEach-Object {
            [pscustomobject]@{ Name = if ([string]::IsNullOrWhiteSpace($_.Name)) { '(Missing Category)' } else { $_.Name }; Count = $_.Count; Group = $_.Group }
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
        if ($Choice.ToUpper() -eq 'B' -or $Choice.ToUpper() -eq 'Q') { return (New-ToolModifierNavAction 'BackToSelector') }
        if ($Choice -notmatch '^\d+$') { continue }
        $Index = [int]$Choice - 1
        if ($Index -lt 0 -or $Index -ge $Groups.Count) { continue }
        $Selected = Select-UserModuleFromList -Modules (@($Groups[$Index].Group | Sort-Object name)) -Title "$Title - $($Groups[$Index].Name)" -BackAction 'BackToCategory'
        if (Test-ToolModifierNavAction $Selected 'BackToCategory') { continue }
        if ($Selected) { return $Selected }
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
            '1' {
                $Selected = Select-UserModuleByCategory -Modules $Modules -Title $Purpose
                if (Test-ToolModifierNavAction $Selected 'BackToSelector') { continue }
                if ($Selected) { return $Selected }
            }
            '2' {
                $Selected = Select-UserModuleBySearch -Modules $Modules -ActionName $Purpose
                if (Test-ToolModifierNavAction $Selected 'BackToSelector') { continue }
                if ($Selected) { return $Selected }
            }
            '3' {
                $Selected = Select-UserModuleFromList -Modules (@($Modules | Sort-Object name)) -Title "$Purpose - ALL USER MODULES" -BackAction 'BackToSelector'
                if (Test-ToolModifierNavAction $Selected 'BackToSelector') { continue }
                if ($Selected) { return $Selected }
            }
            'B' { return $null }
            'Q' { return $null }
        }
    }
}

function Get-DefaultModuleCategories {
    return @('Network Tools','Printer Tools','System Information','Windows Repair','Setup and Dependencies','Cleanup Tools','Security Tools','Disk and Storage','Boot and Recovery','Drivers and Kernel','Process and Services','Windows Features','Custom Tools')
}

function Get-ExistingModuleCategories {
    param([array]$Modules)
    return @($Modules | ForEach-Object { $_.category } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}

function Read-LimitedString {
    param([string]$Title,[string]$Label,[string]$Current,[int]$Min,[int]$Max,[bool]$AllowBlank=$false)
    while ($true) {
        Show-ToolkitHeader $Title
        Write-Host "Current ${Label}:"
        if ([string]::IsNullOrWhiteSpace($Current)) { Write-Host '(blank)' -ForegroundColor Yellow } else { Write-Host $Current -ForegroundColor Cyan }
        Write-Host ''
        Write-Host "Limit: $Min-$Max characters"
        if ($AllowBlank) { Write-Host 'Blank is allowed.' }
        Write-Host ''
        Write-Host '[B] Back'
        Write-Host ''
        $NewValue = Read-Host "New $Label"
        if ($NewValue.ToUpper() -eq 'B') { return $null }
        if ($NewValue.ToUpper() -eq 'Q') { return }
        $NewValue = $NewValue.Trim()
        if ($AllowBlank -and [string]::IsNullOrWhiteSpace($NewValue)) { return '' }
        if ($NewValue.Length -lt $Min) { Show-ToolkitStatus 'FAIL' "$Label must be at least $Min characters."; Pause-Toolkit; continue }
        if ($NewValue.Length -gt $Max) { Show-ToolkitStatus 'FAIL' "$Label must be $Max characters or fewer."; Pause-Toolkit; continue }
        return $NewValue
    }
}

function Select-ModuleCategory {
    param([string]$CurrentCategory = '', [array]$Modules = @())
    $DefaultCategories = @(Get-DefaultModuleCategories)
    $ExistingCategories = @(Get-ExistingModuleCategories -Modules $Modules)
    $AllCategories = @()
    foreach ($Category in $DefaultCategories) { if ($AllCategories -notcontains $Category) { $AllCategories += $Category } }
    foreach ($Category in $ExistingCategories) { if ($AllCategories -notcontains $Category) { $AllCategories += $Category } }
    while ($true) {
        Show-ToolkitHeader 'SELECT CATEGORY'
        if (-not [string]::IsNullOrWhiteSpace($CurrentCategory)) { Write-Host "Current Category: $CurrentCategory"; Write-Host '' }
        Write-Host "Category limit: $CategoryMin-$CategoryMax characters"
        Write-Host ''
        for ($i = 0; $i -lt $AllCategories.Count; $i++) {
            $Number = $i + 1
            $Label = $AllCategories[$i]
            if ($Label -eq $CurrentCategory) { Write-Host "[$Number] $Label (Current)" } else { Write-Host "[$Number] $Label" }
        }
        Write-Host ''
        Write-Host '[C] Create New Category'
        Write-Host '[S] Search Categories'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return $null }
        if ($Choice.ToUpper() -eq 'Q') { return }
        if ($Choice.ToUpper() -eq 'C') {
            $New = Read-LimitedString -Title 'CREATE NEW CATEGORY' -Label 'Category' -Current '' -Min $CategoryMin -Max $CategoryMax
            if ($null -ne $New) { return $New }
            continue
        }
        if ($Choice.ToUpper() -eq 'S') {
            $Query = Read-LimitedString -Title 'SEARCH CATEGORIES' -Label 'Search Term' -Current '' -Min 1 -Max 35
            if ($null -eq $Query) { continue }
            $Matches = @($AllCategories | Where-Object { $_ -like "*$Query*" })
            if (!$Matches -or $Matches.Count -eq 0) { Show-ToolkitStatus 'WARN' "No categories found."; Pause-Toolkit; continue }
            for ($i=0; $i -lt $Matches.Count; $i++) { Write-Host "[$($i+1)] $($Matches[$i])" }
            $Pick = Read-Host 'Selection'
            if ($Pick -match '^\d+$') { $Idx=[int]$Pick-1; if ($Idx -ge 0 -and $Idx -lt $Matches.Count) { return $Matches[$Idx] } }
            continue
        }
        if ($Choice -match '^\d+$') {
            $Index = [int]$Choice - 1
            if ($Index -ge 0 -and $Index -lt $AllCategories.Count) { return $AllCategories[$Index] }
        }
    }
}

function Edit-Name {
    param([object]$Module)
    $Meta = Get-Content $Module.tool_json -Raw | ConvertFrom-Json
    $NewName = Read-LimitedString -Title 'EDIT MODULE NAME' -Label 'Name' -Current ([string](Get-SafeProperty $Meta 'name' $Module.name)) -Min $NameMin -Max $NameMax
    if ($null -eq $NewName) { return }
    $OldName = [string](Get-SafeProperty $Meta 'name' $Module.name)
    $Meta | Add-Member name $NewName -MemberType NoteProperty -Force
    Save-ToolJson -ToolJsonPath $Module.tool_json -Meta $Meta
    $NewFolderName = ConvertTo-SafeFolderName $NewName
    if ($NewFolderName -ne $Module.folder) {
        $Destination = Join-Path $ModulesRoot $NewFolderName
        $i = 2
        while ((Test-Path $Destination) -and ($Destination -ne $Module.full_path)) {
            $Destination = Join-Path $ModulesRoot "$NewFolderName`_$i"
            $i++
        }
        if (!(Test-Path $Destination)) { Rename-Item -Path $Module.full_path -NewName (Split-Path $Destination -Leaf) }
    }
    Write-ToolModifierHistory "Changed Name: $OldName -> $NewName"
    Rebuild-ToolkitRegistrySilent
    Show-ToolkitStatus 'PASS' 'Module name updated.'
    Pause-Toolkit
}

function Edit-Description {
    param([object]$Module)
    $Meta = Get-Content $Module.tool_json -Raw | ConvertFrom-Json
    while ($true) {
        Show-ToolkitHeader 'EDIT DESCRIPTION'
        $Current = [string](Get-SafeProperty $Meta 'description' '')
        Write-Host "Current Description ($($Current.Length)/$DescriptionMax):"
        if ([string]::IsNullOrWhiteSpace($Current)) { Write-Host '(blank)' -ForegroundColor Yellow } else { Write-Host $Current -ForegroundColor Cyan }
        Write-Host ''
        Write-Host "Description limit: 0-$DescriptionMax characters"
        Write-Host '[B] Back'
        Write-Host ''
        $NewDescription = Read-Host 'New description'
        if ($NewDescription.ToUpper() -eq 'B') { return }
        if ($NewDescription.ToUpper() -eq 'Q') { return }
        if ($NewDescription.Length -gt $DescriptionMax) { Show-ToolkitStatus 'FAIL' "Description must be $DescriptionMax characters or fewer."; Pause-Toolkit; continue }
        $Meta | Add-Member description $NewDescription -MemberType NoteProperty -Force
        Save-ToolJson -ToolJsonPath $Module.tool_json -Meta $Meta
        Write-ToolModifierHistory "Changed Description: $($Module.name)"
        Rebuild-ToolkitRegistrySilent
        Show-ToolkitStatus 'PASS' 'Description updated.'
        Pause-Toolkit
        return
    }
}

function Edit-CategorySubcategory {
    param([object]$Module)
    $Meta = Get-Content $Module.tool_json -Raw | ConvertFrom-Json
    while ($true) {
        Show-ToolkitHeader 'EDIT CATEGORY / SUBCATEGORY'
        Write-Host "Module      : $($Module.name)"
        Write-Host "Category    : $([string](Get-SafeProperty $Meta 'category' ''))"
        Write-Host "Subcategory : $([string](Get-SafeProperty $Meta 'subcategory' ''))"
        Write-Host ''
        Write-Host '[1] Change Category'
        Write-Host '[2] Change Subcategory'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch ($Choice.ToUpper()) {
            '1' {
                $NewCategory = Select-ModuleCategory -CurrentCategory ([string](Get-SafeProperty $Meta 'category' '')) -Modules @(Get-UserModulesLive)
                if ($null -ne $NewCategory) {
                    $Meta | Add-Member category $NewCategory -MemberType NoteProperty -Force
                    Save-ToolJson -ToolJsonPath $Module.tool_json -Meta $Meta
                    Write-ToolModifierHistory "Changed Category: $($Module.name) -> $NewCategory"
                    Rebuild-ToolkitRegistrySilent
                    Show-ToolkitStatus 'PASS' 'Category updated.'
                    Pause-Toolkit
                    return
                }
            }
            '2' {
                $NewSub = Read-LimitedString -Title 'EDIT SUBCATEGORY' -Label 'Subcategory' -Current ([string](Get-SafeProperty $Meta 'subcategory' '')) -Min 0 -Max $SubcategoryMax -AllowBlank $true
                if ($null -ne $NewSub) {
                    $Meta | Add-Member subcategory $NewSub -MemberType NoteProperty -Force
                    Save-ToolJson -ToolJsonPath $Module.tool_json -Meta $Meta
                    Write-ToolModifierHistory "Changed Subcategory: $($Module.name) -> $NewSub"
                    Rebuild-ToolkitRegistrySilent
                    Show-ToolkitStatus 'PASS' 'Subcategory updated.'
                    Pause-Toolkit
                    return
                }
            }
            'B' { return }
            'Q' { return }
        }
    }
}

function Edit-Risk {
    param([object]$Module)
    $Meta = Get-Content $Module.tool_json -Raw | ConvertFrom-Json
    $Options = @('Safe','Moderate','High Impact')
    while ($true) {
        Show-ToolkitHeader 'EDIT RISK'
        $Current = [string](Get-SafeProperty $Meta 'risk' 'Safe')
        Write-Host "Current Risk: $Current"
        Write-Host ''
        for ($i=0; $i -lt $Options.Count; $i++) {
            $Label = $Options[$i]
            if ($Label -eq $Current) { Write-Host "[$($i+1)] $Label (Current)" } else { Write-Host "[$($i+1)] $Label" }
        }
        Write-Host ''
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return }
        if ($Choice.ToUpper() -eq 'Q') { return }
        if ($Choice -match '^\d+$') {
            $Idx=[int]$Choice-1
            if ($Idx -ge 0 -and $Idx -lt $Options.Count) {
                $Meta | Add-Member risk $Options[$Idx] -MemberType NoteProperty -Force
                Save-ToolJson -ToolJsonPath $Module.tool_json -Meta $Meta
                Write-ToolModifierHistory "Changed Risk: $($Module.name) -> $($Options[$Idx])"
                Rebuild-ToolkitRegistrySilent
                Show-ToolkitStatus 'PASS' 'Risk updated.'
                Pause-Toolkit
                return
            }
        }
    }
}

function Edit-BooleanField {
    param([object]$Module,[string]$Field,[string]$Title,[string]$Label)
    $Meta = Get-Content $Module.tool_json -Raw | ConvertFrom-Json
    $Current = [bool](Get-SafeProperty $Meta $Field $false)
    Show-ToolkitHeader $Title
    Write-Host "Module : $($Module.name)"
    Write-Host "$Label : $Current"
    Write-Host ''
    Write-Host '[Y] True'
    Write-Host '[N] False'
    Write-Host '[B] Back'
    Write-Host ''
    $Choice = Read-Host 'Selection'
    if ($Choice.ToUpper() -eq 'Q') { return }
    if ($Choice.ToUpper() -eq 'B') { return }
    if ($Choice.ToUpper() -eq 'Y') { $Value = $true }
    elseif ($Choice.ToUpper() -eq 'N') { $Value = $false }
    else { return }
    $Meta | Add-Member $Field $Value -MemberType NoteProperty -Force
    Save-ToolJson -ToolJsonPath $Module.tool_json -Meta $Meta
    Write-ToolModifierHistory "Changed ${Field}: $($Module.name) -> $Value"
    Rebuild-ToolkitRegistrySilent
    Show-ToolkitStatus 'PASS' "$Label updated."
    Pause-Toolkit
}

function Show-CurrentList {
    param([array]$Items)
    if (!$Items -or $Items.Count -eq 0) { Write-Host '(none)' -ForegroundColor Yellow; return }
    for ($i=0; $i -lt $Items.Count; $i++) { Write-Host "[$($i+1)] $($Items[$i])" }
}

function Manage-ListField {
    param([object]$Module,[string]$Field,[string]$Title,[int]$Minimum,[int]$Maximum,[array]$Suggested,[string]$Kind)
    $Meta = Get-Content $Module.tool_json -Raw | ConvertFrom-Json
    $Current = @(Get-SafeProperty $Meta $Field @())
    if ($Kind -eq 'Dependency') { $Current = @(Normalize-List -Values $Current -Kind 'Dependency') } else { $Current = @(Normalize-List -Values $Current -Kind 'Keyword') }
    while ($true) {
        Show-ToolkitHeader $Title
        Write-Host "Module: $($Module.name)"
        Write-Host ''
        Write-Host "Current $Title ($($Current.Count)/$Maximum)"
        Write-Host '--------------------'
        Show-CurrentList $Current
        Write-Host ''
        Write-Host '[A] Add'
        Write-Host '[R] Remove'
        Write-Host '[F] Finish'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch ($Choice.ToUpper()) {
            'A' {
                if ($Current.Count -ge $Maximum) { Show-ToolkitStatus 'FAIL' "$Title limit reached. Maximum allowed: $Maximum"; Pause-Toolkit; continue }
                while ($true) {
                    Show-ToolkitHeader "ADD $Title"
                    Write-Host "Select one or multiple numbers. Examples: 1,3,5 or 1-4"
                    Write-Host ''
                    for ($i=0; $i -lt $Suggested.Count; $i++) { Write-Host "[$($i+1)] $($Suggested[$i])" }
                    Write-Host ''
                    Write-Host '[C] Custom'
                    Write-Host '[B] Back'
                                Write-Host ''
                    $AddChoice = Read-Host 'Selection'
                    if ($AddChoice.ToUpper() -eq 'B') { break }
                    if ($AddChoice.ToUpper() -eq 'Q') { return }
                    $ToAdd = @()
                    if ($AddChoice.ToUpper() -eq 'C') {
                        Write-Host ''
                        Write-Host 'Enter values separated by commas.'
                        $Custom = Read-Host 'Custom values'
                        if ($Kind -eq 'Dependency') { $ToAdd = @(Normalize-List -Values @($Custom) -Kind 'Dependency') } else { $ToAdd = @(Normalize-List -Values @($Custom) -Kind 'Keyword') }
                    } else {
                        $Nums = @(Parse-NumberSelection -Input $AddChoice -Max $Suggested.Count)
                        foreach ($Num in $Nums) { $ToAdd += $Suggested[$Num-1] }
                        if ($Kind -eq 'Dependency') { $ToAdd = @(Normalize-List -Values $ToAdd -Kind 'Dependency') } else { $ToAdd = @(Normalize-List -Values $ToAdd -Kind 'Keyword') }
                    }
                    foreach ($Item in $ToAdd) {
                        if ($Current.Count -ge $Maximum) { break }
                        $Exists = $false
                        foreach ($Existing in $Current) { if ($Existing.ToLower() -eq $Item.ToLower()) { $Exists = $true; break } }
                        if (!$Exists) { $Current += $Item }
                    }
                    break
                }
            }
            'R' {
                if (!$Current -or $Current.Count -eq 0) { Show-ToolkitStatus 'WARN' "No $Title to remove."; Pause-Toolkit; continue }
                Show-ToolkitHeader "REMOVE $Title"
                Show-CurrentList $Current
                Write-Host ''
                Write-Host 'Select one or multiple numbers. Examples: 1,3,5 or 1-4'
                Write-Host '[A] All'
                Write-Host '[B] Back'
                        Write-Host ''
                $RemoveChoice = Read-Host 'Selection'
                if ($RemoveChoice.ToUpper() -eq 'Q') { return }
                if ($RemoveChoice.ToUpper() -eq 'B') { continue }
                if ($RemoveChoice.ToUpper() -eq 'A') { $Current = @(); continue }
                $Nums = @(Parse-NumberSelection -Input $RemoveChoice -Max $Current.Count)
                if ($Nums.Count -eq 0) { continue }
                $NewList = @()
                for ($i=0; $i -lt $Current.Count; $i++) {
                    if ($Nums -notcontains ($i+1)) { $NewList += $Current[$i] }
                }
                $Current = @($NewList)
            }
            'F' {
                if ($Current.Count -lt $Minimum) { Show-ToolkitStatus 'FAIL' "$Title requires at least $Minimum item(s)."; Pause-Toolkit; continue }
                $Meta | Add-Member $Field $Current -MemberType NoteProperty -Force
                Save-ToolJson -ToolJsonPath $Module.tool_json -Meta $Meta
                Write-ToolModifierHistory "Changed ${Field}: $($Module.name) -> $($Current -join ', ')"
                Rebuild-ToolkitRegistrySilent
                Show-ToolkitStatus 'PASS' "$Title updated."
                Pause-Toolkit
                return
            }
            'B' { return }
            'Q' { return }
        }
    }
}

function Repair-CleanUserMetadata {
    param([object]$Module)
    $Meta = Get-Content $Module.tool_json -Raw | ConvertFrom-Json
    foreach ($Field in @('author','version','estimated_time','important','module_scope','framework_protected')) {
        if ($Meta.PSObject.Properties.Name -contains $Field) { $Meta.PSObject.Properties.Remove($Field) }
    }
    if ($null -eq (Get-SafeProperty $Meta 'entry' $null)) { $Meta | Add-Member entry 'run.bat' -MemberType NoteProperty -Force }
    $Meta | Add-Member keywords @(Normalize-List -Values @(Get-SafeProperty $Meta 'keywords' @()) -Kind 'Keyword') -MemberType NoteProperty -Force
    $Meta | Add-Member dependencies @(Normalize-List -Values @(Get-SafeProperty $Meta 'dependencies' @()) -Kind 'Dependency') -MemberType NoteProperty -Force
    Save-ToolJson -ToolJsonPath $Module.tool_json -Meta $Meta
    Write-ToolModifierHistory "Cleaned Metadata: $($Module.name)"
    Rebuild-ToolkitRegistrySilent
    Show-ToolkitStatus 'PASS' 'Metadata cleaned and registry rebuilt.'
    Pause-Toolkit
}

function Show-ModuleDetails {
    param([object]$Module)
    $Meta = Get-Content $Module.tool_json -Raw | ConvertFrom-Json
    Show-ToolkitHeader 'MODULE DETAILS'
    Write-Host "Name          : $([string](Get-SafeProperty $Meta 'name' $Module.name))"
    Write-Host "Category      : $([string](Get-SafeProperty $Meta 'category' ''))"
    Write-Host "Subcategory   : $([string](Get-SafeProperty $Meta 'subcategory' ''))"
    Write-Host "Risk          : $([string](Get-SafeProperty $Meta 'risk' 'Safe'))"
    Write-Host "Requires Admin: $([bool](Get-SafeProperty $Meta 'requires_admin' $false))"
    Write-Host "Supports Logs : $([bool](Get-SafeProperty $Meta 'supports_logs' $false))"
    Write-Host "Supports Export: $([bool](Get-SafeProperty $Meta 'supports_export' $false))"
    Write-Host "Hidden        : $([bool](Get-SafeProperty $Meta 'hidden' $false))"
    Write-Host "Entry         : $([string](Get-SafeProperty $Meta 'entry' 'run.ps1'))"
    Write-Host ''
    Write-Host 'Description:'
    Write-Host ([string](Get-SafeProperty $Meta 'description' ''))
    Write-Host ''
    Write-Host 'Keywords:'
    Show-CurrentList @(Get-SafeProperty $Meta 'keywords' @())
    Write-Host ''
    Write-Host 'Dependencies:'
    Show-CurrentList @(Get-SafeProperty $Meta 'dependencies' @())
    Write-Host ''
    Write-Host '[B] Back'
    $Choice = Read-Host 'Selection'
    if ($Choice.ToUpper() -eq 'Q') { return }
}

$SuggestedKeywords = @('network','dns','printer','print','repair','cleanup','security','system','info','windows','winget','rsat','powershell','disk','driver','service','process','update','audit','report')
$SuggestedDependencies = @('PowerShell','Administrator','Winget','RSAT','ActiveDirectory','ImportExcel','7-Zip','Git','Hyper-V','WSL','DISM','SFC','PrintManagement','Internet','NuGet','PSWindowsUpdate','Carbon')

while ($true) {
    $Selected = Select-UserModule -Purpose 'TOOL MODIFIER'
    if (!$Selected) { return }
    while ($true) {
        $Refreshed = @(Get-UserModulesLive | Where-Object { $_.full_path -eq $Selected.full_path -or $_.name -eq $Selected.name })
        if ($Refreshed.Count -gt 0) { $Selected = $Refreshed[0] }
        Show-ToolkitHeader 'TOOL MODIFIER'
        Write-Host 'Guided metadata editor for user modules only.'
        Write-Host 'No raw JSON editing required.'
        Write-Host ''
        Write-Host "Selected Module: $($Selected.name)"
        Write-Host "Category       : $($Selected.category)"
        Write-Host ''
        Write-Host '[1] View Module Details'
        Write-Host '[2] Edit Name'
        Write-Host '[3] Edit Category / Subcategory'
        Write-Host '[4] Edit Description'
        Write-Host '[5] Edit Keywords'
        Write-Host '[6] Edit Dependencies'
        Write-Host '[7] Edit Risk'
        Write-Host '[8] Requires Admin'
        Write-Host '[9] Supports Logs'
        Write-Host '[10] Supports Export'
        Write-Host '[11] Hidden'
        Write-Host '[12] Clean Deprecated Metadata Fields'
        Write-Host '[S] Select Different Module'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch ($Choice.ToUpper()) {
            '1' { Show-ModuleDetails $Selected }
            '2' { Edit-Name $Selected; break }
            '3' { Edit-CategorySubcategory $Selected; break }
            '4' { Edit-Description $Selected; break }
            '5' { Manage-ListField -Module $Selected -Field 'keywords' -Title 'KEYWORDS' -Minimum $KeywordMin -Maximum $KeywordMax -Suggested $SuggestedKeywords -Kind 'Keyword'; break }
            '6' { Manage-ListField -Module $Selected -Field 'dependencies' -Title 'DEPENDENCIES' -Minimum 0 -Maximum $DependencyMax -Suggested $SuggestedDependencies -Kind 'Dependency'; break }
            '7' { Edit-Risk $Selected; break }
            '8' { Edit-BooleanField -Module $Selected -Field 'requires_admin' -Title 'REQUIRES ADMIN' -Label 'Requires Admin'; break }
            '9' { Edit-BooleanField -Module $Selected -Field 'supports_logs' -Title 'SUPPORTS LOGS' -Label 'Supports Logs'; break }
            '10' { Edit-BooleanField -Module $Selected -Field 'supports_export' -Title 'SUPPORTS EXPORT' -Label 'Supports Export'; break }
            '11' { Edit-BooleanField -Module $Selected -Field 'hidden' -Title 'HIDDEN' -Label 'Hidden'; break }
            '12' { Repair-CleanUserMetadata $Selected; break }
            'S' { break }
            'B' { return }
            'Q' { return }
        }
    }
}
