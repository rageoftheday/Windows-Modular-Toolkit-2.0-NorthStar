# Windows Modular Toolkit - Metadata Engine 35B
# Metadata is Foundation infrastructure. It is generated/stored with real objects.

$ErrorActionPreference = 'Continue'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$FrameworkRoot = Split-Path -Parent $ScriptRoot
$ToolkitRoot = Split-Path -Parent $FrameworkRoot
$ConfigRoot = Join-Path $ToolkitRoot 'Config'
$LogRoot = Join-Path $ToolkitRoot 'Logs'
$IndexPath = Join-Path $ConfigRoot 'metadata_index.json'
$LogPath = Join-Path $LogRoot 'framework_test.log'
$EnginePath = Join-Path $FrameworkRoot 'Foundation\Metadata\Metadata.Engine.ps1'

if (!(Test-Path $ConfigRoot)) { New-Item -ItemType Directory -Path $ConfigRoot -Force | Out-Null }
if (!(Test-Path $LogRoot)) { New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null }
if (Test-Path $EnginePath) { . $EnginePath }

function Write-TestLogLocal {
    param([string]$Area,[string]$Status,[string]$Message)
    try {
        $Line = "{0} | {1} | {2} | {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Status, $Area, $Message
        Add-Content -Path $LogPath -Value $Line -Encoding UTF8
    } catch {}
}

function Show-Header {
    param([string]$Title)
    Clear-Host
    Write-Host '============================================================'
    Write-Host " $Title"
    Write-Host '============================================================'
    Write-Host ''
}

function Pause-Toolkit {
    Write-Host ''
    Read-Host 'Press Enter to continue' | Out-Null
}

function Get-DefaultTypes { return @('Module','Framework Tool','Installer','Website','Script','Folder','Documentation','Workspace Item','Item','Other') }
function Get-DefaultCategories { return @('Networking','Browsers','Printers','Security','Development','Installers','Documentation','Websites','Folders','Scripts','Modules','Workspace','Utilities','System','Other') }

function Select-FromList {
    param(
        [string]$Title,
        [string[]]$Items,
        [string]$Current,
        [switch]$AllowCustom
    )
    while ($true) {
        Show-Header $Title
        if (-not [string]::IsNullOrWhiteSpace($Current)) {
            Write-Host "Current: $Current"
            Write-Host ''
        }
        for ($i = 0; $i -lt $Items.Count; $i++) {
            Write-Host ("[{0}] {1}" -f ($i + 1), $Items[$i])
        }
        if ($AllowCustom) { Write-Host '[C] Custom' }
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return $null }
        if ($AllowCustom -and $Choice.ToUpper() -eq 'C') {
            Write-Host ''
            Write-Host 'Examples:'
            Write-Host 'Custom category: Store Reports'
            Write-Host 'Custom type    : Internal Tool'
            $Value = Read-Host 'Custom value'
            if (-not [string]::IsNullOrWhiteSpace($Value)) { return $Value.Trim() }
            continue
        }
        $Number = 0
        if ([int]::TryParse($Choice, [ref]$Number)) {
            if ($Number -ge 1 -and $Number -le $Items.Count) { return $Items[$Number - 1] }
        }
        Write-Host 'Invalid selection.' -ForegroundColor Yellow
        Start-Sleep -Milliseconds 700
    }
}

function Get-ObjectSourceRecords {
    $Records = New-Object System.Collections.ArrayList

    # Framework tools
    foreach ($File in @(Get-ChildItem -Path $FrameworkRoot -Recurse -Filter tool.json -File -ErrorAction SilentlyContinue)) {
        if ($File.FullName -match '\\Foundation\\') { continue }
        $Obj = Read-WmtJsonFile -Path $File.FullName
        if ($null -eq $Obj) { continue }
        $Name = [string]$Obj.name
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = Split-Path -Leaf $File.DirectoryName }
        [void]$Records.Add([PSCustomObject]@{
            name = $Name
            source_type = 'Framework Tool'
            path = $File.FullName
            relative_path = $File.FullName.Replace($ToolkitRoot + [System.IO.Path]::DirectorySeparatorChar, '')
            object = $Obj
        })
    }

    # User modules
    $ModulesRoot = Join-Path $ToolkitRoot 'Modules'
    if (Test-Path $ModulesRoot) {
        foreach ($File in @(Get-ChildItem -Path $ModulesRoot -Recurse -Filter tool.json -File -ErrorAction SilentlyContinue)) {
            $Obj = Read-WmtJsonFile -Path $File.FullName
            if ($null -eq $Obj) { continue }
            $Name = [string]$Obj.name
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = Split-Path -Leaf $File.DirectoryName }
            [void]$Records.Add([PSCustomObject]@{
                name = $Name
                source_type = 'Module'
                path = $File.FullName
                relative_path = $File.FullName.Replace($ToolkitRoot + [System.IO.Path]::DirectorySeparatorChar, '')
                object = $Obj
            })
        }
    }

    # Workspace physical items
    $WorkspaceRoot = Join-Path $ToolkitRoot 'Workspace'
    if (Test-Path $WorkspaceRoot) {
        foreach ($File in @(Get-ChildItem -Path $WorkspaceRoot -Recurse -Filter *.workspace.json -File -ErrorAction SilentlyContinue)) {
            $Obj = Read-WmtJsonFile -Path $File.FullName
            if ($null -eq $Obj) { continue }
            $Name = [string]$Obj.name
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = [System.IO.Path]::GetFileNameWithoutExtension($File.Name) }
            [void]$Records.Add([PSCustomObject]@{
                name = $Name
                source_type = 'Workspace Item'
                path = $File.FullName
                relative_path = $File.FullName.Replace($ToolkitRoot + [System.IO.Path]::DirectorySeparatorChar, '')
                object = $Obj
            })
        }
    }

    # Installer product metadata if present
    $RepositoryRoot = Join-Path $ToolkitRoot 'Repository'
    if (Test-Path $RepositoryRoot) {
        foreach ($File in @(Get-ChildItem -Path $RepositoryRoot -Recurse -Include metadata.json,installer.json,product.json -File -ErrorAction SilentlyContinue)) {
            $Obj = Read-WmtJsonFile -Path $File.FullName
            if ($null -eq $Obj) { continue }
            $Name = [string]$Obj.name
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = Split-Path -Leaf $File.DirectoryName }
            [void]$Records.Add([PSCustomObject]@{
                name = $Name
                source_type = 'Installer'
                path = $File.FullName
                relative_path = $File.FullName.Replace($ToolkitRoot + [System.IO.Path]::DirectorySeparatorChar, '')
                object = $Obj
            })
        }
    }

    return $Records
}

function New-IndexRecord {
    param($Record)
    $Obj = $Record.object
    return [PSCustomObject]@{
        name = [string]$Obj.name
        description = [string]$Obj.description
        type = [string]$Obj.type
        category = [string]$Obj.category
        keywords = @($Obj.keywords)
        important = [bool]$Obj.important
        source_type = [string]$Record.source_type
        path = [string]$Record.relative_path
    }
}

function Rebuild-MetadataIndex {
    $Records = Get-ObjectSourceRecords
    $Index = New-Object System.Collections.ArrayList
    foreach ($Record in $Records) { [void]$Index.Add((New-IndexRecord -Record $Record)) }
    try {
        $Out = @()
        foreach ($Entry in $Index) { $Out += $Entry }
        ConvertTo-Json -InputObject $Out -Depth 20 | Set-Content -Path $IndexPath -Encoding UTF8
        Write-TestLogLocal 'Metadata' 'PASS' ("Rebuilt metadata index: $($Index.Count) objects")
        return $Index.Count
    } catch {
        Write-TestLogLocal 'Metadata' 'FAIL' ('Rebuild metadata index failed: ' + $_.Exception.Message)
        return -1
    }
}

function Show-MetadataScan {
    Show-Header 'METADATA SOURCE SCAN'
    $Records = Get-ObjectSourceRecords
    if ($Records.Count -eq 0) {
        Write-Host 'No metadata-capable objects found.' -ForegroundColor Yellow
    } else {
        Write-Host "Objects found: $($Records.Count)"
        Write-Host ''
        $Preview = @($Records | Select-Object -First 20)
        $i = 1
        foreach ($Record in $Preview) {
            Write-Host ("[{0}] {1}" -f $i, $Record.name)
            Write-Host ("    Source : {0}" -f $Record.source_type) -ForegroundColor DarkGray
            Write-Host ("    Path   : {0}" -f $Record.relative_path) -ForegroundColor DarkGray
            $i++
        }
        if ($Records.Count -gt 20) { Write-Host "...and $($Records.Count - 20) more." -ForegroundColor DarkGray }
    }
    $Count = Rebuild-MetadataIndex
    if ($Count -ge 0) { Write-Host ''; Write-Host "Metadata index rebuilt: $Count objects" -ForegroundColor Green }
    Pause-Toolkit
}

function Validate-MetadataObjects {
    Show-Header 'VALIDATE METADATA'
    $Records = Get-ObjectSourceRecords
    $Bad = New-Object System.Collections.ArrayList
    foreach ($Record in $Records) {
        $Issues = @(Test-WmtMetadata -Object $Record.object)
        if ($Issues.Count -gt 0) {
            [void]$Bad.Add([PSCustomObject]@{ record = $Record; issues = $Issues })
        }
    }
    Write-Host "Objects checked: $($Records.Count)"
    Write-Host "Issues found   : $($Bad.Count)"
    Write-Host ''
    if ($Bad.Count -eq 0) {
        Write-Host '[PASS] Metadata validation passed.' -ForegroundColor Green
        Write-TestLogLocal 'Metadata' 'PASS' 'Metadata validation passed'
    } else {
        $i = 1
        foreach ($Item in @($Bad | Select-Object -First 20)) {
            Write-Host ("[{0}] {1}" -f $i, $Item.record.name) -ForegroundColor Yellow
            Write-Host ("    Source : {0}" -f $Item.record.source_type) -ForegroundColor DarkGray
            Write-Host ("    Issues : {0}" -f (($Item.issues) -join ', ')) -ForegroundColor DarkGray
            $i++
        }
        Write-TestLogLocal 'Metadata' 'WARN' ("Metadata validation found $($Bad.Count) issue objects")
    }
    Pause-Toolkit
}

function Repair-MetadataObjects {
    Show-Header 'REPAIR METADATA'
    Write-Host 'This repairs missing metadata fields on real objects.'
    Write-Host 'It does not create standalone metadata records.'
    Write-Host ''
    Write-Host '[1] Repair missing metadata'
    Write-Host '[B] Back'
    Write-Host ''
    $Choice = Read-Host 'Selection'
    if ($Choice.ToUpper() -eq 'B') { return }
    if ($Choice -ne '1') { return }

    $Records = Get-ObjectSourceRecords
    $Fixed = 0
    foreach ($Record in $Records) {
        $Issues = @(Test-WmtMetadata -Object $Record.object)
        if ($Issues.Count -eq 0) { continue }
        $DefaultType = $Record.source_type
        $Updated = Repair-WmtMetadataObject -Object $Record.object -DefaultType $DefaultType -Path $Record.path
        if ($null -ne $Updated) {
            if (Write-WmtJsonFile -Path $Record.path -Object $Updated) { $Fixed++ }
        }
    }
    $Count = Rebuild-MetadataIndex
    Write-Host ''
    Write-Host "Objects repaired: $Fixed" -ForegroundColor Green
    if ($Count -ge 0) { Write-Host "Metadata index rebuilt: $Count objects" -ForegroundColor Green }
    Write-TestLogLocal 'Metadata' 'PASS' ("Metadata repair fixed $Fixed objects")
    Pause-Toolkit
}

function Show-ObjectMetadata {
    param($Record)
    $Obj = $Record.object
    Show-Header 'METADATA PREVIEW'
    Write-Host "Name        : $($Obj.name)"
    Write-Host "Description : $($Obj.description)"
    Write-Host "Type        : $($Obj.type)"
    Write-Host "Category    : $($Obj.category)"
    Write-Host "Important   : $($Obj.important)"
    if ($Obj.keywords) { Write-Host "Keywords    : $(($Obj.keywords) -join ', ')" } else { Write-Host 'Keywords    : none' }
    Write-Host ''
    Write-Host "Source      : $($Record.source_type)"
    Write-Host "Path        : $($Record.relative_path)"
    Write-Host ''
}

function Edit-MetadataObject {
    $Records = Get-ObjectSourceRecords
    if ($Records.Count -eq 0) { Show-Header 'METADATA EDITOR'; Write-Host 'No objects found.'; Pause-Toolkit; return }
    while ($true) {
        Show-Header 'METADATA EDITOR'
        Write-Host 'Edit metadata attached to existing objects.'
        Write-Host ''
        $Max = [Math]::Min($Records.Count, 25)
        for ($i = 0; $i -lt $Max; $i++) {
            Write-Host ("[{0}] {1}" -f ($i + 1), $Records[$i].name)
            Write-Host ("    {0} | {1}" -f $Records[$i].source_type, $Records[$i].relative_path) -ForegroundColor DarkGray
        }
        if ($Records.Count -gt 25) { Write-Host "Only showing first 25 objects. Use validation/repair for bulk work." -ForegroundColor DarkGray }
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return }
        $Number = 0
        if (-not [int]::TryParse($Choice, [ref]$Number)) { continue }
        if ($Number -lt 1 -or $Number -gt $Max) { continue }
        $Record = $Records[$Number - 1]
        Edit-SelectedMetadataObject -Record $Record
        $Records = Get-ObjectSourceRecords
    }
}

function Edit-SelectedMetadataObject {
    param($Record)
    $Obj = $Record.object
    while ($true) {
        Show-ObjectMetadata -Record $Record
        Write-Host '[1] Edit Description'
        Write-Host '[2] Select Type'
        Write-Host '[3] Select Category'
        Write-Host '[4] Edit Keywords'
        Write-Host '[5] Regenerate Metadata'
        Write-Host '[6] Toggle Important'
        Write-Host '[S] Save'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch ($Choice.ToUpper()) {
            '1' {
                Write-Host ''
                Write-Host 'Example: Clears Windows DNS cache.'
                $Value = Read-Host 'Description'
                if (-not [string]::IsNullOrWhiteSpace($Value)) { $Obj.description = $Value.Trim() }
            }
            '2' {
                $Value = Select-FromList -Title 'SELECT TYPE' -Items (Get-DefaultTypes) -Current ([string]$Obj.type) -AllowCustom
                if ($null -ne $Value) { $Obj.type = $Value }
            }
            '3' {
                $Value = Select-FromList -Title 'SELECT CATEGORY' -Items (Get-DefaultCategories) -Current ([string]$Obj.category) -AllowCustom
                if ($null -ne $Value) { $Obj.category = $Value }
            }
            '4' {
                Write-Host ''
                Write-Host 'Examples:'
                Write-Host 'printer, toner, audit'
                Write-Host 'dns, network, troubleshooting'
                $Value = Read-Host 'Keywords comma-separated'
                if (-not [string]::IsNullOrWhiteSpace($Value)) {
                    $Arr = @()
                    foreach ($K in ($Value -split ',')) {
                        $Clean = $K.Trim().ToLowerInvariant()
                        if ($Clean.Length -gt 1 -and -not ($Arr -contains $Clean)) { $Arr += $Clean }
                    }
                    $Obj.keywords = @($Arr)
                }
            }
            '5' {
                $Obj = Repair-WmtMetadataObject -Object $Obj -DefaultType $Record.source_type -Path $Record.path
                Write-Host 'Metadata regenerated.' -ForegroundColor Green
                Start-Sleep -Milliseconds 700
            }
            '6' {
                if ($null -eq $Obj.important) { $Obj | Add-Member -MemberType NoteProperty -Name important -Value $true -Force }
                else { $Obj.important = -not [bool]$Obj.important }
            }
            'S' {
                if (Write-WmtJsonFile -Path $Record.path -Object $Obj) {
                    Rebuild-MetadataIndex | Out-Null
                    Write-Host ''
                    Write-Host 'Metadata saved.' -ForegroundColor Green
                    Write-TestLogLocal 'Metadata' 'PASS' ('Edited metadata: ' + $Record.name)
                    Pause-Toolkit
                    return
                } else {
                    Write-Host '[FAIL] Could not save metadata.' -ForegroundColor Red
                    Pause-Toolkit
                }
            }
            'B' { return }
        }
    }
}

function Test-MetadataEngineSuggestions {
    Show-Header 'TEST METADATA ENGINE'
    Write-Host 'This tests suggestions only. It does not save anything.'
    Write-Host ''
    Write-Host 'Examples:'
    Write-Host 'Name: Google Chrome'
    Write-Host 'Description: Web browser from Google.'
    Write-Host ''
    Write-Host 'Name: DNS Flush'
    Write-Host 'Description: Clears Windows DNS cache.'
    Write-Host ''
    $Name = Read-Host 'Name'
    if ([string]::IsNullOrWhiteSpace($Name)) { return }
    $Description = Read-Host 'Description'
    if ([string]::IsNullOrWhiteSpace($Description)) { return }
    $Meta = New-WmtMetadata -Name $Name.Trim() -Description $Description.Trim()
    Show-Header 'METADATA SUGGESTION PREVIEW'
    Write-Host "Name        : $($Meta.name)"
    Write-Host "Description : $($Meta.description)"
    Write-Host "Type        : $($Meta.type)"
    Write-Host "Category    : $($Meta.category)"
    Write-Host "Keywords    : $(($Meta.keywords) -join ', ')"
    Write-Host "Important   : $($Meta.important)"
    Write-Host ''
    Write-Host 'No record was created. Metadata is stored only with real objects.' -ForegroundColor DarkGray
    Write-TestLogLocal 'Metadata' 'PASS' ('Tested metadata engine: ' + $Name)
    Pause-Toolkit
}

function Open-MetadataLocations {
    Show-Header 'OPEN METADATA LOCATIONS'
    Write-Host '[1] Open Foundation Metadata Folder'
    Write-Host '[2] Open Config Folder'
    Write-Host '[3] Open Docs Folder'
    Write-Host '[B] Back'
    Write-Host ''
    $Choice = Read-Host 'Selection'
    try {
        switch ($Choice.ToUpper()) {
            '1' { Start-Process explorer.exe (Join-Path $FrameworkRoot 'Foundation\Metadata') }
            '2' { Start-Process explorer.exe $ConfigRoot }
            '3' { Start-Process explorer.exe (Join-Path $FrameworkRoot 'Docs') }
            'B' { return }
        }
    } catch {
        Write-Host '[FAIL] Could not open folder.' -ForegroundColor Red
        Pause-Toolkit
    }
}

function Show-MetadataHelp {
    Show-Header 'METADATA ENGINE HELP'
    Write-Host 'Metadata Engine is Foundation infrastructure.'
    Write-Host ''
    Write-Host 'It does NOT create standalone metadata records.'
    Write-Host ''
    Write-Host 'It does:'
    Write-Host '- Generate metadata for real objects'
    Write-Host '- Store metadata with those objects'
    Write-Host '- Validate missing metadata'
    Write-Host '- Repair/regenerate metadata'
    Write-Host '- Let you edit existing object metadata'
    Write-Host ''
    Write-Host 'North Star rule:'
    Write-Host 'Framework suggests. User decides.'
    Pause-Toolkit
}

Write-TestLogLocal 'Metadata' 'INFO' 'Metadata Engine launched'

while ($true) {
    Show-Header 'METADATA ENGINE'
    Write-Host 'Foundation service for metadata attached to real toolkit objects.'
    Write-Host 'No standalone metadata records are created here.'
    Write-Host ''
    Write-Host '[1] Scan Metadata Sources'
    Write-Host '    Scan tools, modules, workspace items, and installer metadata.' -ForegroundColor DarkGray
    Write-Host '[2] Validate Metadata'
    Write-Host '    Check existing objects for missing metadata.' -ForegroundColor DarkGray
    Write-Host '[3] Repair Missing Metadata'
    Write-Host '    Regenerate missing fields directly on real objects.' -ForegroundColor DarkGray
    Write-Host '[4] Metadata Editor'
    Write-Host '    View or edit metadata attached to existing objects.' -ForegroundColor DarkGray
    Write-Host '[5] Test Metadata Engine'
    Write-Host '    Preview suggestions without saving anything.' -ForegroundColor DarkGray
    Write-Host '[6] Open Metadata Locations'
    Write-Host '    Open Foundation, Config, or Docs folders.' -ForegroundColor DarkGray
    Write-Host '[H] Help'
    Write-Host '[B] Back'
    Write-Host ''
    $Choice = Read-Host 'Selection'
    switch ($Choice.ToUpper()) {
        '1' { Show-MetadataScan }
        '2' { Validate-MetadataObjects }
        '3' { Repair-MetadataObjects }
        '4' { Edit-MetadataObject }
        '5' { Test-MetadataEngineSuggestions }
        '6' { Open-MetadataLocations }
        'H' { Show-MetadataHelp }
        'B' { Write-TestLogLocal 'Metadata' 'PASS' 'Back Metadata Engine -> Toolkit Management'; return }
        default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; Start-Sleep -Milliseconds 700 }
    }
}
