$ErrorActionPreference = "Continue"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ModulesPath = Join-Path $Root "Modules"
$FrameworkPath = Join-Path $Root "Framework"
$CachePath = Join-Path $Root "Cache"
$ConfigPath = Join-Path $Root "Config"
$LogsPath = Join-Path $Root "Logs"
$BackupPath = Join-Path $Root "Backups"
$HistoryPath = Join-Path $LogsPath "category_history.json"
$CategoryRecordsPath = Join-Path $ConfigPath "category_records.json"
$DebugLogPath = Join-Path $LogsPath "category_manager_debug.log"

$BlockedCategoryNames = @("Uncategorized")
$ReservedFrameworkCategories = @(
    "Toolkit Management",
    "Toolkit Operations",
    "Validation & Health",
    "Backup & Recovery",
    "Compatibility & Requirements",
    "Builders",
    "Configuration",
    "Import & Export",
    "Audit & Reporting",
    "Support & Documentation",
    "Development & Testing"
)

function Ensure-CategoryFolders {
    foreach ($Path in @($CachePath, $ConfigPath, $LogsPath, $BackupPath)) {
        if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    }
    if (!(Test-Path $CategoryRecordsPath)) { @() | ConvertTo-Json | Set-Content -Path $CategoryRecordsPath -Encoding UTF8 }
}

function Write-CategoryDebug {
    param([string]$Message)
    try {
        Ensure-CategoryFolders
        $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        Add-Content -Path $DebugLogPath -Value "$Stamp | $Message" -Encoding UTF8
    } catch {}
}

function Show-CategoryHeader {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "============================================================"
    Write-Host (" " + $Title)
    Write-Host "============================================================"
    Write-Host ""
}

function Read-CategoryInput {
    param([string]$Prompt = "Selection")
    $Value = Read-Host $Prompt
    if ($null -eq $Value) { return "" }
    return $Value.Trim()
}

function Wait-CategoryBack {
    Write-Host ""
    Write-Host "[B] Back"
    do { $Choice = (Read-Host "Selection").Trim().ToUpper() } until ($Choice -eq "B")
}

function Normalize-CategoryName {
    param([string]$Name)
    if ($null -eq $Name) { return "" }
    return (($Name -replace '\s+', ' ').Trim())
}

function ConvertTo-CategoryText {
    param($Value)

    $Parts = New-Object System.Collections.Generic.List[string]

    function Add-CategoryTextPart {
        param($Item)
        if ($null -eq $Item) { return }
        if ($Item -is [System.Array]) {
            foreach ($SubItem in @($Item)) { Add-CategoryTextPart $SubItem }
            return
        }
        if ($Item -is [pscustomobject]) {
            if ($Item.PSObject.Properties.Name -contains "name") { Add-CategoryTextPart $Item.name; return }
            $Parts.Add((($Item | ConvertTo-Json -Compress -Depth 6).Trim())) | Out-Null
            return
        }
        $Text = ([string]$Item).Trim().TrimStart(',').Trim()
        if (![string]::IsNullOrWhiteSpace($Text)) { $Parts.Add($Text) | Out-Null }
    }

    Add-CategoryTextPart $Value
    return (($Parts.ToArray() | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ", ")
}

function Get-JsonFile {
    param([string]$Path)
    try {
        if (!(Test-Path $Path)) { return $null }
        $Raw = Get-Content -Path $Path -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
        return $Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-CategoryDebug "Get-JsonFile failed path=$Path error=$($_.Exception.Message)"
        return $null
    }
}

function Save-JsonFile {
    param([string]$Path, [object]$Data)
    try {
        $Data | ConvertTo-Json -Depth 30 | Set-Content -Path $Path -Encoding UTF8
        Write-CategoryDebug "Saved JSON path=$Path"
    } catch {
        Write-CategoryDebug "Save-JsonFile failed path=$Path error=$($_.Exception.Message)"
    }
}

function Test-CategoryNameValid {
    param([string]$Name)
    $Clean = Normalize-CategoryName $Name
    if ([string]::IsNullOrWhiteSpace($Clean)) { return "Category name cannot be blank." }
    if ($Clean.Length -lt 1 -or $Clean.Length -gt 35) { return "Category name must be 1-35 characters." }
    if ($BlockedCategoryNames -contains $Clean) { return "Uncategorized is not allowed. Category is required." }
    if ($Clean -match '[\\/:*?"<>|]') { return "Category name contains invalid path characters." }
    return $null
}

function Get-ModuleRecords {
    $Records = @()
    if (!(Test-Path $ModulesPath)) { return @() }
    foreach ($Folder in @(Get-ChildItem -Path $ModulesPath -Directory -ErrorAction SilentlyContinue)) {
        $JsonPath = Join-Path $Folder.FullName "tool.json"
        $Tool = Get-JsonFile $JsonPath
        if ($Tool) {
            $Records += [PSCustomObject]@{
                Name = [string]$Tool.name
                Category = Normalize-CategoryName ([string]$Tool.category)
                Subcategory = Normalize-CategoryName ([string]$Tool.subcategory)
                Hidden = [bool]($Tool.hidden -eq $true)
                Folder = $Folder.Name
                FolderPath = $Folder.FullName
                JsonPath = $JsonPath
                Data = $Tool
            }
        }
    }
    return @($Records | Sort-Object Category, Name)
}

function Test-CategoryUsedByModule {
    param([string]$Name)
    $Clean = Normalize-CategoryName $Name
    if ([string]::IsNullOrWhiteSpace($Clean)) { return $false }
    return (@(Get-ModuleRecords | Where-Object { $_.Category.ToLower() -eq $Clean.ToLower() }).Count -gt 0)
}

function Get-FrameworkCategoryRecords {
    $Records = @()
    if (!(Test-Path $FrameworkPath)) { return @() }
    foreach ($Folder in @(Get-ChildItem -Path $FrameworkPath -Directory -ErrorAction SilentlyContinue)) {
        $JsonPath = Join-Path $Folder.FullName "tool.json"
        $Tool = Get-JsonFile $JsonPath
        if ($Tool) {
            $Category = Normalize-CategoryName ([string]$Tool.category)
            if ([string]::IsNullOrWhiteSpace($Category)) { $Category = "Toolkit Management" }
            $Records += [PSCustomObject]@{ Name = [string]$Tool.name; Category = $Category; Folder = $Folder.Name }
        }
    }
    return @($Records | Sort-Object Category, Name)
}

function Get-CategoryRecords {
    Ensure-CategoryFolders
    $Records = @()
    $RawData = Get-JsonFile $CategoryRecordsPath
    if ($null -eq $RawData) { return @() }
    foreach ($Item in @($RawData)) {
        $Name = ""
        $Created = ""
        $Source = "manual"
        if ($Item -is [string]) { $Name = $Item }
        elseif ($Item.PSObject.Properties.Name -contains "name") {
            $Name = [string]$Item.name
            if ($Item.PSObject.Properties.Name -contains "created") { $Created = [string]$Item.created }
            if ($Item.PSObject.Properties.Name -contains "source") { $Source = [string]$Item.source }
        }
        $Name = Normalize-CategoryName $Name
        if (![string]::IsNullOrWhiteSpace($Name) -and !($BlockedCategoryNames -contains $Name)) {
            if ([string]::IsNullOrWhiteSpace($Created)) { $Created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
            $Records += [PSCustomObject]@{ name = $Name; created = $Created; source = $Source }
        }
    }
    $Unique = @()
    foreach ($Record in @($Records | Sort-Object name)) {
        if (@($Unique | Where-Object { $_.name.ToLower() -eq $Record.name.ToLower() }).Count -eq 0) { $Unique += $Record }
    }
    Write-CategoryDebug "Get-CategoryRecords count=$($Unique.Count) names=$(($Unique | ForEach-Object {$_.name}) -join '; ')"
    return @($Unique)
}

function Save-CategoryRecords {
    param([object[]]$Records)
    Ensure-CategoryFolders
    $Clean = @()
    foreach ($Record in @($Records)) {
        $Name = ""
        $Created = ""
        $Source = "manual"
        if ($Record -is [string]) { $Name = $Record }
        elseif ($Record.PSObject.Properties.Name -contains "name") {
            $Name = [string]$Record.name
            if ($Record.PSObject.Properties.Name -contains "created") { $Created = [string]$Record.created }
            if ($Record.PSObject.Properties.Name -contains "source") { $Source = [string]$Record.source }
        }
        $Name = Normalize-CategoryName $Name
        if ([string]::IsNullOrWhiteSpace($Name)) { continue }
        if ($BlockedCategoryNames -contains $Name) { continue }
        if (@($Clean | Where-Object { $_.name.ToLower() -eq $Name.ToLower() }).Count -gt 0) { continue }
        if ([string]::IsNullOrWhiteSpace($Created)) { $Created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
        if ([string]::IsNullOrWhiteSpace($Source)) { $Source = "manual" }
        $Clean += [PSCustomObject]@{ name = $Name; created = $Created; source = $Source }
    }
    Save-JsonFile -Path $CategoryRecordsPath -Data @($Clean | Sort-Object name)
    Write-CategoryDebug "Save-CategoryRecords count=$($Clean.Count) names=$(($Clean | ForEach-Object {$_.name}) -join '; ')"
}

function Add-CategoryRecord {
    param([string]$Name)
    $Clean = Normalize-CategoryName $Name
    if ([string]::IsNullOrWhiteSpace($Clean)) { return }

    # Category records are for empty/manual categories only.
    # Categories already used by modules are discovered from tool.json and do not need duplicate records.
    if (Test-CategoryUsedByModule -Name $Clean) {
        Write-CategoryDebug "Add-CategoryRecord skipped=$Clean reason=already_used_by_module"
        return
    }

    $Records = @(Get-CategoryRecords)
    if (@($Records | Where-Object { $_.name.ToLower() -eq $Clean.ToLower() }).Count -eq 0) {
        $Records += [PSCustomObject]@{ name = $Clean; created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"); source = "manual" }
        Save-CategoryRecords -Records $Records
        Write-CategoryDebug "Add-CategoryRecord added=$Clean"
    } else { Write-CategoryDebug "Add-CategoryRecord existed=$Clean" }
}

function Remove-CategoryRecord {
    param([string]$Name)
    $Clean = Normalize-CategoryName $Name
    $Before = @(Get-CategoryRecords)
    $After = @($Before | Where-Object { $_.name.ToLower() -ne $Clean.ToLower() })
    Save-CategoryRecords -Records $After
    Write-CategoryDebug "Remove-CategoryRecord name=$Clean before=$($Before.Count) after=$($After.Count) remaining=$(($After | ForEach-Object {$_.name}) -join '; ')"
}

function Rename-CategoryRecord {
    param([string]$OldName, [string]$NewName)
    $Old = Normalize-CategoryName $OldName
    $New = Normalize-CategoryName $NewName
    $Records = @(Get-CategoryRecords | Where-Object { $_.name.ToLower() -ne $Old.ToLower() -and $_.name.ToLower() -ne $New.ToLower() })
    $Records += [PSCustomObject]@{ name = $New; created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"); source = "manual" }
    Save-CategoryRecords -Records $Records
    Write-CategoryDebug "Rename-CategoryRecord old=$Old new=$New"
}

function Get-UserCategories {
    $Modules = @(Get-ModuleRecords)
    $RecordNames = @(Get-CategoryRecords | ForEach-Object { Normalize-CategoryName ([string]$_.name) })
    $ModuleNames = @($Modules | Where-Object { ![string]::IsNullOrWhiteSpace($_.Category) } | ForEach-Object { Normalize-CategoryName ([string]$_.Category) })
    $AllNames = @($ModuleNames + $RecordNames | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $Categories = @()
    foreach ($Name in $AllNames) {
        $Group = @($Modules | Where-Object { (Normalize-CategoryName $_.Category).ToLower() -eq $Name.ToLower() })
        $HasRecord = @($RecordNames | Where-Object { $_.ToLower() -eq $Name.ToLower() }).Count -gt 0
        $Categories += [PSCustomObject]@{
            Name = $Name
            Count = $Group.Count
            Group = $Group
            IsPlaceholder = ($Group.Count -eq 0)
            HasRecord = $HasRecord
        }
    }
    Write-CategoryDebug "Get-UserCategories count=$($Categories.Count) names=$(($Categories | ForEach-Object {$_.Name + '(' + $_.Count + ')'}) -join '; ')"
    return @($Categories | Sort-Object Name)
}

function Add-CategoryHistory {
    param([string]$Action, [string]$Category, [string]$Target = "", [int]$ModuleCount = 0, [string]$Reason = "")
    Ensure-CategoryFolders
    $History = @()
    $RawHistory = Get-JsonFile $HistoryPath
    if ($RawHistory) { $History = @($RawHistory) }
    $Entry = [PSCustomObject]@{
        date = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        action = (ConvertTo-CategoryText $Action)
        category = (ConvertTo-CategoryText $Category)
        target = (ConvertTo-CategoryText $Target)
        modules_affected = [int]$ModuleCount
        reason = (ConvertTo-CategoryText $Reason)
    }
    $History += $Entry
    Save-JsonFile -Path $HistoryPath -Data @($History)
    Write-CategoryDebug "History action=$($Entry.action) category=$($Entry.category) target=$($Entry.target) modules=$($Entry.modules_affected)"
}

function New-CategoryBackup {
    param([string]$Reason)
    Ensure-CategoryFolders
    $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $SafeReason = ($Reason -replace '[^A-Za-z0-9_-]', '_')
    $Dest = Join-Path $BackupPath "category_${SafeReason}_$Stamp"
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    if (Test-Path $ModulesPath) { Copy-Item -Path (Join-Path $ModulesPath "*") -Destination $Dest -Recurse -Force -ErrorAction SilentlyContinue }
    Write-CategoryDebug "Backup created reason=$Reason path=$Dest"
    return $Dest
}

function Rebuild-ToolkitRegistryFromDisk {
    Ensure-CategoryFolders
    $Items = @()
    foreach ($Base in @("Framework", "Modules")) {
        $BasePath = Join-Path $Root $Base
        if (!(Test-Path $BasePath)) { continue }
        foreach ($Folder in @(Get-ChildItem -Path $BasePath -Directory -ErrorAction SilentlyContinue)) {
            $JsonPath = Join-Path $Folder.FullName "tool.json"
            $Tool = Get-JsonFile $JsonPath
            if ($Tool) {
                $Obj = $Tool | ConvertTo-Json -Depth 30 | ConvertFrom-Json
                if ($Base -eq "Framework") {
                    if (-not ($Obj.PSObject.Properties.Name -contains "module_scope")) { $Obj | Add-Member -NotePropertyName "module_scope" -NotePropertyValue "Framework" }
                    if (-not ($Obj.PSObject.Properties.Name -contains "framework_protected")) { $Obj | Add-Member -NotePropertyName "framework_protected" -NotePropertyValue $true }
                }
                $RelPath = "$Base/$($Folder.Name)"
                if ($Obj.PSObject.Properties.Name -contains "folder") { $Obj.folder = $Folder.Name } else { $Obj | Add-Member -NotePropertyName "folder" -NotePropertyValue $Folder.Name }
                if ($Obj.PSObject.Properties.Name -contains "path") { $Obj.path = $RelPath } else { $Obj | Add-Member -NotePropertyName "path" -NotePropertyValue $RelPath }
                $Items += $Obj
            }
        }
    }
    Save-JsonFile -Path (Join-Path $CachePath "toolkit_registry.json") -Data @($Items | Sort-Object @{Expression={ if ($_.module_scope -eq "Framework") { 0 } else { 1 } }}, category, name)
    Write-CategoryDebug "Registry rebuilt items=$($Items.Count)"
}

function Set-ModuleCategory {
    param([object]$Record, [string]$NewCategory)
    $CleanCategory = Normalize-CategoryName $NewCategory
    $Tool = Get-JsonFile $Record.JsonPath
    if (!$Tool) { return }
    $OldCategory = [string]$Tool.category
    $Tool.category = $CleanCategory
    if ([string]::IsNullOrWhiteSpace([string]$Tool.subcategory)) { $Tool.subcategory = $CleanCategory }
    Save-JsonFile -Path $Record.JsonPath -Data $Tool
    Write-CategoryDebug "Set-ModuleCategory module=$($Record.Name) old=$OldCategory new=$CleanCategory json=$($Record.JsonPath)"
}

function Select-Category {
    param([string]$Title = "SELECT CATEGORY", [string]$Exclude = "", [switch]$AllowNew)
    while ($true) {
        $ExcludeClean = Normalize-CategoryName $Exclude
        $Categories = @(Get-UserCategories | Where-Object { (Normalize-CategoryName $_.Name).ToLower() -ne $ExcludeClean.ToLower() })
        Show-CategoryHeader $Title
        if ($Categories.Count -eq 0) { Write-Host "No user categories found." }
        else {
            for ($i = 0; $i -lt $Categories.Count; $i++) {
                $Note = if ($Categories[$i].Count -eq 0) { " empty" } else { "" }
                Write-Host ("[{0}] {1} ({2}{3})" -f ($i + 1), $Categories[$i].Name, $Categories[$i].Count, $Note)
            }
        }
        Write-Host ""
        if ($AllowNew) { Write-Host "[N] New Category" }
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = Read-CategoryInput "Selection"
        switch ($Choice.ToUpper()) {
            "B" { return $null }
            "N" { if ($AllowNew) { $New = Read-NewCategoryName; if ($New) { Add-CategoryRecord -Name $New; return $New } } }
            default {
                if ($Choice -match '^\d+$') {
                    $Index = [int]$Choice - 1
                    if ($Index -ge 0 -and $Index -lt $Categories.Count) { return [string]$Categories[$Index].Name }
                }
            }
        }
    }
}

function Select-ModuleRecords {
    param([string]$Title = "SELECT MODULES")
    while ($true) {
        $Modules = @(Get-ModuleRecords)
        Show-CategoryHeader $Title
        Write-Host "Step 1 of 2: Choose module(s) to move. Target category is selected next."
        Write-Host ""
        if ($Modules.Count -eq 0) { Write-Host "No user modules found."; Wait-CategoryBack; return @() }
        for ($i = 0; $i -lt $Modules.Count; $i++) { Write-Host ("[{0}] {1}  [{2}]" -f ($i + 1), $Modules[$i].Name, $Modules[$i].Category) }
        Write-Host ""
        Write-Host "Enter one number, multiple numbers separated by commas, or ALL."
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = Read-CategoryInput "Selection"
        if ($Choice.ToUpper() -eq "B") { return @() }
        if ($Choice.ToUpper() -eq "ALL") { return @($Modules) }
        $Selected = @()
        foreach ($Part in @($Choice -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
            if ($Part -match '^\d+$') {
                $Index = [int]$Part - 1
                if ($Index -ge 0 -and $Index -lt $Modules.Count) { $Selected += $Modules[$Index] }
            }
        }
        if ($Selected.Count -gt 0) { return @($Selected | Sort-Object JsonPath -Unique) }
    }
}

function Read-NewCategoryName {
    while ($true) {
        Show-CategoryHeader "NEW CATEGORY"
        Write-Host "Category rules: 1-35 characters, required, no Uncategorized."
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        $Name = Read-CategoryInput "New category name"
        if ($Name.ToUpper() -eq "B") { return $null }
        $Clean = Normalize-CategoryName $Name
        $ErrorText = Test-CategoryNameValid $Clean
        if ($ErrorText) { Write-Host ""; Write-Host "[FAIL] $ErrorText" -ForegroundColor Red; Start-Sleep -Milliseconds 900; continue }
        $Existing = @(Get-UserCategories | Where-Object { $_.Name.ToLower() -eq $Clean.ToLower() })
        if ($Existing.Count -gt 0) { Write-Host ""; Write-Host "[FAIL] Category already exists." -ForegroundColor Red; Start-Sleep -Milliseconds 900; continue }
        return $Clean
    }
}

function Confirm-CategoryAction {
    param([string]$Title, [string[]]$Lines)
    Show-CategoryHeader $Title
    foreach ($Line in $Lines) { Write-Host $Line }
    Write-Host ""
    Write-Host "[Y] Yes"
    Write-Host "[N] No"
    Write-Host ""
    do { $Choice = Read-CategoryInput "Proceed" } until ($Choice.ToUpper() -in @("Y", "N"))
    return ($Choice.ToUpper() -eq "Y")
}

function Invoke-CreateCategory {
    $Name = Read-NewCategoryName
    if (!$Name) { return }
    Add-CategoryRecord -Name $Name
    Add-CategoryHistory -Action "create" -Category $Name -Reason "Created empty user category record."
    Show-CategoryHeader "CATEGORY CREATED"
    Write-Host "Created category: $Name"
    Write-Host ""
    Write-Host "This category is now available in Rename, Delete, Merge, and Move target lists."
    Write-Host "It will appear in Browse/Search after at least one visible module uses it."
    Wait-CategoryBack
}

function Invoke-RenameCategory {
    $Old = Select-Category -Title "RENAME CATEGORY - SELECT SOURCE"
    if (!$Old) { return }
    $New = Read-NewCategoryName
    if (!$New) { return }
    $Modules = @(Get-ModuleRecords | Where-Object { $_.Category.ToLower() -eq $Old.ToLower() })
    $Lines = @("Rename category:", "  From : $Old", "  To   : $New", "", "Modules affected: $($Modules.Count)")
    $Modules | ForEach-Object { $Lines += "  - $($_.Name)" }
    if (!(Confirm-CategoryAction -Title "CONFIRM CATEGORY RENAME" -Lines $Lines)) { return }
    $Backup = New-CategoryBackup "rename"
    foreach ($Mod in $Modules) { Set-ModuleCategory -Record $Mod -NewCategory $New }
    Rename-CategoryRecord -OldName $Old -NewName $New
    Add-CategoryHistory -Action "rename" -Category $Old -Target $New -ModuleCount $Modules.Count -Reason "Renamed category. Backup: $Backup"
    Rebuild-ToolkitRegistryFromDisk
    Show-CategoryHeader "CATEGORY RENAMED"
    Write-Host "$Old -> $New"
    Write-Host "Modules updated: $($Modules.Count)"
    Wait-CategoryBack
}

function Invoke-MergeCategories {
    $Source = Select-Category -Title "MERGE CATEGORIES - SELECT SOURCE"
    if (!$Source) { return }
    $Target = Select-Category -Title "MERGE CATEGORIES - SELECT TARGET" -Exclude $Source -AllowNew
    if (!$Target) { return }
    $Modules = @(Get-ModuleRecords | Where-Object { $_.Category.ToLower() -eq $Source.ToLower() })
    $Lines = @("Merge source category into target:", "  Source: $Source", "  Target: $Target", "", "Modules affected: $($Modules.Count)")
    $Modules | ForEach-Object { $Lines += "  - $($_.Name)" }
    if (!(Confirm-CategoryAction -Title "CONFIRM CATEGORY MERGE" -Lines $Lines)) { return }
    $Backup = New-CategoryBackup "merge"
    foreach ($Mod in $Modules) { Set-ModuleCategory -Record $Mod -NewCategory $Target }
    Add-CategoryRecord -Name $Target
    Remove-CategoryRecord -Name $Source
    Add-CategoryHistory -Action "merge" -Category $Source -Target $Target -ModuleCount $Modules.Count -Reason "Merged category. Backup: $Backup"
    Rebuild-ToolkitRegistryFromDisk
    Show-CategoryHeader "CATEGORIES MERGED"
    Write-Host "$Source -> $Target"
    Write-Host "Modules moved: $($Modules.Count)"
    Wait-CategoryBack
}

function Invoke-MoveModules {
    $Selected = @(Select-ModuleRecords -Title "MOVE MODULES - SELECT MODULES")
    if ($Selected.Count -eq 0) { return }
    $Target = Select-Category -Title "MOVE MODULES - SELECT TARGET CATEGORY" -AllowNew
    if (!$Target) { return }
    $Lines = @("Move selected modules to:", "  Target: $Target", "", "Modules affected: $($Selected.Count)")
    $Selected | ForEach-Object { $Lines += "  - $($_.Name) [$($_.Category)]" }
    if (!(Confirm-CategoryAction -Title "CONFIRM MODULE MOVE" -Lines $Lines)) { return }
    $Backup = New-CategoryBackup "move"
    Add-CategoryRecord -Name $Target
    foreach ($Mod in $Selected) { Set-ModuleCategory -Record $Mod -NewCategory $Target }
    Add-CategoryHistory -Action "move" -Category "multiple" -Target $Target -ModuleCount $Selected.Count -Reason "Moved modules. Backup: $Backup"
    Rebuild-ToolkitRegistryFromDisk
    Show-CategoryHeader "MODULES MOVED"
    Write-Host "Target category: $Target"
    Write-Host "Modules moved: $($Selected.Count)"
    Wait-CategoryBack
}

function Invoke-DeleteCategory {
    $Category = Select-Category -Title "DELETE CATEGORY - SELECT CATEGORY"
    if (!$Category) { return }
    $Modules = @(Get-ModuleRecords | Where-Object { $_.Category.ToLower() -eq $Category.ToLower() })
    if ($Modules.Count -eq 0) {
        $Lines = @("Delete empty category record:", "  Category: $Category", "", "No modules will be moved or deleted.")
        if (!(Confirm-CategoryAction -Title "CONFIRM EMPTY CATEGORY DELETE" -Lines $Lines)) { return }
        Remove-CategoryRecord -Name $Category
        Add-CategoryHistory -Action "delete" -Category $Category -Reason "Deleted empty category record."
        Rebuild-ToolkitRegistryFromDisk
        Show-CategoryHeader "CATEGORY DELETED"
        Write-Host "Deleted empty category: $Category"
        Wait-CategoryBack
        return
    }
    $Target = Select-Category -Title "DELETE CATEGORY - MOVE MODULES TO" -Exclude $Category -AllowNew
    if (!$Target) { return }
    $Lines = @("Delete category by moving its modules:", "  Delete : $Category", "  Move To: $Target", "", "Modules affected: $($Modules.Count)")
    $Modules | ForEach-Object { $Lines += "  - $($_.Name)" }
    if (!(Confirm-CategoryAction -Title "CONFIRM CATEGORY DELETE" -Lines $Lines)) { return }
    $Backup = New-CategoryBackup "delete"
    Add-CategoryRecord -Name $Target
    foreach ($Mod in $Modules) { Set-ModuleCategory -Record $Mod -NewCategory $Target }
    Remove-CategoryRecord -Name $Category
    Add-CategoryHistory -Action "delete" -Category $Category -Target $Target -ModuleCount $Modules.Count -Reason "Moved modules and removed user category. Backup: $Backup"
    Rebuild-ToolkitRegistryFromDisk
    Show-CategoryHeader "CATEGORY DELETED"
    Write-Host "$Category removed by moving modules to $Target."
    Write-Host "Modules moved: $($Modules.Count)"
    Wait-CategoryBack
}

function Show-CategoryOverview {
    $UserCats = @(Get-UserCategories)
    $FwCats = @(Get-FrameworkCategoryRecords | Group-Object Category | Sort-Object Name)
    Show-CategoryHeader "CATEGORY OVERVIEW"
    Write-Host "User Categories"
    Write-Host "---------------"
    if ($UserCats.Count -eq 0) { Write-Host "No user categories found." }
    foreach ($Cat in $UserCats) {
        $Visible = @($Cat.Group | Where-Object { $_.Hidden -ne $true }).Count
        $Hidden = @($Cat.Group | Where-Object { $_.Hidden -eq $true }).Count
        $Note = if ($Cat.Count -eq 0) { "  (empty)" } else { "" }
        Write-Host ("{0,-30} {1,3} modules  visible:{2} hidden:{3}{4}" -f $Cat.Name, $Cat.Count, $Visible, $Hidden, $Note)
    }
    Write-Host ""
    Write-Host "Framework Categories (Protected)"
    Write-Host "--------------------------------"
    if ($FwCats.Count -eq 0) { Write-Host "No framework categories found." }
    foreach ($Cat in $FwCats) { Write-Host ("{0,-30} {1,3} components" -f $Cat.Name, $Cat.Count) }
    Wait-CategoryBack
}

function Show-CategoryHealth {
    $UserCats = @(Get-UserCategories)
    Show-CategoryHeader "CATEGORY HEALTH"
    if ($UserCats.Count -eq 0) { Write-Host "No user categories found."; Wait-CategoryBack; return }
    $Warnings = @()
    $TotalUserModules = @(Get-ModuleRecords).Count
    foreach ($Cat in $UserCats) {
        if ($Cat.Count -eq 0) { $Warnings += "Empty category: $($Cat.Name) has no modules yet." }
        elseif ($TotalUserModules -gt 10 -and $Cat.Count -eq 1) { $Warnings += "Small category: $($Cat.Name) has only 1 module." }
    }
    if ($TotalUserModules -le 10) { Write-Host "Info: Starter/small toolkit detected. One-module categories are normal."; Write-Host "" }
    for ($i = 0; $i -lt $UserCats.Count; $i++) {
        for ($j = $i + 1; $j -lt $UserCats.Count; $j++) {
            $A = $UserCats[$i].Name.ToLower() -replace '\s+tools$', '' -replace '\s+', ''
            $B = $UserCats[$j].Name.ToLower() -replace '\s+tools$', '' -replace '\s+', ''
            if ($A -eq $B -or $A.Contains($B) -or $B.Contains($A)) { $Warnings += "Possible duplicate categories: $($UserCats[$i].Name) / $($UserCats[$j].Name)" }
        }
    }
    if ($Warnings.Count -eq 0) { Write-Host "No category health warnings found." } else { foreach ($Warn in $Warnings) { Write-Host "[!] $Warn" -ForegroundColor Yellow } }
    Wait-CategoryBack
}

function Show-CategoryHistory {
    Show-CategoryHeader "CATEGORY HISTORY"
    $History = @()
    $RawHistory = Get-JsonFile $HistoryPath
    if ($RawHistory) { $History = @($RawHistory) }
    if ($History.Count -eq 0) { Write-Host "No category history found yet." }
    else {
        foreach ($Item in @($History | Select-Object -Last 20)) {
            $DateText = ConvertTo-CategoryText $Item.date
            $ActionText = ConvertTo-CategoryText $Item.action
            $CategoryText = ConvertTo-CategoryText $Item.category
            $TargetText = ConvertTo-CategoryText $Item.target
            $ModulesText = ConvertTo-CategoryText $Item.modules_affected
            if ([string]::IsNullOrWhiteSpace($TargetText)) { $TargetText = "-" }
            if ([string]::IsNullOrWhiteSpace($ModulesText)) { $ModulesText = "0" }
            Write-Host ("{0} | {1} | {2} -> {3} | modules:{4}" -f $DateText, $ActionText, $CategoryText, $TargetText, $ModulesText)
        }
    }
    Wait-CategoryBack
}

function Show-CategoryDebugLog {
    Show-CategoryHeader "CATEGORY MANAGER DEBUG LOG"
    if (!(Test-Path $DebugLogPath)) { Write-Host "No debug log found yet."; Wait-CategoryBack; return }
    Get-Content -Path $DebugLogPath -Tail 60 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
    Wait-CategoryBack
}

Ensure-CategoryFolders
Write-CategoryDebug "Category Manager started root=$Root records=$CategoryRecordsPath"

while ($true) {
    Show-CategoryHeader "CATEGORY MANAGER"
    Write-Host "Create, rename, merge, move, delete, and audit user module categories."
    Write-Host "Framework categories are protected. User modules are never orphaned."
    Write-Host ""
    Write-Host "Primary Actions"
    Write-Host "---------------"
    Write-Host "[1] Create Category"
    Write-Host "[2] Rename Category"
    Write-Host "[3] Merge Categories"
    Write-Host "[4] Move Modules"
    Write-Host "[5] Delete Category"
    Write-Host ""
    Write-Host "Inspect"
    Write-Host "-------"
    Write-Host "[6] View Categories"
    Write-Host "[7] Category Health"
    Write-Host "[8] Category History"
    Write-Host "[9] Debug Log / Diagnostics"
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = Read-CategoryInput "Selection"
    switch ($Choice.ToUpper()) {
        "1" { Invoke-CreateCategory }
        "2" { Invoke-RenameCategory }
        "3" { Invoke-MergeCategories }
        "4" { Invoke-MoveModules }
        "5" { Invoke-DeleteCategory }
        "6" { Show-CategoryOverview }
        "7" { Show-CategoryHealth }
        "8" { Show-CategoryHistory }
        "9" { Show-CategoryDebugLog }
        "B" { return }
    }
}
