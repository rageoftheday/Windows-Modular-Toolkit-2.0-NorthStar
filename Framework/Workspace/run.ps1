# ============================================================
# WORKSPACE - FRAMEWORK 2.0
# Build 34G Workspace Graduation - First Run + Physical Storage
# ============================================================

$RootPath = (Resolve-Path "$PSScriptRoot\..\..").Path
$WorkspaceRoot = Join-Path $RootPath 'Workspace'
$ConfigRoot = Join-Path $RootPath 'Config'
$ItemsPath = Join-Path $ConfigRoot 'workspace_items.json'
$SettingsPath = Join-Path $ConfigRoot 'workspace_settings.json'
$WorkspaceConfigPath = Join-Path $ConfigRoot 'workspace.config.json'
$WorkspaceProfilesRoot = Join-Path $WorkspaceRoot 'Profiles'
$TemplatesPath = Join-Path $ConfigRoot 'workspace_templates.json'
$LogPath = Join-Path $RootPath 'Logs\framework_test.log'
$ReservedSections = @('Quick Access','Work','Personal')
$DefaultSections = @('Quick Access','Work','Personal')

function Write-TestLogLocal {
    param([string]$Action, [string]$Result = 'INFO', [string]$Details = '')
    try {
        $Logs = Join-Path $RootPath 'Logs'
        if (!(Test-Path $Logs)) { New-Item -ItemType Directory -Path $Logs -Force | Out-Null }
        $Stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        Add-Content -Path $LogPath -Value "$Stamp | $Result | Workspace | $Action | $Details" -Encoding UTF8
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

function Pause-Workspace {
    Write-Host ''
    Read-Host 'Press Enter to continue' | Out-Null
}

function Ensure-BaseFolders {
    if (!(Test-Path $ConfigRoot)) { New-Item -ItemType Directory -Path $ConfigRoot -Force | Out-Null }
    if (!(Test-Path $WorkspaceRoot)) { New-Item -ItemType Directory -Path $WorkspaceRoot -Force | Out-Null }
    if (!(Test-Path $WorkspaceProfilesRoot)) { New-Item -ItemType Directory -Path $WorkspaceProfilesRoot -Force | Out-Null }
    $Incoming = Join-Path $WorkspaceRoot 'Incoming'
    if (!(Test-Path $Incoming)) { New-Item -ItemType Directory -Path $Incoming -Force | Out-Null }
}


function Get-ActiveWorkspaceName {
    Ensure-BaseFolders
    if (Test-Path $WorkspaceConfigPath) {
        try {
            $Cfg = Get-Content $WorkspaceConfigPath -Raw | ConvertFrom-Json
            if ($Cfg.active_workspace) { return [string]$Cfg.active_workspace }
        } catch {}
    }
    if (Test-Path $SettingsPath) {
        try {
            $Old = Get-Content $SettingsPath -Raw | ConvertFrom-Json
            if ($Old.active_workspace) { return [string]$Old.active_workspace }
        } catch {}
    }
    return $null
}

function ConvertTo-SafeProfileName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $Clean = ($Name.Trim() -replace '[\\/:*?"<>|]+','_' -replace '\s+','_')
    $Clean = $Clean.Trim('_',' ')
    if ([string]::IsNullOrWhiteSpace($Clean)) { return $null }
    return $Clean
}

function Get-ActiveWorkspacePath {
    Ensure-BaseFolders
    $Name = Get-ActiveWorkspaceName
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    return (Join-Path $WorkspaceProfilesRoot $Name)
}

function Save-WorkspaceConfig {
    param([string]$ActiveWorkspace, [string]$LayoutName = '')
    Ensure-BaseFolders
    $Obj = [PSCustomObject]@{
        active_workspace = $ActiveWorkspace
        layout = $LayoutName
        version = '2.0'
        updated = (Get-Date).ToString('s')
    }
    $Obj | ConvertTo-Json -Depth 6 | Set-Content $WorkspaceConfigPath -Encoding UTF8
}

function Ensure-ActiveWorkspaceFolders {
    param([string]$ProfileName, [string[]]$Sections)
    Ensure-BaseFolders
    $SafeProfile = ConvertTo-SafeProfileName $ProfileName
    if (!$SafeProfile) { throw 'Workspace profile name is invalid.' }
    $ProfilePath = Join-Path $WorkspaceProfilesRoot $SafeProfile
    if (!(Test-Path $ProfilePath)) { New-Item -ItemType Directory -Path $ProfilePath -Force | Out-Null }
    foreach ($Section in $Sections) {
        if ([string]::IsNullOrWhiteSpace($Section)) { continue }
        if (!(Test-SafeName $Section)) { continue }
        $Path = Join-Path $ProfilePath $Section
        if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    }
    return $ProfilePath
}

function Get-WorkspaceIncomingPath {
    Ensure-BaseFolders
    return (Join-Path $WorkspaceRoot 'Incoming')
}

function Get-RepositoryRootPath {
    Ensure-BaseFolders
    $Path = Join-Path $RootPath 'Repository'
    if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    return $Path
}

function Get-ModulesRootPath {
    Ensure-BaseFolders
    $Path = Join-Path $RootPath 'Modules'
    if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    return $Path
}

function Get-LinkableWorkspaceSources {
    $Sources = @()
    $Repo = Get-RepositoryRootPath
    $Modules = Get-ModulesRootPath
    if (Test-Path $Repo) { $Sources += $Repo }
    if (Test-Path $Modules) { $Sources += $Modules }
    return @($Sources | Select-Object -Unique)
}

function ConvertTo-RelativeToolkitPath {
    param([string]$Path)
    try {
        $Full = (Resolve-Path $Path -ErrorAction Stop).Path
        if ($Full.StartsWith($RootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return ($Full.Substring($RootPath.Length).TrimStart('\','/') -replace '\\','/')
        }
        return $Full
    } catch { return $Path }
}

function Resolve-ToolkitPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $RootPath ($Path -replace '/', '\'))
}

function Read-WithDefault {
    param([string]$Prompt, [string]$Default)
    if ([string]::IsNullOrWhiteSpace($Default)) { return (Read-Host $Prompt) }
    $Value = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($Value)) { return $Default }
    return $Value
}

function Test-SafeName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    foreach ($Char in [System.IO.Path]::GetInvalidFileNameChars()) {
        if ($Name.Contains([string]$Char)) { return $false }
    }
    return $true
}

function ConvertTo-SafeId {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return ([guid]::NewGuid().ToString()) }
    $Id = (($Text.ToLower() -replace '[^a-z0-9]+','-').Trim('-'))
    if ([string]::IsNullOrWhiteSpace($Id)) { return ([guid]::NewGuid().ToString()) }
    return $Id
}

function Get-PropValue {
    param($Object, [string[]]$Names)
    if ($null -eq $Object) { return $null }
    foreach ($Name in $Names) {
        $Prop = $Object.PSObject.Properties[$Name]
        if ($Prop -and $null -ne $Prop.Value -and ![string]::IsNullOrWhiteSpace([string]$Prop.Value)) { return $Prop.Value }
    }
    return $null
}

function Get-DefaultWorkspaceTemplates {
    $List = New-Object System.Collections.ArrayList
    [void]$List.Add([PSCustomObject]@{
        name='IT Admin'
        description='General IT administration, tools, notes, documentation, printers, scripts, and support resources.'
        folders=@('Quick Access','Work','Personal','Notes','Files','Folders','Documentation','Printers','Scripts','Links')
    })
    [void]$List.Add([PSCustomObject]@{
        name='Network'
        description='Network troubleshooting, DNS, IP notes, switches, firewalls, Wi-Fi, and network documentation.'
        folders=@('Quick Access','Work','Personal','Notes','Files','Folders','Network','DNS','Switches','Firewalls','WiFi','Documentation')
    })
    [void]$List.Add([PSCustomObject]@{
        name='Server'
        description='Server administration, Active Directory, virtualization, backups, logs, and infrastructure notes.'
        folders=@('Quick Access','Work','Personal','Notes','Files','Folders','Servers','Active Directory','Virtualization','Backups','Logs','Documentation')
    })
    [void]$List.Add([PSCustomObject]@{
        name='Printer / Imaging'
        description='Printer support, drivers, supplies, print server notes, imaging, and deployment references.'
        folders=@('Quick Access','Work','Personal','Notes','Files','Folders','Printers','Drivers','Supplies','Print Server','Imaging','Documentation')
    })
    [void]$List.Add([PSCustomObject]@{
        name='Security'
        description='Security tools, endpoint notes, audit references, incident notes, and policy documentation.'
        folders=@('Quick Access','Work','Personal','Notes','Files','Folders','Security','Endpoint','Audit','Incidents','Policies','Documentation')
    })
    [void]$List.Add([PSCustomObject]@{
        name='Helpdesk'
        description='User support, common fixes, tickets, printers, applications, and troubleshooting notes.'
        folders=@('Quick Access','Work','Personal','Notes','Files','Folders','Users','Tickets','Printers','Applications','Troubleshooting','Documentation')
    })
    [void]$List.Add([PSCustomObject]@{
        name='AIO'
        description='Creates all standard workspace folders. Best for a full all-in-one profile.'
        folders=@('Quick Access','Work','Personal','Notes','Files','Folders','Documentation','Printers','Drivers','Supplies','Network','DNS','Switches','Firewalls','WiFi','Servers','Active Directory','Virtualization','Backups','Logs','Security','Endpoint','Audit','Incidents','Policies','Users','Tickets','Applications','Troubleshooting','Links','Scripts','Projects')
    })
    return $List
}

function Get-WorkspaceTemplates {
    # Use built-in validated templates as the safe source for first-run setup.
    # External template JSON can be supported later, but first-run must never show blank options.
    return (Get-DefaultWorkspaceTemplates)
}
function New-WorkspaceFolders {
    param([string[]]$Sections, [string]$ProfileName = '')
    Ensure-BaseFolders
    if ([string]::IsNullOrWhiteSpace($ProfileName)) { $ProfileName = Get-ActiveWorkspaceName }
    if ([string]::IsNullOrWhiteSpace($ProfileName)) { $ProfileName = 'Default' }
    [void](Ensure-ActiveWorkspaceFolders -ProfileName $ProfileName -Sections $Sections)
}

function Save-WorkspaceSettings {
    param([string]$TemplateName, [string]$ProfileName = '')
    Ensure-BaseFolders
    if ([string]::IsNullOrWhiteSpace($ProfileName)) { $ProfileName = Get-ActiveWorkspaceName }
    if ([string]::IsNullOrWhiteSpace($ProfileName)) { $ProfileName = 'Default' }
    Save-WorkspaceConfig -ActiveWorkspace $ProfileName -LayoutName $TemplateName
    $Settings = [PSCustomObject]@{
        initialized = $true
        active_workspace = $ProfileName
        template = $TemplateName
        created = (Get-Date).ToString('s')
        version = '2.0'
    }
    $Settings | ConvertTo-Json -Depth 6 | Set-Content $SettingsPath -Encoding UTF8
}

function Test-WorkspaceInitialized {
    Ensure-BaseFolders
    $Active = Get-ActiveWorkspaceName
    if ($Active) {
        $Path = Join-Path $WorkspaceProfilesRoot $Active
        if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        return $true
    }
    if (Test-Path $SettingsPath) {
        try {
            $Settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
            if ($Settings.initialized -eq $true -and $Settings.template) {
                $Profile = ConvertTo-SafeProfileName ([string]$Settings.template)
                if (!$Profile) { $Profile = 'Default' }
                New-WorkspaceFolders $DefaultSections $Profile
                Save-WorkspaceSettings ([string]$Settings.template) $Profile
                return $true
            }
        } catch {}
    }
    return $false
}

function Select-FromList {
    param(
        [string]$Title,
        [array]$Items,
        [string]$DisplayProperty = 'name',
        [switch]$AllowCustom,
        [string]$CustomLabel = 'Create New'
    )
    while ($true) {
        Show-Header $Title
        if (!$Items -or $Items.Count -eq 0) { Write-Host 'No items found.' -ForegroundColor Yellow; Write-Host '' }
        $Map = @{}
        $Index = 1
        foreach ($Item in $Items) {
            if ($Item -is [string]) { $Label = $Item }
            else {
                $Label = Get-PropValue $Item @($DisplayProperty,'name','Name','title','Title')
                if ([string]::IsNullOrWhiteSpace([string]$Label)) { $Label = [string]$Item }
            }
            Write-Host "[$Index] $Label"
            if (!($Item -is [string])) {
                $Desc = Get-PropValue $Item @('description','Description','purpose','Purpose')
                if ($Desc) { Write-Host "    $Desc" -ForegroundColor DarkGray }
            }
            $Map[[string]$Index] = $Item
            $Index++
        }
        if ($AllowCustom) { Write-Host "[C] $CustomLabel" }
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return $null }
        if ($AllowCustom -and $Choice.ToUpper() -eq 'C') { return '__CUSTOM__' }
        if ($Map.ContainsKey($Choice)) { return $Map[$Choice] }
    }
}

function Start-CustomWorkspaceSetup {
    param([string]$ProfileName = '')
    $Required = @('Quick Access','Work','Personal')
    $Optional = @('Notes','Projects','Scripts','Websites','Documentation','Customers','Servers','Networking','GitHub','Files','Folders','Printers','Security')
    $Selected = @{}
    foreach ($R in $Required) { $Selected[$R] = $true }
    foreach ($O in $Optional) { $Selected[$O] = $false }

    while ($true) {
        Show-Header 'CUSTOM WORKSPACE SETUP'
        Write-Host 'Toggle optional sections, then press D when done.'
        Write-Host ''
        Write-Host 'Required sections are always included:'
        Write-Host 'Quick Access, Work, Personal'
        Write-Host ''
        Write-Host 'Optional Sections'
        Write-Host '-----------------'
        $Map = @{}
        $Index = 1
        foreach ($Name in $Optional) {
            $Mark = if ($Selected[$Name]) { '[X]' } else { '[ ]' }
            Write-Host "[$Index] $Mark $Name"
            $Map[[string]$Index] = $Name
            $Index++
        }
        Write-Host ''
        Write-Host '[A] Select all optional sections'
        Write-Host '[D] Done'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch ($Choice.ToUpper()) {
            'B' { return $false }
            'A' { foreach ($Name in $Optional) { $Selected[$Name] = $true } }
            'D' {
                $Final = @()
                foreach ($Name in $Required) { $Final += $Name }
                foreach ($Name in ($Optional | Sort-Object)) { if ($Selected[$Name]) { $Final += $Name } }
                if ([string]::IsNullOrWhiteSpace($ProfileName)) { $ProfileName = 'Custom' }
                New-WorkspaceFolders $Final $ProfileName
                Save-WorkspaceSettings 'Custom' $ProfileName
                Write-TestLogLocal 'First setup' 'PASS' 'Custom Workspace'
                return $true
            }
            default {
                if ($Map.ContainsKey($Choice)) {
                    $Name = $Map[$Choice]
                    $Selected[$Name] = -not $Selected[$Name]
                }
            }
        }
    }
}

function Get-ExistingWorkspaceProfiles {
    Ensure-BaseFolders
    return @(Get-ChildItem $WorkspaceProfilesRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
}

function Prompt-WorkspaceProfileName {
    param([string]$DefaultName = '')
    Show-Header 'CREATE WORKSPACE PROFILE'
    Write-Host 'Workspace profiles keep shortcuts, notes, and links separate for each user/team.'
    Write-Host 'Workspace\Incoming is shared so any profile can link staged files/folders.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Profile Examples:'
    Write-Host '  Personal Name 1'
    Write-Host '  Personal Name 2'
    Write-Host '  Personal Name 3'
    Write-Host ''
    Write-Host '  IT_ADMIN'
    Write-Host '  HELPDESK'
    Write-Host '  NETWORK_TEAM'
    Write-Host '  STORE_SUPPORT'
    Write-Host ''
    $Name = Read-WithDefault 'Profile name' $DefaultName
    $Safe = ConvertTo-SafeProfileName $Name
    if (!$Safe) {
        Write-Host '[FAIL] Invalid profile name.' -ForegroundColor Red
        Pause-Workspace
        return $null
    }
    return $Safe
}

function Create-WorkspaceProfileFromLayout {
    param([string]$ProfileName, $Template)
    $LayoutName = Get-PropValue $Template @('name','Name')
    $Folders = @($Template.folders)
    if (!$Folders -or $Folders.Count -eq 0) { $Folders = $DefaultSections }
    Show-Header 'CREATE WORKSPACE PROFILE'
    Write-Host "Profile Name : $ProfileName"
    Write-Host "Starter Layout: $LayoutName"
    Write-Host ''
    Write-Host 'Workspace\Incoming is shared and will be available to every profile.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Profile folders to create:'
    foreach ($F in $Folders) { Write-Host "- $F" }
    Write-Host ''
    $Confirm = Read-Host 'Create/switch to this workspace profile? [Y/N]'
    if ($Confirm.ToUpper() -ne 'Y') { return $false }
    New-WorkspaceFolders $Folders $ProfileName
    Save-WorkspaceSettings $LayoutName $ProfileName
    Write-TestLogLocal 'Workspace profile' 'PASS' "$ProfileName / $LayoutName"
    Write-Host ''
    Write-Host "Active workspace profile: $ProfileName" -ForegroundColor Green
    Pause-Workspace
    return $true
}

function New-WorkspaceProfileWizard {
    param([string]$DefaultProfileName = '')
    $Templates = @(Get-WorkspaceTemplates)
    $ProfileName = Prompt-WorkspaceProfileName -DefaultName $DefaultProfileName
    if (!$ProfileName) { return $false }
    while ($true) {
        Show-Header 'CHOOSE STARTER LAYOUT'
        Write-Host "Profile Name: $ProfileName"
        Write-Host ''
        Write-Host 'Choose an IT-focused starter layout.' -ForegroundColor DarkGray
        Write-Host 'AIO creates all standard folders. Custom lets you choose folders manually.' -ForegroundColor DarkGray
        Write-Host ''
        $Map = @{}
        $Index = 1
        foreach ($Template in $Templates) {
            $Name = Get-PropValue $Template @('name','Name')
            $Desc = Get-PropValue $Template @('description','Description')
            Write-Host "[$Index] $Name"
            if ($Desc) { Write-Host "    $Desc" -ForegroundColor DarkGray }
            $Map[[string]$Index] = $Template
            $Index++
        }
        Write-Host "[$Index] Custom"
        Write-Host '    Choose folders manually. Use A inside Custom to select all folders.' -ForegroundColor DarkGray
        $CustomChoice = [string]$Index
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return $false }
        if ($Choice -eq $CustomChoice) { return (Start-CustomWorkspaceSetup -ProfileName $ProfileName) }
        if ($Map.ContainsKey($Choice)) { return (Create-WorkspaceProfileFromLayout -ProfileName $ProfileName -Template $Map[$Choice]) }
    }
}

function Start-WorkspaceProfileSelector {
    param([switch]$AllowBack)
    while ($true) {
        Ensure-BaseFolders
        $Current = Get-ActiveWorkspaceName
        if ([string]::IsNullOrWhiteSpace($Current)) { $Current = 'Not configured' }
        $Profiles = @(Get-ExistingWorkspaceProfiles)
        Show-Header 'WORKSPACE PROFILES'
        Write-Host "Current Workspace Profile: $Current"
        Write-Host ''
        Write-Host 'Profiles keep workspace links/notes separate when the USB is shared.' -ForegroundColor DarkGray
        Write-Host 'Workspace\Incoming is shared so any profile can link staged files/folders.' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '[1] Switch Workspace'
        Write-Host '    Choose an existing workspace profile.' -ForegroundColor DarkGray
        Write-Host '[2] Create New Workspace'
        Write-Host '    Name a profile, then choose IT Admin, Network, Server, Printer, Security, Helpdesk, AIO, or Custom.' -ForegroundColor DarkGray
        Write-Host '[3] Rename Workspace'
        Write-Host '    Rename the active workspace profile.' -ForegroundColor DarkGray
        Write-Host '[4] Delete Workspace'
        Write-Host '    Delete a non-active profile after confirmation.' -ForegroundColor DarkGray
        Write-Host '[O] Open Workspace Folder'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch ($Choice.ToUpper()) {
            '1' {
                if (!$Profiles -or $Profiles.Count -eq 0) { Write-Host 'No workspace profiles found.' -ForegroundColor Yellow; Pause-Workspace; continue }
                $Selected = Select-FromList -Title 'SWITCH WORKSPACE PROFILE' -Items $Profiles -DisplayProperty 'Name'
                if ($Selected) {
                    Save-WorkspaceSettings 'Existing Profile' $Selected.Name
                    Write-Host "Active workspace profile changed to: $($Selected.Name)" -ForegroundColor Green
                    Pause-Workspace
                    return $true
                }
            }
            '2' { if (New-WorkspaceProfileWizard) { return $true } }
            '3' {
                $Active = Get-ActiveWorkspaceName
                if (!$Active) { Write-Host 'No active profile to rename.' -ForegroundColor Yellow; Pause-Workspace; continue }
                $NewName = Prompt-WorkspaceProfileName -DefaultName $Active
                if (!$NewName -or $NewName -eq $Active) { continue }
                $OldPath = Join-Path $WorkspaceProfilesRoot $Active
                $NewPath = Join-Path $WorkspaceProfilesRoot $NewName
                if (Test-Path $NewPath) { Write-Host 'A profile with that name already exists.' -ForegroundColor Yellow; Pause-Workspace; continue }
                Rename-Item -Path $OldPath -NewName $NewName -ErrorAction Stop
                Save-WorkspaceSettings 'Renamed Profile' $NewName
                Write-Host "Workspace renamed to: $NewName" -ForegroundColor Green
                Pause-Workspace
            }
            '4' {
                $Profiles = @(Get-ExistingWorkspaceProfiles)
                if (!$Profiles -or $Profiles.Count -eq 0) { Write-Host 'No profiles found.' -ForegroundColor Yellow; Pause-Workspace; continue }
                $Selected = Select-FromList -Title 'DELETE WORKSPACE PROFILE' -Items $Profiles -DisplayProperty 'Name'
                if (!$Selected) { continue }
                $Active = Get-ActiveWorkspaceName
                if ($Selected.Name -eq $Active) { Write-Host 'Cannot delete the active workspace profile. Switch first.' -ForegroundColor Yellow; Pause-Workspace; continue }
                $Confirm = Read-Host "Delete workspace profile '$($Selected.Name)'? [Y/N]"
                if ($Confirm.ToUpper() -eq 'Y') { Remove-Item -Path $Selected.FullName -Recurse -Force; Write-Host 'Profile deleted.' -ForegroundColor Green; Pause-Workspace }
            }
            'O' { Start-Process $WorkspaceRoot }
            'B' { if ($AllowBack) { return $false } }
        }
    }
}

function Start-WorkspaceFirstRunSetup {
    Show-Header 'WORKSPACE SETUP - INTRODUCTION'
    Write-Host 'Workspace provides a personal area inside the toolkit.'
    Write-Host ''
    Write-Host 'Each workspace profile can have its own:'
    Write-Host '  - Notes'
    Write-Host '  - File Links'
    Write-Host '  - Folder Links'
    Write-Host '  - Module Links'
    Write-Host '  - Category Links'
    Write-Host ''
    Write-Host 'Profiles are isolated from each other.'
    Write-Host ''
    Write-Host 'Profile Examples:'
    Write-Host '  Personal Name 1'
    Write-Host '  Personal Name 2'
    Write-Host '  Personal Name 3'
    Write-Host ''
    Write-Host '  IT_ADMIN'
    Write-Host '  HELPDESK'
    Write-Host '  NETWORK_TEAM'
    Write-Host '  STORE_SUPPORT'
    Write-Host ''
    Write-Host 'Shared Area:'
    Write-Host '  Workspace\Incoming' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Files and folders placed in Incoming can be linked into any workspace profile.'
    Write-Host ''
    Write-Host 'You can create additional profiles later through:'
    Write-Host '  Workspace > Workspace Profiles' -ForegroundColor DarkGray
    Write-Host ''
    Pause-Workspace
    return (New-WorkspaceProfileWizard)
}

function Get-WorkspaceRecordFiles {
    Ensure-BaseFolders
    $ActivePath = Get-ActiveWorkspacePath
    if (!$ActivePath) { return @() }
    return @(Get-ChildItem $ActivePath -Recurse -Filter '*.workspace.json' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('.keep','.gitkeep') })
}

function Get-WorkspaceItems {
    $Items = @()
    foreach ($File in (Get-WorkspaceRecordFiles)) {
        try {
            $Obj = Get-Content $File.FullName -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($null -eq $Obj) { continue }
            $Section = Split-Path $File.Directory.FullName -Leaf
            if (!(Get-PropValue $Obj @('category','Category','section','Section'))) {
                $Obj | Add-Member -NotePropertyName category -NotePropertyValue $Section -Force
            }
            if (!(Get-PropValue $Obj @('id','Id'))) {
                $Name = Get-PropValue $Obj @('name','Name')
                $Type = Get-PropValue $Obj @('type','Type')
                $Obj | Add-Member -NotePropertyName id -NotePropertyValue (ConvertTo-SafeId "$Type-$Name") -Force
            }
            $Items += $Obj
        } catch {
            Write-TestLogLocal 'Read workspace item' 'WARN' $File.FullName
        }
    }
    return $Items
}

function Rebuild-WorkspaceIndex {
    try {
        $Items = @(Get-WorkspaceItems)
        $Json = ConvertTo-Json -InputObject $Items -Depth 12
        if ([string]::IsNullOrWhiteSpace($Json)) { $Json = '[]' }
        $Json | Set-Content $ItemsPath -Encoding UTF8
        Write-TestLogLocal 'Rebuild index' 'PASS' "$($Items.Count) items"
        return $true
    } catch {
        Write-TestLogLocal 'Rebuild index' 'FAIL' $_.Exception.Message
        return $false
    }
}

function Save-WorkspaceItem {
    param($Item)
    if ($null -eq $Item) { return $false }
    $Section = Get-PropValue $Item @('category','Category','section','Section')
    $Name = Get-PropValue $Item @('name','Name')
    $Type = Get-PropValue $Item @('type','Type')
    if ([string]::IsNullOrWhiteSpace([string]$Section)) { $Section = 'Quick Access' }
    if ([string]::IsNullOrWhiteSpace([string]$Name)) { throw 'Workspace item name is missing.' }
    if ([string]::IsNullOrWhiteSpace([string]$Type)) { throw 'Workspace item type is missing.' }
    if (!(Test-SafeName $Section)) { throw "Invalid workspace section: $Section" }

    $ActivePath = Get-ActiveWorkspacePath
    if (!$ActivePath) { throw 'No active workspace profile configured.' }
    $Folder = Join-Path $ActivePath $Section
    if (!(Test-Path $Folder)) { New-Item -ItemType Directory -Path $Folder -Force -ErrorAction Stop | Out-Null }
    $Id = Get-PropValue $Item @('id','Id')
    if ([string]::IsNullOrWhiteSpace([string]$Id)) { $Id = ConvertTo-SafeId "$Type-$Name" }
    $SafeFile = ConvertTo-SafeId $Id
    $ItemFile = Join-Path $Folder ("$SafeFile.workspace.json")
    $Item | ConvertTo-Json -Depth 12 | Set-Content $ItemFile -Encoding UTF8 -ErrorAction Stop
    return (Rebuild-WorkspaceIndex)
}

function Get-WorkspaceSections {
    Ensure-BaseFolders
    $Names = @()
    foreach ($R in $ReservedSections) { $Names += $R }
    $ActivePath = Get-ActiveWorkspacePath
    if ($ActivePath -and (Test-Path $ActivePath)) {
        $Dirs = @(Get-ChildItem $ActivePath -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        foreach ($D in $Dirs) {
            if ([string]::IsNullOrWhiteSpace($D)) { continue }
            if ($ReservedSections -contains $D) { continue }
            if ($Names -notcontains $D) { $Names += $D }
        }
    }
    $Other = @($Names | Where-Object { $ReservedSections -notcontains $_ } | Sort-Object)
    return @($ReservedSections + $Other)
}

function Select-WorkspaceSection {
    $Sections = @(Get-WorkspaceSections)
    $Selected = Select-FromList -Title 'SELECT WORKSPACE SECTION' -Items $Sections -AllowCustom -CustomLabel 'Create New Section'
    if ($null -eq $Selected) { return $null }
    if ($Selected -eq '__CUSTOM__') {
        Show-Header 'CREATE SECTION'
        Write-Host 'Examples:'
        Write-Host 'Customers'
        Write-Host 'Store Reports'
        Write-Host 'Projects'
        Write-Host 'VIP Users'
        Write-Host ''
        $New = Read-Host 'Section name'
        if (!(Test-SafeName $New)) {
            Write-Host ''
            Write-Host '[FAIL] Invalid section name. Avoid special characters such as < > : " / \ | ? *' -ForegroundColor Red
            Write-TestLogLocal 'Create section' 'FAIL' "Invalid section: $New"
            Pause-Workspace
            return $null
        }
        try {
            New-WorkspaceFolders @($New)
            Write-Host ''
            Write-Host "Workspace section created: $New" -ForegroundColor Green
            Write-TestLogLocal 'Create section' 'PASS' $New
            return $New
        } catch {
            Write-Host '[FAIL] Could not create section.' -ForegroundColor Red
            Write-TestLogLocal 'Create section' 'FAIL' $_.Exception.Message
            Pause-Workspace
            return $null
        }
    }
    return [string]$Selected
}

function Get-UserModules {
    $Modules = @()
    $RegistryPath = Join-Path $RootPath 'Cache\toolkit_registry.json'
    if (Test-Path $RegistryPath) {
        try {
            $All = @(Get-Content $RegistryPath -Raw | ConvertFrom-Json)
            foreach ($Item in $All) {
                $Path = [string](Get-PropValue $Item @('path','Path','relativePath','RelativePath'))
                $Scope = [string](Get-PropValue $Item @('module_scope','ModuleScope','scope','Scope'))
                $Hidden = Get-PropValue $Item @('hidden','Hidden')
                if ($Hidden -eq $true) { continue }
                if ($Path -like 'Modules*' -and $Scope -ne 'Framework') { $Modules += $Item }
            }
        } catch { Write-TestLogLocal 'Read module registry' 'WARN' $_.Exception.Message }
    }

    $ModulesRoot = Join-Path $RootPath 'Modules'
    if (Test-Path $ModulesRoot) {
        foreach ($ToolJson in @(Get-ChildItem $ModulesRoot -Recurse -Filter 'tool.json' -File -ErrorAction SilentlyContinue)) {
            try {
                $Obj = Get-Content $ToolJson.FullName -Raw | ConvertFrom-Json
                $RelFolder = $ToolJson.Directory.FullName.Substring($RootPath.Length).TrimStart('\','/') -replace '\\','/'
                $Name = Get-PropValue $Obj @('name','Name')
                if ([string]::IsNullOrWhiteSpace([string]$Name)) { $Name = $ToolJson.Directory.Name }
                $Exists = $false
                foreach ($M in $Modules) { if ((Get-ModuleNameValue $M) -eq $Name) { $Exists = $true } }
                if ($Exists) { continue }
                $Obj | Add-Member -NotePropertyName path -NotePropertyValue $RelFolder -Force
                $Obj | Add-Member -NotePropertyName folder -NotePropertyValue $ToolJson.Directory.Name -Force
                $Modules += $Obj
            } catch { Write-TestLogLocal 'Read module tool.json' 'WARN' $ToolJson.FullName }
        }
    }
    return @($Modules | Where-Object { Get-ModuleNameValue $_ } | Sort-Object @{ Expression = { Get-ModuleNameValue $_ } })
}

function Get-ModuleNameValue { param($Module) return [string](Get-PropValue $Module @('name','Name','title','Title','folder','Folder')) }
function Get-ModuleDescriptionValue { param($Module) return [string](Get-PropValue $Module @('description','Description','purpose','Purpose')) }
function Get-ModulePathValue { param($Module) return [string](Get-PropValue $Module @('path','Path','relativePath','RelativePath')) }
function Get-ModuleEntryValue { param($Module) $Entry = Get-PropValue $Module @('entry','Entry'); if ($Entry) { return [string]$Entry }; return 'run.bat' }
function Get-ModuleKeywordsValue { param($Module) $K = Get-PropValue $Module @('keywords','Keywords'); if ($K) { return @($K) }; return @() }

function Get-ModuleCategoryValue {
    param($Module)
    $Cat = Get-PropValue $Module @('category','Category','framework_category','FrameworkCategory','subcategory','Subcategory')
    if ($Cat) { return [string]$Cat }
    $Path = [string](Get-ModulePathValue $Module)
    if ($Path -match '^Modules[\/](.+?)[\/]') { return $Matches[1] }
    return 'Uncategorized'
}

function Select-ModuleCategory {
    $Categories = @(Get-UserModules | ForEach-Object { Get-ModuleCategoryValue $_ } | Where-Object { $_ } | Sort-Object -Unique)
    if (!$Categories -or $Categories.Count -eq 0) {
        Write-Host 'No module categories found.' -ForegroundColor Yellow
        Write-TestLogLocal 'Select module category' 'FAIL' 'No categories found'
        Pause-Workspace
        return $null
    }
    return (Select-FromList -Title 'SELECT MODULE CATEGORY' -Items $Categories)
}

function Select-ModuleFromCategory {
    param([string]$Category)
    $Modules = @(Get-UserModules | Where-Object { (Get-ModuleCategoryValue $_) -eq $Category } | Sort-Object @{ Expression = { Get-ModuleNameValue $_ } })
    if (!$Modules -or $Modules.Count -eq 0) {
        Write-Host 'No modules found in this category.' -ForegroundColor Yellow
        Pause-Workspace
        return $null
    }
    return (Select-FromList -Title 'SELECT MODULE' -Items $Modules -DisplayProperty 'name')
}

function Get-SuggestedKeywords {
    param([string]$Name, [string]$Description, [string]$Type, [string]$Category, [string]$Extra = '')
    $Stop = @('the','and','for','with','from','that','this','into','used','uses','use','your','you','are','can','will','tool','item','open','create','manage','local')
    $Text = "$Name $Description $Type $Category $Extra".ToLower()
    $Words = @($Text -split '[^a-z0-9]+' | Where-Object { $_ -and $_.Length -gt 2 -and ($Stop -notcontains $_) } | Select-Object -Unique)
    return @($Words | Select-Object -First 15)
}

function Confirm-Keywords {
    param([string[]]$Suggested)
    $Suggested = @($Suggested | Where-Object { $_ } | Select-Object -Unique)
    while ($true) {
        Show-Header 'SUGGESTED KEYWORDS'
        if ($Suggested.Count -gt 0) { foreach ($K in $Suggested) { Write-Host "- $K" } }
        else { Write-Host 'No keywords generated yet.' -ForegroundColor Yellow }
        Write-Host ''
        Write-Host '[A] Accept suggested keywords'
        Write-Host '[E] Edit keywords'
        Write-Host '[C] Add custom keywords'
        Write-Host '[S] Skip keywords'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch ($Choice.ToUpper()) {
            'A' { return @($Suggested) }
            'S' { return @() }
            'B' { return $null }
            'C' {
                Write-Host 'Examples: printer, toner, audit'
                $Custom = Read-Host 'Custom keywords, comma-separated'
                return @(@($Suggested) + @($Custom -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ }) | Select-Object -Unique)
            }
            'E' {
                Write-Host 'Examples: dns, network, troubleshooting'
                $Edited = Read-Host 'Final keywords, comma-separated'
                return @($Edited -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ } | Select-Object -Unique)
            }
        }
    }
}

function Test-IPv4Address {
    param([string]$Text)
    $IP = $null
    return [System.Net.IPAddress]::TryParse($Text, [ref]$IP)
}

function Normalize-WebsiteAddress {
    param([string]$InputText)
    $InputText = ($InputText -as [string]).Trim()
    if ([string]::IsNullOrWhiteSpace($InputText)) { return $null }
    if ($InputText -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
        $HostPart = ($InputText -split '/')[0]
        if (Test-IPv4Address $HostPart) { $InputText = "http://$InputText" }
        elseif ($HostPart -notmatch '\.') { $InputText = "http://$InputText" }
        else { $InputText = "https://$InputText" }
    }
    return $InputText
}

function Test-WebsiteAddress {
    param([string]$Address)
    $Normalized = Normalize-WebsiteAddress $Address
    if (!$Normalized) { return $null }
    $UriObj = $null
    $ValidUri = [System.Uri]::TryCreate($Normalized, [System.UriKind]::Absolute, [ref]$UriObj)
    $Messages = @()
    if (!$ValidUri) {
        $Messages += '[FAIL] Invalid URL format'
        return [PSCustomObject]@{ Address=$Normalized; UrlHost=''; IsValid=$false; Status='Invalid'; Messages=$Messages }
    }
    $UrlHost = $UriObj.Host
    $Messages += '[PASS] URL format valid'
    if (Test-IPv4Address $UrlHost) {
        $Reachable = $false
        try { $Reachable = Test-Connection -ComputerName $UrlHost -Count 1 -Quiet -ErrorAction SilentlyContinue } catch {}
        if ($Reachable) { $Messages += '[PASS] IP/host reachable by ping' }
        else { $Messages += '[WARN] IP/host did not respond to ping' }
        return [PSCustomObject]@{ Address=$Normalized; UrlHost=$UrlHost; IsValid=$true; Status='IP'; Messages=$Messages }
    }
    try {
        $null = Resolve-DnsName $UrlHost -ErrorAction Stop
        $Messages += '[PASS] DNS/hostname resolved'
    } catch {
        $Ping = $false
        try { $Ping = Test-Connection -ComputerName $UrlHost -Count 1 -Quiet -ErrorAction SilentlyContinue } catch {}
        if ($Ping) { $Messages += '[PASS] Host reachable by ping' }
        else { $Messages += '[WARN] Hostname/domain did not resolve or respond' }
    }
    return [PSCustomObject]@{ Address=$Normalized; UrlHost=$UrlHost; IsValid=$true; Status='Host'; Messages=$Messages }
}

function Prompt-WebsiteAddress {
    Show-Header 'ADD WEBSITE ADDRESS'
    Write-Host 'Examples:'
    Write-Host 'google.com'
    Write-Host 'https://google.com'
    Write-Host '10.10.100.1'
    Write-Host 'printserver'
    Write-Host ''
    $Raw = Read-Host 'Website address'
    $Result = Test-WebsiteAddress $Raw
    if (!$Result) { return $null }
    Show-Header 'WEBSITE ADDRESS CHECK'
    Write-Host "Final address: $($Result.Address)"
    Write-Host "Host         : $($Result.UrlHost)"
    Write-Host ''
    foreach ($Msg in $Result.Messages) { Write-Host $Msg }
    Write-Host ''
    if (!$Result.IsValid) { Pause-Workspace; return $null }
    $Save = Read-Host 'Save this address? [Y/N]'
    if ($Save.ToUpper() -ne 'Y') { return $null }
    return $Result.Address
}

function Start-WorkspaceModule {
    param($Module)
    if (!$Module) { return }
    $Rel = Get-ModulePathValue $Module
    $Folder = if ($Rel) { Join-Path $RootPath $Rel } else { $null }
    if (!$Folder) { Write-Host '[FAIL] Module path missing.' -ForegroundColor Red; Pause-Workspace; return }
    $Entry = Get-ModuleEntryValue $Module
    $EntryPath = Join-Path $Folder $Entry
    if (!(Test-Path $EntryPath)) { $EntryPath = Join-Path $Folder 'run.ps1' }
    if (!(Test-Path $EntryPath)) { $EntryPath = Join-Path $Folder 'run.bat' }
    if (!(Test-Path $EntryPath)) {
        Write-Host "[FAIL] Module entry not found: $(Get-ModuleNameValue $Module)" -ForegroundColor Red
        Write-TestLogLocal 'Launch module' 'FAIL' (Get-ModuleNameValue $Module)
        Pause-Workspace
        return
    }
    Write-TestLogLocal 'Launch module' 'INFO' (Get-ModuleNameValue $Module)
    if ($EntryPath.ToLower().EndsWith('.bat')) { Start-Process -FilePath $EntryPath -WorkingDirectory (Split-Path $EntryPath) -Wait }
    else { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $EntryPath }
}

function Show-CategoryLinkItems {
    param([string]$Category)
    while ($true) {
        Show-Header "WORKSPACE CATEGORY LINK - $Category"
        $Modules = @(Get-UserModules | Where-Object { (Get-ModuleCategoryValue $_) -eq $Category } | Sort-Object @{ Expression = { Get-ModuleNameValue $_ } })
        if (!$Modules -or $Modules.Count -eq 0) { Write-Host 'No modules found in this category.'; Write-Host '' }
        $Index = 1
        $Map = @{}
        foreach ($Module in $Modules) {
            $Name = Get-ModuleNameValue $Module
            $Desc = Get-ModuleDescriptionValue $Module
            Write-Host "[$Index] $Name"
            if ($Desc) { Write-Host "    $Desc" -ForegroundColor DarkGray }
            $Map[[string]$Index] = $Module
            $Index++
        }
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return }
        if ($Map.ContainsKey($Choice)) { Start-WorkspaceModule $Map[$Choice] }
    }
}

function Launch-WorkspaceItem {
    param($Item)
    if (!$Item) { return }
    $Type = [string](Get-PropValue $Item @('type','Type'))
    switch ($Type) {
        'module_link' {
            $Target = [string](Get-PropValue $Item @('target','Target'))
            $Name = [string](Get-PropValue $Item @('name','Name'))
            $Module = Get-UserModules | Where-Object { (Get-ModulePathValue $_) -eq $Target -or (Get-ModuleNameValue $_) -eq $Name } | Select-Object -First 1
            Start-WorkspaceModule $Module
        }
        'category_link' { Show-CategoryLinkItems ([string](Get-PropValue $Item @('target','Target'))) }
        'website' { $P = Get-PropValue $Item @('path','Path'); if ($P) { Start-Process $P } }
        'folder' { $P = Resolve-ToolkitPath (Get-PropValue $Item @('path','Path')); if ($P) { Start-Process $P } }
        'file' { $P = Resolve-ToolkitPath (Get-PropValue $Item @('path','Path')); if ($P) { Start-Process $P } }
        'script' {
            $P = [string](Get-PropValue $Item @('path','Path'))
            if ($P) {
                $Resolved = Resolve-ToolkitPath $P
                if ($Resolved.ToLower().EndsWith('.ps1')) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Resolved }
                else { Start-Process $Resolved }
            }
        }
        'note' {
            Show-Header "NOTE - $((Get-PropValue $Item @('name','Name')))"
            Write-Host (Get-PropValue $Item @('note','Note'))
            Pause-Workspace
        }
        default { $P = Get-PropValue $Item @('path','Path'); if ($P) { Start-Process $P } }
    }
}

function Show-WorkspaceCenter {
    while ($true) {
        Show-Header 'WORKSPACE CENTER'
        $Items = @(Get-WorkspaceItems)
        if (!$Items -or $Items.Count -eq 0) {
            Write-Host 'Workspace is empty.' -ForegroundColor Yellow
            Write-Host 'Use Workspace Manager to add items.'
            Write-Host ''
            Write-Host '[B] Back'
            $EmptyChoice = Read-Host 'Selection'
            if ($EmptyChoice.ToUpper() -eq 'B') { return }
            continue
        }
        $Sections = @(Get-WorkspaceSections)
        $Map = @{}
        $Index = 1
        foreach ($Section in $Sections) {
            $SectionItems = @($Items | Where-Object { (Get-PropValue $_ @('category','Category','section','Section')) -eq $Section } | Sort-Object @{ Expression = { Get-PropValue $_ @('name','Name') } })
            if ($SectionItems.Count -eq 0) { continue }
            Write-Host $Section
            Write-Host ('-' * $Section.Length)
            foreach ($Item in $SectionItems) {
                $Name = Get-PropValue $Item @('name','Name')
                $Desc = Get-PropValue $Item @('description','Description','purpose','Purpose')
                Write-Host "[$Index] $Name"
                if ($Desc) { Write-Host "    $Desc" -ForegroundColor DarkGray }
                $Map[[string]$Index] = $Item
                $Index++
            }
            Write-Host ''
        }
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return }
        if ($Map.ContainsKey($Choice)) { Launch-WorkspaceItem $Map[$Choice] }
    }
}

function Get-WorkspaceModuleDisplayName {
    param([System.IO.DirectoryInfo]$ModuleFolder)
    if (!$ModuleFolder) { return '' }
    $ToolJson = Join-Path $ModuleFolder.FullName 'tool.json'
    if (Test-Path $ToolJson) {
        try {
            $Json = Get-Content $ToolJson -Raw | ConvertFrom-Json
            if ($Json.name) { return [string]$Json.name }
        } catch {}
    }
    return ($ModuleFolder.Name -replace '_',' ')
}

function Get-LinkableCategoryName {
    param([string]$FullPath)
    $Rel = ConvertTo-RelativeToolkitPath $FullPath
    $Parts = @($Rel -split '[\\/]+' | Where-Object { $_ })
    if ($Parts.Count -ge 2 -and $Parts[0] -eq 'Repository') { return $Parts[1] }
    if ($Parts.Count -ge 1 -and $Parts[0] -eq 'Modules') { return 'Modules' }
    return ''
}

function New-LinkableWorkspaceObject {
    param(
        [object]$Item,
        [string]$DisplayName,
        [string]$Group,
        [string]$Kind,
        [string]$AdvancedName
    )
    return [PSCustomObject]@{
        item = $Item
        display = $DisplayName
        group = $Group
        kind = $Kind
        advanced = $AdvancedName
    }
}

function Get-LinkableWorkspaceItems {
    $Items = New-Object System.Collections.Generic.List[object]
    $Repo = Get-RepositoryRootPath
    $Modules = Get-ModulesRootPath

    # Modules are linkable as module folders only. Do not expose run.ps1, run.bat, tool.json, or README files here.
    if (Test-Path $Modules) {
        foreach ($Dir in @(Get-ChildItem $Modules -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('.keep','.gitkeep') } | Sort-Object Name)) {
            $Name = Get-WorkspaceModuleDisplayName $Dir
            $Advanced = "Modules > $($Dir.Name)"
            $Items.Add((New-LinkableWorkspaceObject -Item $Dir -DisplayName $Name -Group 'Modules' -Kind 'Folder' -AdvancedName $Advanced))
        }
    }

    if (Test-Path $Repo) {
        # Repository files are the primary linkable file targets.
        foreach ($File in @(Get-ChildItem $Repo -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('.keep','.gitkeep') } | Sort-Object FullName)) {
            $Category = Get-LinkableCategoryName $File.FullName
            if ([string]::IsNullOrWhiteSpace($Category)) { $Category = 'Repository Files' }
            $Advanced = if ($Category -and $Category -ne 'Repository Files') { "$Category > $($File.Name)" } else { $File.Name }
            $Items.Add((New-LinkableWorkspaceObject -Item $File -DisplayName $File.Name -Group $Category -Kind 'File' -AdvancedName $Advanced))
        }

        # Repository folders are linkable too, but hide plumbing folders that are not useful workspace targets.
        $TopCategories = @(Get-ChildItem $Repo -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.ToLowerInvariant() })
        foreach ($Dir in @(Get-ChildItem $Repo -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('.keep','.gitkeep','Current') } | Sort-Object FullName)) {
            if ($TopCategories -contains $Dir.FullName.ToLowerInvariant()) { continue }
            $Category = Get-LinkableCategoryName $Dir.FullName
            if ([string]::IsNullOrWhiteSpace($Category)) { $Category = 'Repository Folders' }
            $Advanced = if ($Category) { "$Category > $($Dir.Name)" } else { $Dir.Name }
            $Items.Add((New-LinkableWorkspaceObject -Item $Dir -DisplayName $Dir.Name -Group "$Category Folders" -Kind 'Folder' -AdvancedName $Advanced))
        }
    }

    return @($Items | Sort-Object group, display, advanced -Unique)
}

function Select-LinkableWorkspaceItem {
    while ($true) {
        Show-Header 'LINK FILE OR FOLDER'
        Write-Host 'Workspace links are portable when linked items stay inside the toolkit.' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'Workspace links are created from:'
        Write-Host '  Repository\' -ForegroundColor Yellow
        Write-Host '  Modules\' -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'Incoming\ is a temporary staging area and is not scanned for links.' -ForegroundColor DarkGray
        Write-Host 'Use Repository Manager or manually sort items into Repository\ first.' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'Choose what you want to link:' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '[1] Files'
        Write-Host '    Friendly file names only.' -ForegroundColor DarkGray
        Write-Host '    Example: QA_Test_xlsx.xlsx' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '[2] Advanced Files'
        Write-Host '    Show category/source context.' -ForegroundColor DarkGray
        Write-Host '    Example: Documents > QA_Test_xlsx.xlsx' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '[3] Folders'
        Write-Host '    Friendly folder/module names only.' -ForegroundColor DarkGray
        Write-Host '    Example: Check Winget or QA_Test_xlsx' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '[4] Advanced Folders'
        Write-Host '    Show category/source context.' -ForegroundColor DarkGray
        Write-Host '    Example: Modules > Check Winget or Documents > QA_Test_xlsx' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '[B] Back'
        Write-Host ''
        $ViewChoice = Read-Host 'Selection'
        if ($ViewChoice.ToUpper() -eq 'B') { return $null }
        if ($ViewChoice -notin @('1','2','3','4')) { continue }

        $WantFolders = $ViewChoice -in @('3','4')
        $AdvancedView = $ViewChoice -in @('2','4')
        $Title = switch ($ViewChoice) {
            '1' { 'LINK FILE - CLEAN VIEW' }
            '2' { 'LINK FILE - ADVANCED VIEW' }
            '3' { 'LINK FOLDER - CLEAN VIEW' }
            '4' { 'LINK FOLDER - ADVANCED VIEW' }
        }

        Show-Header $Title
        Write-Host 'Scanning Repository\ and Modules\ for linkable items...' -ForegroundColor Cyan
        Write-Host ''
        $Found = @(Get-LinkableWorkspaceItems | Where-Object {
            if ($WantFolders) { $_.kind -eq 'Folder' } else { $_.kind -eq 'File' }
        })

        if (!$Found -or $Found.Count -eq 0) {
            Write-Host ''
            if ($WantFolders) {
                Write-Host 'No linkable folders found in Repository\ or Modules\.' -ForegroundColor Yellow
            } else {
                Write-Host 'No linkable files found in Repository\.' -ForegroundColor Yellow
            }
            Write-Host ''
            Write-Host 'If the item is still in Incoming\, use Repository Manager or manually sort it into Repository\ first.'
            Write-Host ''
            Write-Host '[1] Open Repository Manager'
            Write-Host '[B] Back'
            Write-Host ''
            $EmptyChoice = Read-Host 'Selection'
            if ($EmptyChoice -eq '1') { Open-WorkspaceRepositoryManager }
            continue
        }

        $Summary = $Found | Group-Object group | Sort-Object Name
        Write-Host 'Found:' -ForegroundColor Cyan
        foreach ($G in $Summary) {
            Write-Host ("  {0,-20} {1}" -f ($G.Name + ':'), $G.Count)
        }
        Write-Host ''

        $Map = @{}
        $Index = 1
        $CurrentGroup = ''
        foreach ($Entry in $Found) {
            if ($Entry.group -ne $CurrentGroup) {
                $CurrentGroup = $Entry.group
                Write-Host "== $CurrentGroup ==" -ForegroundColor Cyan
            }
            $Label = if ($AdvancedView) { $Entry.advanced } else { $Entry.display }
            Write-Host "[$Index] $Label"
            $Map[[string]$Index] = $Entry.item
            $Index++
        }
        Write-Host ''
        Write-Host '[C] Change View'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return $null }
        if ($Choice.ToUpper() -eq 'C') { continue }
        if ($Map.ContainsKey($Choice)) { return $Map[$Choice] }
    }
}

function Select-IncomingItem {
    param([string]$Kind)
    # Compatibility wrapper for older internal calls. The new workspace linker uses one clean file/folder picker.
    $Selected = Select-LinkableWorkspaceItem
    if (!$Selected) { return $null }
    if ($Kind -eq 'File' -and $Selected.PSIsContainer) { return $null }
    if ($Kind -eq 'Folder' -and -not $Selected.PSIsContainer) { return $null }
    return $Selected
}

function Open-WorkspaceRepositoryManager {
    $RepoManager = Join-Path $RootPath 'Framework\Repository_Manager\run.bat'
    if (!(Test-Path $RepoManager)) {
        Write-Host 'Repository Manager was not found.' -ForegroundColor Red
        Pause-Workspace
        return
    }
    Write-Host ''
    Write-Host 'Opening Repository Manager...' -ForegroundColor Cyan
    & $RepoManager
}

function Add-WorkspaceItem {
    while ($true) {
        Show-Header 'ADD WORKSPACE ITEM'
        Write-Host 'Workspace is a personal shortcut layer.' -ForegroundColor DarkGray
        Write-Host 'Use Repository Manager or manually sort items into Repository\ before linking.' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'Item Type'
        Write-Host '---------'
        Write-Host '[1] Link File'
        Write-Host '    Scan Repository\ and Modules\ for files.' -ForegroundColor DarkGray
        Write-Host '[2] Link Folder'
        Write-Host '    Scan Repository\ and Modules\ for folders.' -ForegroundColor DarkGray
        Write-Host '[3] Add Note'
        Write-Host '    Store a personal note inside Workspace.' -ForegroundColor DarkGray
        Write-Host '[4] Link Existing Module'
        Write-Host '    Create a Workspace shortcut to a module created in Module Tool Manager.' -ForegroundColor DarkGray
        Write-Host '[5] Link Module Category'
        Write-Host '    Create a Workspace shortcut to a full module category.' -ForegroundColor DarkGray
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return }
        $TypeMap = @{ '1'='file'; '2'='folder'; '3'='note'; '4'='module_link'; '5'='category_link' }
        if (!$TypeMap.ContainsKey($Choice)) { continue }
        $Type = $TypeMap[$Choice]

        $Name = $null; $Description = $null; $Path = $null; $Note = $null; $Target = $null; $Keywords = @(); $ObjectType = $Type

        if ($Type -eq 'file') {
            $Selected = Select-IncomingItem -Kind 'File'
            if (!$Selected) { continue }
            $Name = Read-WithDefault 'Workspace display name' ([IO.Path]::GetFileNameWithoutExtension($Selected.Name))
            $Description = Read-WithDefault 'Description' "Linked file from $((ConvertTo-RelativeToolkitPath $Selected.FullName)): $($Selected.Name)"
            $Path = ConvertTo-RelativeToolkitPath $Selected.FullName
            $ObjectType = 'File'
            $Keywords = @(Get-SuggestedKeywords -Name $Name -Description $Description -Type 'File' -Category '' -Extra $Selected.Extension)
        } elseif ($Type -eq 'folder') {
            $Selected = Select-IncomingItem -Kind 'Folder'
            if (!$Selected) { continue }
            $Name = Read-WithDefault 'Workspace display name' $Selected.Name
            $Description = Read-WithDefault 'Description' "Linked folder from $((ConvertTo-RelativeToolkitPath $Selected.FullName)): $($Selected.Name)"
            $Path = ConvertTo-RelativeToolkitPath $Selected.FullName
            $ObjectType = 'Folder'
            $Keywords = @(Get-SuggestedKeywords -Name $Name -Description $Description -Type 'Folder' -Category '' -Extra $Selected.Name)
        } elseif ($Type -eq 'module_link') {
            $ModuleCategory = Select-ModuleCategory
            if (!$ModuleCategory) { continue }
            $Module = Select-ModuleFromCategory $ModuleCategory
            if (!$Module) { continue }
            $Name = Get-ModuleNameValue $Module
            $Description = Get-ModuleDescriptionValue $Module
            $Target = Get-ModulePathValue $Module
            $ObjectType = 'Module Link'
            $Keywords = @(Get-ModuleKeywordsValue $Module)
            if (!$Keywords -or $Keywords.Count -eq 0) { $Keywords = @(Get-SuggestedKeywords -Name $Name -Description $Description -Type 'Module' -Category $ModuleCategory) }
        } elseif ($Type -eq 'category_link') {
            $CategoryTarget = Select-ModuleCategory
            if (!$CategoryTarget) { continue }
            $Name = $CategoryTarget
            $Description = "Open modules in the $CategoryTarget category."
            $Target = $CategoryTarget
            $ObjectType = 'Category Link'
            $Keywords = @(Get-SuggestedKeywords -Name $Name -Description $Description -Type 'Category' -Category $CategoryTarget)
        } elseif ($Type -eq 'note') {
            Show-Header 'ADD NOTE'
            Write-Host 'Examples: Store contacts, Printer notes, Project notes'
            Write-Host ''
            $Name = Read-Host 'Note name'
            if ([string]::IsNullOrWhiteSpace($Name)) { continue }
            $Description = Read-WithDefault 'Description' "Personal note: $Name"
            $Note = Read-Host 'Note text'
            $ObjectType = 'Note'
            $Keywords = @(Get-SuggestedKeywords -Name $Name -Description $Description -Type 'Note' -Category '' -Extra $Note)
        }

        if ($Type -in @('file','folder','note')) {
            $Keywords = Confirm-Keywords $Keywords
            if ($null -eq $Keywords) { continue }
        }

        $Section = Select-WorkspaceSection
        if ([string]::IsNullOrWhiteSpace($Section)) { continue }

        $Item = [PSCustomObject]@{
            id = ConvertTo-SafeId "$Type-$Name"
            name = $Name
            description = $Description
            type = $Type
            object_type = $ObjectType
            category = $Section
            path = $Path
            target = $Target
            note = $Note
            keywords = @($Keywords)
            created = (Get-Date).ToString('s')
        }

        try {
            $Saved = Save-WorkspaceItem -Item $Item
            if ($Saved) {
                Write-Host ''
                Write-Host "Workspace item added: $Name" -ForegroundColor Green
                Write-TestLogLocal 'Add item' 'PASS' "$Name [$ObjectType] -> $Section"
            } else {
                Write-Host ''
                Write-Host '[FAIL] Workspace item could not be indexed. Item was not confirmed.' -ForegroundColor Red
                Write-TestLogLocal 'Add item' 'FAIL' "$Name index failed"
            }
        } catch {
            Write-Host ''
            Write-Host '[FAIL] Workspace item was not added.' -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-TestLogLocal 'Add item' 'FAIL' $_.Exception.Message
        }
        Pause-Workspace
        return
    }
}


function Get-SuggestedWorkspaceSection {
    param([System.IO.FileInfo]$File)
    $Ext = $File.Extension.ToLower()
    switch ($Ext) {
        '.ps1' { return 'Scripts' }
        '.bat' { return 'Scripts' }
        '.cmd' { return 'Scripts' }
        '.url' { return 'Websites' }
        '.lnk' { return 'Quick Access' }
        '.md' { return 'Notes' }
        '.txt' { return 'Notes' }
        '.json' { return 'Documentation' }
        '.pdf' { return 'Files' }
        '.docx' { return 'Files' }
        default { return 'Files' }
    }
}

function Sort-WorkspaceIncoming {
    while ($true) {
        Ensure-BaseFolders
        $Incoming = Join-Path $WorkspaceRoot 'Incoming'
        if (!(Test-Path $Incoming)) { New-Item -ItemType Directory -Path $Incoming -Force | Out-Null }
        Show-Header 'SORT WORKSPACE INCOMING'
        $Files = @(Get-ChildItem $Incoming -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('.keep','.gitkeep') } | Sort-Object Name)
        if (!$Files -or $Files.Count -eq 0) {
            Write-Host 'No incoming files found.'
            Write-Host ''
            Write-Host '[B] Back'
            $NoneChoice = Read-Host 'Selection'
            if ($NoneChoice.ToUpper() -eq 'B') { return }
            continue
        }
        $Index = 1; $Map = @{}
        foreach ($File in $Files) {
            $Suggested = Get-SuggestedWorkspaceSection $File
            Write-Host "[$Index] $($File.Name) -> Suggested: $Suggested"
            $Map[[string]$Index] = $File
            $Index++
        }
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Select file'
        if ($Choice.ToUpper() -eq 'B') { return }
        if (!$Map.ContainsKey($Choice)) { continue }
        $File = $Map[$Choice]
        $SuggestedSection = Get-SuggestedWorkspaceSection $File
        Show-Header 'SORT WORKSPACE ITEM'
        Write-Host "File      : $($File.Name)"
        Write-Host "Suggested : $SuggestedSection"
        Write-Host ''
        Write-Host '[Y] Move to suggested section'
        Write-Host '[C] Choose section'
        Write-Host '[S] Skip'
        Write-Host '[B] Back'
        $MoveChoice = Read-Host 'Selection'
        if ($MoveChoice.ToUpper() -eq 'B') { continue }
        if ($MoveChoice.ToUpper() -eq 'S') { continue }
        if ($MoveChoice.ToUpper() -eq 'Y') { $Section = $SuggestedSection }
        elseif ($MoveChoice.ToUpper() -eq 'C') { $Section = Select-WorkspaceSection }
        else { continue }
        if (!$Section) { continue }
        $ActivePath = Get-ActiveWorkspacePath
        if (!$ActivePath) { Write-Host 'No active workspace profile configured.' -ForegroundColor Red; Pause-Workspace; continue }
        $DestFolder = Join-Path $ActivePath $Section
        if (!(Test-Path $DestFolder)) { New-Item -ItemType Directory -Path $DestFolder -Force | Out-Null }
        $Dest = Join-Path $DestFolder $File.Name
        Move-Item -Path $File.FullName -Destination $Dest -Force
        Write-TestLogLocal 'Sort incoming' 'PASS' "$($File.Name) -> $Section"
        Write-Host "Moved to: $Section" -ForegroundColor Green
        Pause-Workspace
    }
}

function Show-WorkspaceHelp {
    while ($true) {
        Show-Header 'WORKSPACE HELP'
        Write-Host 'Workspace is a personal shortcut area inside the toolkit.'
        Write-Host ''
        Write-Host 'Workspace can store/link:'
        Write-Host '- Notes'
        Write-Host '- File Links'
        Write-Host '- Folder Links'
        Write-Host '- Module Links'
        Write-Host '- Category Links'
        Write-Host ''
        Write-Host 'Workspace does not store modules. Create runnable scripts, websites, and installers as Modules.'
        Write-Host ''
        Write-Host 'Repository workflow:'
        Write-Host '  Incoming\ -> Repository Manager or manual sort -> Repository\'
        Write-Host ''
        Write-Host 'Workspace links can point to:'
        Write-Host '  Repository\'
        Write-Host '  Modules\'
        Write-Host ''
        Write-Host 'Profiles are isolated:'
        Write-Host '  Workspace\Profiles\<ProfileName>'
        Write-Host ''
        
        Write-Host '[O] Open full workspace guide'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        if ($Choice.ToUpper() -eq 'B') { return }
        if ($Choice.ToUpper() -eq 'O') {
            $Guide = Join-Path $RootPath 'Docs\Workspace_Guide.md'
            if (Test-Path $Guide) { Start-Process $Guide } else { Write-Host 'Guide not found.'; Pause-Workspace }
        }
    }
}

function Show-WorkspaceManager {
    while ($true) {
        Ensure-BaseFolders
        Show-Header 'WORKSPACE MANAGER'
        $ActiveProfile = Get-ActiveWorkspaceName
        if ([string]::IsNullOrWhiteSpace($ActiveProfile)) { $ActiveProfile = 'Not configured' }
        Write-Host "Current Profile: $ActiveProfile"
        Write-Host ''
        Write-Host 'Workspace is a personal shortcut area.' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'Use Repository Manager or manually sort items into:'
        Write-Host '  Repository\' -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'Workspace links can be created from:'
        Write-Host '  Repository\' -ForegroundColor Yellow
        Write-Host '  Modules\' -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'Use Open Workspace Folder to access your personal workspace.' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '[O] Open Workspace Folder'
        Write-Host ''
        Write-Host '[1] Link File or Folder'
        Write-Host '    Scan Repository\ and Modules\ for linkable items.' -ForegroundColor DarkGray
        Write-Host '[2] Link Existing Module'
        Write-Host '    Create a shortcut to a module.' -ForegroundColor DarkGray
        Write-Host '[3] Link Module Category'
        Write-Host '    Create a shortcut to a module category.' -ForegroundColor DarkGray
        Write-Host '[4] Add Note'
        Write-Host '    Store personal notes.' -ForegroundColor DarkGray
        Write-Host '[5] Open Repository Manager'
        Write-Host '    Sort files from Incoming\ into Repository\ before linking.' -ForegroundColor DarkGray
        Write-Host '[R] Rebuild Workspace Index'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch ($Choice.ToUpper()) {
            'O' { Start-Process $WorkspaceRoot }
            '1' {
                $Selected = Select-LinkableWorkspaceItem
                if ($Selected) {
                    $IsFolder = $Selected.PSIsContainer
                    $ItemType = if ($IsFolder) { 'folder' } else { 'file' }
                    $ObjectType = if ($IsFolder) { 'Folder' } else { 'File' }
                    $DefaultName = if ($IsFolder) { $Selected.Name } else { [IO.Path]::GetFileNameWithoutExtension($Selected.Name) }
                    $Name = Read-WithDefault 'Workspace display name' $DefaultName
                    $Description = Read-WithDefault 'Description' "Linked $ItemType from $((ConvertTo-RelativeToolkitPath $Selected.FullName)): $($Selected.Name)"
                    $Extra = if ($IsFolder) { $Selected.Name } else { $Selected.Extension }
                    $Keywords = Confirm-Keywords @(Get-SuggestedKeywords -Name $Name -Description $Description -Type $ObjectType -Category '' -Extra $Extra)
                    if ($null -eq $Keywords) { continue }
                    $Section = Select-WorkspaceSection
                    if (!$Section) { continue }
                    $Item = [PSCustomObject]@{ id=ConvertTo-SafeId "$ItemType-$Name"; name=$Name; description=$Description; type=$ItemType; object_type=$ObjectType; category=$Section; path=(ConvertTo-RelativeToolkitPath $Selected.FullName); target=$null; note=$null; keywords=@($Keywords); created=(Get-Date).ToString('s') }
                    try { [void](Save-WorkspaceItem $Item); Write-Host "Workspace $ItemType link added: $Name" -ForegroundColor Green } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
                    Pause-Workspace
                }
            }
            '2' {
                $ModuleCategory = Select-ModuleCategory
                if (!$ModuleCategory) { continue }
                $Module = Select-ModuleFromCategory $ModuleCategory
                if (!$Module) { continue }
                $Name = Get-ModuleNameValue $Module
                $Description = Get-ModuleDescriptionValue $Module
                $Section = Select-WorkspaceSection
                if (!$Section) { continue }
                $Item = [PSCustomObject]@{ id=ConvertTo-SafeId "module-$Name"; name=$Name; description=$Description; type='module_link'; object_type='Module Link'; category=$Section; path=$null; target=(Get-ModulePathValue $Module); note=$null; keywords=@(Get-ModuleKeywordsValue $Module); created=(Get-Date).ToString('s') }
                try { [void](Save-WorkspaceItem $Item); Write-Host "Workspace module link added: $Name" -ForegroundColor Green } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
                Pause-Workspace
            }
            '3' {
                $CategoryTarget = Select-ModuleCategory
                if (!$CategoryTarget) { continue }
                $Name = $CategoryTarget
                $Description = "Open modules in the $CategoryTarget category."
                $Keywords = @(Get-SuggestedKeywords -Name $Name -Description $Description -Type 'Category' -Category $CategoryTarget)
                $Section = Select-WorkspaceSection
                if (!$Section) { continue }
                $Item = [PSCustomObject]@{ id=ConvertTo-SafeId "category-$Name"; name=$Name; description=$Description; type='category_link'; object_type='Category Link'; category=$Section; path=$null; target=$CategoryTarget; note=$null; keywords=@($Keywords); created=(Get-Date).ToString('s') }
                try { [void](Save-WorkspaceItem $Item); Write-Host "Workspace category link added: $Name" -ForegroundColor Green } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
                Pause-Workspace
            }
            '4' { 
                Show-Header 'ADD NOTE'
                $Name = Read-Host 'Note name'
                if ([string]::IsNullOrWhiteSpace($Name)) { continue }
                $Description = Read-WithDefault 'Description' "Personal note: $Name"
                $Note = Read-Host 'Note text'
                $Keywords = Confirm-Keywords @(Get-SuggestedKeywords -Name $Name -Description $Description -Type 'Note' -Category '' -Extra $Note)
                if ($null -eq $Keywords) { continue }
                $Section = Select-WorkspaceSection
                if (!$Section) { continue }
                $Item = [PSCustomObject]@{ id=ConvertTo-SafeId "note-$Name"; name=$Name; description=$Description; type='note'; object_type='Note'; category=$Section; path=$null; target=$null; note=$Note; keywords=@($Keywords); created=(Get-Date).ToString('s') }
                try { [void](Save-WorkspaceItem $Item); Write-Host "Workspace note added: $Name" -ForegroundColor Green } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
                Pause-Workspace
            }
            '5' { Open-WorkspaceRepositoryManager; Pause-Workspace }
            'R' { if (Rebuild-WorkspaceIndex) { Write-Host 'Workspace index rebuilt.' -ForegroundColor Green } else { Write-Host '[FAIL] Index rebuild failed.' -ForegroundColor Red }; Pause-Workspace }
            'B' { Write-TestLogLocal 'Back' 'PASS' 'Workspace Manager -> Workspace'; return }
        }
    }
}


function Show-WorkspaceMain {
    Ensure-BaseFolders
    Write-TestLogLocal 'Open Workspace' 'INFO' 'Workspace launched'
    if (!(Test-WorkspaceInitialized)) {
        $SetupDone = Start-WorkspaceFirstRunSetup
        if (!$SetupDone) { return }
    }
    while ($true) {
        Show-Header 'WORKSPACE'
        Write-Host '[1] Workspace Center'
        Write-Host '    Open personal workspace items and shortcuts.' -ForegroundColor DarkGray
        Write-Host '[2] Workspace Manager'
        Write-Host '    Create, organize, sort, and maintain workspace items.' -ForegroundColor DarkGray
        Write-Host '[3] Workspace Profiles'
        Write-Host '    Switch, create, rename, or delete workspace profiles.' -ForegroundColor DarkGray
        Write-Host '[4] Workspace Help'
        Write-Host '    Learn what Workspace is and how to set it up.' -ForegroundColor DarkGray
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch ($Choice.ToUpper()) {
            '1' { Show-WorkspaceCenter }
            '2' { Show-WorkspaceManager }
            '3' { [void](Start-WorkspaceProfileSelector -AllowBack) }
            '4' { Show-WorkspaceHelp }
            'B' { Write-TestLogLocal 'Back' 'PASS' 'Workspace -> Main Menu'; return }
        }
    }
}

Show-WorkspaceMain
