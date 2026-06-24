# Windows Modular Toolkit - Foundation Search Engine
# Framework 2.0 Phase 42C.1a
# Searches metadata-backed framework objects using a shared result format.

function Read-WmtSearchJsonFile {
    param([string]$Path)
    try {
        if (!(Test-Path $Path)) { return $null }
        $Raw = Get-Content -Path $Path -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
        return ($Raw | ConvertFrom-Json -ErrorAction Stop)
    } catch { return $null }
}

function Get-WmtSearchArray {
    param($Value)
    $Out = New-Object System.Collections.ArrayList
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { foreach ($v in $Value) { [void]$Out.Add($v) } }
    elseif ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) { foreach ($v in $Value) { [void]$Out.Add($v) } }
    else { [void]$Out.Add($Value) }
    return @($Out)
}

function Resolve-WmtSearchPath {
    param([string]$ToolkitRoot,[string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    try {
        if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
        return (Join-Path $ToolkitRoot $Path)
    } catch { return $Path }
}

function Get-WmtRepositoryType {
    param($Record,[string]$RecordFilePath,[string]$DefaultType = "Repository Item")
    $PathText = (([string]$Record.path) + ' ' + ([string]$RecordFilePath)).Replace('/','\')

    if (-not [string]::IsNullOrWhiteSpace([string]$Record.source_type)) {
        switch -Regex ([string]$Record.source_type) {
            'script' { return 'Script' }
            'document' { return 'Document' }
            'software' { return 'Software' }
            'installer' { return 'Software' }
        }
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$Record.repository_kind)) { return [string]$Record.repository_kind }
    if ($PathText -match 'Repository\\Scripts\\|script\.records\.json') { return 'Script' }
    if ($PathText -match 'Repository\\Documents\\|document\.records\.json') { return 'Document' }
    if ($PathText -match 'Repository\\Software\\|software\.records\.json') { return 'Software' }
    if ($PathText -match 'Repository\\Packages\\|package\.records\.json') { return 'Package' }
    if ($PathText -match 'Repository\\Disk Images\\|diskimage\.records\.json|Repository\\Images\\') { return 'Disk Image' }
    if ($PathText -match 'Repository\\Archives\\|archive\.records\.json') { return 'Archive' }
    return $DefaultType
}

function Get-WmtRepositoryCategory {
    param($Record,[string]$RecordType)
    if (-not [string]::IsNullOrWhiteSpace([string]$Record.category)) { return [string]$Record.category }
    if (-not [string]::IsNullOrWhiteSpace([string]$Record.destination)) { return [string]$Record.destination }
    switch ($RecordType) {
        'Software' { return 'Software' }
        'Script' { return 'Scripts' }
        'Document' { return 'Documents' }
        'Package' { return 'Packages' }
        'Disk Image' { return 'Disk Images' }
        'Archive' { return 'Archives' }
        default { return 'Repository' }
    }
}

function Get-WmtRepositoryDescription {
    param($Record,[string]$RecordType)
    if (-not [string]::IsNullOrWhiteSpace([string]$Record.description)) { return [string]$Record.description }
    $Name = [string]$Record.name
    if ([string]::IsNullOrWhiteSpace($Name)) { $Name = [string]$Record.source_name }
    switch ($RecordType) {
        'Software' { return "Repository software item: $Name" }
        'Script' { return "Repository PowerShell script: $Name" }
        'Document' { return "Repository document: $Name" }
        'Package' { return "Repository Windows package: $Name" }
        'Disk Image' { return "Repository disk image: $Name" }
        'Archive' { return "Repository archive: $Name" }
        default { return "Repository item: $Name" }
    }
}

function New-WmtSearchObject {
    param(
        [string]$Name,
        [string]$Description,
        [string]$Type,
        [string]$Category,
        $Keywords,
        [string]$Path,
        [string]$Source
    )
    $KeywordList = @()
    if ($Keywords) {
        foreach ($K in (Get-WmtSearchArray $Keywords)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$K)) { $KeywordList += ([string]$K).Trim().ToLowerInvariant() }
        }
    }
    if ([string]::IsNullOrWhiteSpace($Name)) { $Name = [System.IO.Path]::GetFileNameWithoutExtension($Path) }
    if ([string]::IsNullOrWhiteSpace($Description)) { $Description = $Name }
    if ([string]::IsNullOrWhiteSpace($Type)) { $Type = 'Item' }
    if ([string]::IsNullOrWhiteSpace($Category)) { $Category = 'Other' }
    return [PSCustomObject]@{
        name = $Name
        description = $Description
        type = $Type
        category = $Category
        keywords = @($KeywordList)
        path = $Path
        source = $Source
    }
}

function Add-WmtSearchObject {
    param($List,$Object)
    if ($null -eq $Object) { return }
    if ([string]::IsNullOrWhiteSpace([string]$Object.name)) { return }
    [void]$List.Add($Object)
}

function Add-WmtRepositoryRecordToIndex {
    param($List,[string]$ToolkitRoot,$Record,[string]$RecordFilePath,[string]$DefaultType)
    if ($null -eq $Record) { return }
    $RecordType = Get-WmtRepositoryType -Record $Record -RecordFilePath $RecordFilePath -DefaultType $DefaultType
    $Category = Get-WmtRepositoryCategory -Record $Record -RecordType $RecordType
    $Description = Get-WmtRepositoryDescription -Record $Record -RecordType $RecordType
    $TargetPath = if ($Record.path) { Resolve-WmtSearchPath -ToolkitRoot $ToolkitRoot -Path $Record.path } else { $RecordFilePath }
    $Keywords = @($Record.keywords)
    if ($Record.destination) { $Keywords += $Record.destination }
    if ($Record.source_name) { $Keywords += $Record.source_name }
    if ($Record.extension) { $Keywords += $Record.extension; $Keywords += ([string]$Record.extension).TrimStart('.') }
    if ($Record.format) { $Keywords += $Record.format }
    if ($Record.detection_name) { $Keywords += $Record.detection_name }
    if ($Record.detection_category) { $Keywords += $Record.detection_category }
    if ($Record.detection_subcategory) { $Keywords += $Record.detection_subcategory }
    if ($Record.custom_type) { $Keywords += $Record.custom_type }
    Add-WmtSearchObject $List (New-WmtSearchObject -Name $Record.name -Description $Description -Type $RecordType -Category $Category -Keywords $Keywords -Path $TargetPath -Source 'Repository')
}

function Get-WmtSearchIndex {
    param([string]$ToolkitRoot)
    $Results = New-Object System.Collections.ArrayList

    # Metadata index cache
    $MetadataPath = Join-Path $ToolkitRoot 'Config\metadata_index.json'
    $Metadata = Read-WmtSearchJsonFile $MetadataPath
    foreach ($M in (Get-WmtSearchArray $Metadata)) {
        Add-WmtSearchObject $Results (New-WmtSearchObject -Name $M.name -Description $M.description -Type $M.type -Category $M.category -Keywords $M.keywords -Path $M.path -Source 'Metadata Index')
    }

    # Framework tools
    $FrameworkPath = Join-Path $ToolkitRoot 'Framework'
    if (Test-Path $FrameworkPath) {
        Get-ChildItem -Path $FrameworkPath -Recurse -Filter tool.json -ErrorAction SilentlyContinue | ForEach-Object {
            $J = Read-WmtSearchJsonFile $_.FullName
            if ($J) {
                Add-WmtSearchObject $Results (New-WmtSearchObject -Name $J.name -Description $J.description -Type 'Framework Tool' -Category $J.category -Keywords $J.keywords -Path $_.DirectoryName -Source 'Framework')
            }
        }
    }

    # User modules
    $ModulesPath = Join-Path $ToolkitRoot 'Modules'
    if (Test-Path $ModulesPath) {
        Get-ChildItem -Path $ModulesPath -Recurse -Filter tool.json -ErrorAction SilentlyContinue | ForEach-Object {
            $J = Read-WmtSearchJsonFile $_.FullName
            if ($J) {
                Add-WmtSearchObject $Results (New-WmtSearchObject -Name $J.name -Description $J.description -Type 'Module' -Category $J.category -Keywords $J.keywords -Path $_.DirectoryName -Source 'Modules')
            }
        }
    }

    # Workspace items from physical files
    $WorkspacePath = Join-Path $ToolkitRoot 'Workspace'
    if (Test-Path $WorkspacePath) {
        Get-ChildItem -Path $WorkspacePath -Recurse -Filter '*.workspace.json' -ErrorAction SilentlyContinue | ForEach-Object {
            $J = Read-WmtSearchJsonFile $_.FullName
            if ($J) {
                Add-WmtSearchObject $Results (New-WmtSearchObject -Name $J.name -Description $J.description -Type $J.object_type -Category $J.category -Keywords $J.keywords -Path $(if ($J.path) { $J.path } else { $_.FullName }) -Source 'Workspace')
            }
        }
    }

    # Workspace cache fallback
    $WorkspaceItems = Read-WmtSearchJsonFile (Join-Path $ToolkitRoot 'Config\workspace_items.json')
    foreach ($W in (Get-WmtSearchArray $WorkspaceItems)) {
        Add-WmtSearchObject $Results (New-WmtSearchObject -Name $W.name -Description $W.description -Type $W.object_type -Category $W.category -Keywords $W.keywords -Path $(if ($W.path) { $W.path } else { $W.target }) -Source 'Workspace Cache')
    }

    # Repository records stored in Config
    $RepositoryRecordFiles = @(
        @{ Path = (Join-Path $ToolkitRoot 'Config\software.records.json'); Type = 'Software' },
        @{ Path = (Join-Path $ToolkitRoot 'Config\script.records.json'); Type = 'Script' },
        @{ Path = (Join-Path $ToolkitRoot 'Config\document.records.json'); Type = 'Document' },
        @{ Path = (Join-Path $ToolkitRoot 'Config\package.records.json'); Type = 'Package' },
        @{ Path = (Join-Path $ToolkitRoot 'Config\archive.records.json'); Type = 'Archive' },
        @{ Path = (Join-Path $ToolkitRoot 'Config\diskimage.records.json'); Type = 'Disk Image' },
        @{ Path = (Join-Path $ToolkitRoot 'Config\custom.records.json'); Type = 'Custom' },
        @{ Path = (Join-Path $ToolkitRoot 'Config\repository.records.json'); Type = 'Repository Item' }
    )
    foreach ($RecordFile in $RepositoryRecordFiles) {
        if (-not (Test-Path $RecordFile.Path)) { continue }
        $Data = Read-WmtSearchJsonFile $RecordFile.Path
        foreach ($R in (Get-WmtSearchArray $Data)) {
            Add-WmtRepositoryRecordToIndex -List $Results -ToolkitRoot $ToolkitRoot -Record $R -RecordFilePath $RecordFile.Path -DefaultType $RecordFile.Type
        }
    }

    # Repository metadata/configs stored beside repository items
    $RepositoryPath = Join-Path $ToolkitRoot 'Repository'
    if (Test-Path $RepositoryPath) {
        Get-ChildItem -Path $RepositoryPath -Recurse -Include '*.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
            $J = Read-WmtSearchJsonFile $_.FullName
            if ($J) {
                Add-WmtRepositoryRecordToIndex -List $Results -ToolkitRoot $ToolkitRoot -Record $J -RecordFilePath $_.FullName -DefaultType 'Repository Item'
            }
        }
    }

    # Detection Library entries
    foreach ($DetectionLibraryPath in @((Join-Path $ToolkitRoot 'Config\detection.library.core.json'), (Join-Path $ToolkitRoot 'Config\detection.library.json'))) {
        if (Test-Path $DetectionLibraryPath) {
            $DLib = Read-WmtSearchJsonFile $DetectionLibraryPath
            foreach ($D in (Get-WmtSearchArray $DLib.detections)) {
                $Keywords = @($D.indicators) + @($D.name,$D.category,$D.subcategory,'detection','library')
                Add-WmtSearchObject $Results (New-WmtSearchObject -Name $D.name -Description $D.description -Type 'Detection Rule' -Category $D.category -Keywords $Keywords -Path $DetectionLibraryPath -Source 'Detection Library')
            }
            foreach ($D in (Get-WmtSearchArray $DLib.user_detections)) {
                $Keywords = @($D.indicators) + @($D.name,$D.category,$D.subcategory,'detection','library','user')
                Add-WmtSearchObject $Results (New-WmtSearchObject -Name $D.name -Description $D.description -Type 'User Detection Rule' -Category $D.category -Keywords $Keywords -Path $DetectionLibraryPath -Source 'Detection Library')
            }
        }
    }

    # Documentation
    $DocsPath = Join-Path $ToolkitRoot 'Docs'
    if (Test-Path $DocsPath) {
        Get-ChildItem -Path $DocsPath -Recurse -Include '*.md','*.txt' -File -ErrorAction SilentlyContinue | ForEach-Object {
            $Content = ''
            try { $Content = (Get-Content $_.FullName -TotalCount 20 -ErrorAction Stop) -join ' ' } catch {}
            Add-WmtSearchObject $Results (New-WmtSearchObject -Name $_.BaseName -Description $Content -Type 'Documentation' -Category (Split-Path $_.DirectoryName -Leaf) -Keywords @($_.BaseName -split '[_\- ]+') -Path $_.FullName -Source 'Docs')
        }
    }

    return @($Results)
}

function Search-WmtIndex {
    param([array]$Index,[string]$Query)
    if ([string]::IsNullOrWhiteSpace($Query)) { return @() }
    $Needle = $Query.ToLowerInvariant().Trim()
    $Matches = New-Object System.Collections.ArrayList
    foreach ($Item in @($Index)) {
        $Haystack = (([string]$Item.name) + ' ' + ([string]$Item.description) + ' ' + ([string]$Item.type) + ' ' + ([string]$Item.category) + ' ' + (@($Item.keywords) -join ' ') + ' ' + ([string]$Item.source)).ToLowerInvariant()
        if ($Haystack -like "*$Needle*") {
            $Score = 1
            if (([string]$Item.name).ToLowerInvariant() -like "*$Needle*") { $Score += 10 }
            if (([string]$Item.category).ToLowerInvariant() -like "*$Needle*") { $Score += 4 }
            if ((@($Item.keywords) -join ' ').ToLowerInvariant() -like "*$Needle*") { $Score += 5 }
            Add-Member -InputObject $Item -MemberType NoteProperty -Name search_score -Value $Score -Force
            [void]$Matches.Add($Item)
        }
    }
    return @($Matches | Sort-Object search_score,name -Descending)
}

function Save-WmtSearchIndex {
    param([string]$ToolkitRoot,[array]$Index)
    try {
        $Path = Join-Path $ToolkitRoot 'Config\search_index.json'
        @($Index) | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding UTF8
        return $true
    } catch { return $false }
}
