# ============================================================
# WINDOWS MODULAR TOOLKIT - REBUILD TOOLKIT CACHE
# Framework Edition 2.0
# ============================================================

$ErrorActionPreference = 'Stop'

function Show-Header {
    param([string]$Title)
    Clear-Host
    Write-Host '============================================================'
    Write-Host (' ' + $Title)
    Write-Host '============================================================'
    Write-Host ''
}

function Convert-ToolkitBoolean {
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

function Get-Prop {
    param($Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Value = $Object.$Name
        if ($null -ne $Value) { return $Value }
    }
    return $Default
}

function Get-ArrayProp {
    param($Object, [string]$Name)
    $Value = Get-Prop $Object $Name @()
    if ($null -eq $Value) { return @() }
    return @($Value)
}

function Convert-ToSafeRelativePath {
    param([string]$BasePath, [string]$FullPath)
    try {
        $Base = (Resolve-Path $BasePath).Path.TrimEnd('\') + '\'
        $Full = (Resolve-Path $FullPath).Path
        if ($Full.StartsWith($Base, [System.StringComparison]::OrdinalIgnoreCase)) {
            return ($Full.Substring($Base.Length) -replace '\\','/')
        }
    } catch {}
    return ($FullPath -replace '\\','/')
}

function New-RegistryItemFromToolJson {
    param(
        [string]$ToolkitRoot,
        [string]$Scope,
        [string]$FolderPath,
        [object]$OldItem = $null
    )

    $ToolJsonPath = Join-Path $FolderPath 'tool.json'
    if (-not (Test-Path $ToolJsonPath)) { return $null }

    try {
        $Json = Get-Content -Path $ToolJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Host "WARN: Invalid JSON skipped: $ToolJsonPath" -ForegroundColor Yellow
        return $null
    }

    $FolderName = Split-Path $FolderPath -Leaf
    $IsFramework = ($Scope -eq 'Framework')

    $Name = [string](Get-Prop $Json 'name' $FolderName)
    if ([string]::IsNullOrWhiteSpace($Name)) { $Name = $FolderName }

    $Category = [string](Get-Prop $Json 'category' 'Uncategorized')
    if ([string]::IsNullOrWhiteSpace($Category)) { $Category = 'Uncategorized' }

    $Description = [string](Get-Prop $Json 'description' '')
    if ([string]::IsNullOrWhiteSpace($Description)) { $Description = "Runs $Name." }

    $Entry = [string](Get-Prop $Json 'entry' 'run.bat')
    if ([string]::IsNullOrWhiteSpace($Entry)) { $Entry = 'run.bat' }

    $Result = [ordered]@{
        name = $Name
        category = $Category
        subcategory = [string](Get-Prop $Json 'subcategory' '')
        description = $Description
        keywords = @(Get-ArrayProp $Json 'keywords')
        risk = [string](Get-Prop $Json 'risk' 'Safe')
        estimated_time = [string](Get-Prop $Json 'estimated_time' 'Instant')
        requires_admin = Convert-ToolkitBoolean (Get-Prop $Json 'requires_admin' $false) $false
        entry = $Entry
        dependencies = @(Get-ArrayProp $Json 'dependencies')
        author = [string](Get-Prop $Json 'author' 'Toolkit User')
        version = [string](Get-Prop $Json 'version' '1.0')
        supports_logs = Convert-ToolkitBoolean (Get-Prop $Json 'supports_logs' $false) $false
        supports_export = Convert-ToolkitBoolean (Get-Prop $Json 'supports_export' $false) $false
        important = Convert-ToolkitBoolean (Get-Prop $Json 'important' $false) $false
        hidden = Convert-ToolkitBoolean (Get-Prop $Json 'hidden' $false) $false
        module_scope = $(if ($IsFramework) { 'Framework' } else { 'User' })
        framework_protected = $(if ($IsFramework) { $true } else { Convert-ToolkitBoolean (Get-Prop $Json 'framework_protected' $false) $false })
        allow_delete = $(if ($IsFramework) { $false } else { Convert-ToolkitBoolean (Get-Prop $Json 'allow_delete' $true) $true })
        allow_rename = $(if ($IsFramework) { $false } else { Convert-ToolkitBoolean (Get-Prop $Json 'allow_rename' $true) $true })
        allow_move = $(if ($IsFramework) { $false } else { Convert-ToolkitBoolean (Get-Prop $Json 'allow_move' $true) $true })
        folder = $FolderName
        path = Convert-ToSafeRelativePath -BasePath $ToolkitRoot -FullPath $FolderPath
    }

    if ($IsFramework) {
        $Result.framework_priority = [string](Get-Prop $Json 'framework_priority' (Get-Prop $OldItem 'framework_priority' 'Medium'))
        $Result.framework_category = [string](Get-Prop $Json 'framework_category' (Get-Prop $OldItem 'framework_category' 'General'))
    }

    return [pscustomobject]$Result
}

function Get-CuratedFrameworkFolders {
    param([string]$RegistryPath)
    $Folders = @()
    if (Test-Path $RegistryPath) {
        try {
            $OldRegistry = @(Get-Content -Path $RegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json)
            $Folders = @(
                $OldRegistry |
                Where-Object { $_.module_scope -eq 'Framework' -or $_.framework_protected -eq $true } |
                ForEach-Object { [string]$_.folder } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Sort-Object -Unique
            )
        } catch {}
    }
    return @($Folders)
}

function Rebuild-ToolkitCache {
    param([string]$ToolkitRoot)

    $CacheRoot = Join-Path $ToolkitRoot 'Cache'
    $FrameworkRoot = Join-Path $ToolkitRoot 'Framework'
    $ModulesRoot = Join-Path $ToolkitRoot 'Modules'
    $RegistryPath = Join-Path $CacheRoot 'toolkit_registry.json'

    if (-not (Test-Path $CacheRoot)) { New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null }

    if (Test-Path $RegistryPath) {
        $Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        Copy-Item -Path $RegistryPath -Destination (Join-Path $CacheRoot "toolkit_registry.backup_$Stamp.json") -Force
    }

    $OldRegistry = @()
    if (Test-Path $RegistryPath) {
        try { $OldRegistry = @(Get-Content -Path $RegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $OldRegistry = @() }
    }

    $Items = New-Object System.Collections.Generic.List[object]

    # Preserve the curated framework component list when an existing cache is available.
    # This keeps Framework Components stable while refreshing live metadata from tool.json.
    $CuratedFrameworkFolders = @(Get-CuratedFrameworkFolders -RegistryPath $RegistryPath)
    if ($CuratedFrameworkFolders.Count -eq 0 -and (Test-Path $FrameworkRoot)) {
        $CuratedFrameworkFolders = @(Get-ChildItem -Path $FrameworkRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name } | Sort-Object)
    }

    foreach ($FolderName in $CuratedFrameworkFolders) {
        $FolderPath = Join-Path $FrameworkRoot $FolderName
        if (-not (Test-Path $FolderPath)) { continue }
        $OldItem = $OldRegistry | Where-Object { $_.folder -eq $FolderName } | Select-Object -First 1
        $Item = New-RegistryItemFromToolJson -ToolkitRoot $ToolkitRoot -Scope 'Framework' -FolderPath $FolderPath -OldItem $OldItem
        if ($null -ne $Item) { [void]$Items.Add($Item) }
    }

    if (Test-Path $ModulesRoot) {
        foreach ($Folder in @(Get-ChildItem -Path $ModulesRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
            $Item = New-RegistryItemFromToolJson -ToolkitRoot $ToolkitRoot -Scope 'User' -FolderPath $Folder.FullName
            if ($null -ne $Item) { [void]$Items.Add($Item) }
        }
    }

    $Sorted = @($Items | Sort-Object @{Expression={ if ($_.module_scope -eq 'Framework') { 0 } else { 1 } }}, category, name)
    $Sorted | ConvertTo-Json -Depth 20 | Set-Content -Path $RegistryPath -Encoding UTF8

    $FrameworkCount = @($Sorted | Where-Object { $_.module_scope -eq 'Framework' -or $_.framework_protected -eq $true }).Count
    $ModuleItems = @($Sorted | Where-Object { $_.module_scope -ne 'Framework' -and $_.framework_protected -ne $true })
    $VisibleModules = @($ModuleItems | Where-Object { $_.hidden -ne $true })
    $CategoryCount = @($VisibleModules | ForEach-Object { [string]$_.category } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique).Count

    return [pscustomobject]@{
        RegistryPath = $RegistryPath
        FrameworkComponents = $FrameworkCount
        AvailableModules = $VisibleModules.Count
        ModuleCategories = $CategoryCount
        TotalRegistryItems = $Sorted.Count
    }
}

try {
    $ToolFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ToolkitRoot = Resolve-Path (Join-Path $ToolFolder '..\..')

    Show-Header 'REBUILD TOOLKIT CACHE'

    Write-Host 'Scanning live Framework and Modules folders...'
    Write-Host ''

    $Result = Rebuild-ToolkitCache -ToolkitRoot $ToolkitRoot.Path

    Write-Host 'Toolkit cache rebuilt successfully.' -ForegroundColor Green
    Write-Host ''
    Write-Host ('Framework Components : ' + $Result.FrameworkComponents)
    Write-Host ('Available Modules    : ' + $Result.AvailableModules)
    Write-Host ('Module Categories    : ' + $Result.ModuleCategories)
    Write-Host ('Total Registry Items : ' + $Result.TotalRegistryItems)
    Write-Host ''
    Write-Host ('Registry: ' + $Result.RegistryPath)
    Write-Host ''
}
catch {
    Write-Host ''
    Write-Host 'Toolkit cache rebuild failed.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
}

Write-Host 'Press Enter to return.'
[void][System.Console]::ReadLine()
