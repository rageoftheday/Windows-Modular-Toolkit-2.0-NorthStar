# ============================================================
# WINDOWS MODULAR TOOLKIT - FRAMEWORK EDITION 2.0
# ============================================================

$Root = Resolve-Path "$PSScriptRoot"

. "$Root\core\bootstrap.ps1"

$TestLoggerPath = Join-Path $Root "core\test.logger.ps1"
if (Test-Path $TestLoggerPath) { . $TestLoggerPath; Initialize-ToolkitTestLog }

$RegistryPath  = Join-Path $Root "cache\toolkit_registry.json"
# Legacy: favorites.json is not created by default in Framework Edition 2.0.
# Show-Favorites remains tolerant if older builds still have this file.
$FavoritesPath = Join-Path $Root "config\favorites.json"

if (!(Test-Path (Join-Path $Root "config"))) {
    New-Item -ItemType Directory -Path (Join-Path $Root "config") | Out-Null
}

# ============================================================
# REGISTRY
# ============================================================


function Convert-ToolkitBoolean {
    param(
        [Parameter(Mandatory=$false)]
        $Value,
        [bool]$Default = $false
    )

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


function Get-MainRegistry {

    if (!(Test-Path $RegistryPath)) {

        Show-ToolkitHeader "REGISTRY NOT FOUND"
        Show-ToolkitStatus "WARN" "Build the registry before launching modules."
        Pause-Toolkit

        return @()
    }

    return @(Get-ToolkitRegistry $RegistryPath)
}



function Get-LiveUserModuleRegistry {
    # Live scan used by Open Modules so newly-created modules appear immediately.
    # Uses the script root as fallback so this does not depend on cache/global registry state.

    $ToolkitRoot = $null
    if ($Global:ToolkitRoot) { $ToolkitRoot = [string]$Global:ToolkitRoot }
    if ([string]::IsNullOrWhiteSpace($ToolkitRoot) -and $Root) { $ToolkitRoot = [string]$Root }
    if ([string]::IsNullOrWhiteSpace($ToolkitRoot)) { $ToolkitRoot = [string](Resolve-Path "$PSScriptRoot") }

    $ModulesRoot = Join-Path $ToolkitRoot "Modules"
    if (-not (Test-Path $ModulesRoot)) { return @() }

    $Results = @()
    $ModuleFolders = @(Get-ChildItem -Path $ModulesRoot -Directory -ErrorAction SilentlyContinue)

    foreach ($FolderItem in $ModuleFolders) {
        $FolderPath = $FolderItem.FullName
        $FolderName = $FolderItem.Name
        $JsonPath = Join-Path $FolderPath "tool.json"
        if (-not (Test-Path $JsonPath)) { continue }

        try {
            $Json = Get-Content -Path $JsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            continue
        }

        $Hidden = $false
        if ($Json.PSObject.Properties.Name -contains 'hidden') { $Hidden = Convert-ToolkitBoolean $Json.hidden $false }
        if ($Hidden) { continue }

        $Name = $FolderName
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
        if ($Json.PSObject.Properties.Name -contains 'requires_admin') { $RequiresAdmin = Convert-ToolkitBoolean $Json.requires_admin $false }

        $SupportsLogs = $false
        if ($Json.PSObject.Properties.Name -contains 'supports_logs') { $SupportsLogs = Convert-ToolkitBoolean $Json.supports_logs $false }

        $SupportsExport = $false
        if ($Json.PSObject.Properties.Name -contains 'supports_export') { $SupportsExport = Convert-ToolkitBoolean $Json.supports_export $false }

        $Entry = "run.bat"
        if ($Json.PSObject.Properties.Name -contains 'entry' -and -not [string]::IsNullOrWhiteSpace([string]$Json.entry)) { $Entry = [string]$Json.entry }

        $Keywords = @()
        if ($Json.PSObject.Properties.Name -contains 'keywords' -and $null -ne $Json.keywords) { $Keywords = @($Json.keywords) }

        $Dependencies = @()
        if ($Json.PSObject.Properties.Name -contains 'dependencies' -and $null -ne $Json.dependencies) { $Dependencies = @($Json.dependencies) }

        $Results += [pscustomobject]@{
            name = $Name
            folder = $FolderName
            path = $FolderPath
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
            hidden = $Hidden
            module_scope = "User"
            framework_protected = $false
        }
    }

    return @($Results)
}

# ============================================================
# SAFE REGISTRY HELPERS
# ============================================================

function Get-ToolkitPropertyValue {
    param([object]$Item, [string]$Name, [object]$Default = $null)
    if ($null -eq $Item) { return $Default }
    if ($Item.PSObject.Properties.Name -contains $Name) {
        $Value = $Item.$Name
        if ($null -ne $Value) { return $Value }
    }
    return $Default
}

function Get-ToolkitUserModules {
    param([array]$Registry)
    return @(
        $Registry | Where-Object {
            (Get-ToolkitPropertyValue $_ 'module_scope' '') -ne 'Framework' -and
            (Get-ToolkitPropertyValue $_ 'framework_protected' $false) -ne $true
        }
    )
}

function Get-ToolkitVisibleUserModules {
    param([array]$Registry)
    return @(
        Get-ToolkitUserModules $Registry | Where-Object {
            (Get-ToolkitPropertyValue $_ 'hidden' $false) -ne $true
        }
    )
}

function Get-ToolkitUserCategories {
    param([array]$Registry)
    return @(
        Get-ToolkitUserModules $Registry |
        ForEach-Object { [string](Get-ToolkitPropertyValue $_ 'category' '') } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    )
}

# ============================================================
# START MODULE BY FOLDER
# ============================================================

function Start-ModuleByFolder {

    param(
        [string]$Folder
    )

    $Registry = Get-MainRegistry

    $Module = $Registry |
        Where-Object {
            $_.folder -eq $Folder
        } |
        Select-Object -First 1

    if ($Module) {
        if (Get-Command Write-ToolkitTestLog -ErrorAction SilentlyContinue) { Write-ToolkitTestLog -Area "Launcher" -Action "Start-ModuleByFolder" -Result "INFO" -Details $Folder }
        Start-ToolkitModule $Module
    }
    else {
        # Fallback: allow newly-added framework/module folders to launch even if cache registry is stale.
        $FrameworkPath = Join-Path $Global:ToolkitRoot "Framework\$Folder"
        $ModulePath = Join-Path $Global:ToolkitRoot "Modules\$Folder"
        $DirectPath = $null

        if (Test-Path $FrameworkPath) { $DirectPath = $FrameworkPath }
        elseif (Test-Path $ModulePath) { $DirectPath = $ModulePath }

        if ($DirectPath) {
            $ToolJsonPath = Join-Path $DirectPath "tool.json"
            $Entry = "run.ps1"
            $Name = $Folder
            if (Test-Path $ToolJsonPath) {
                try {
                    $ToolJson = Get-Content $ToolJsonPath -Raw | ConvertFrom-Json
                    if ($ToolJson.entry) { $Entry = $ToolJson.entry }
                    if ($ToolJson.name) { $Name = $ToolJson.name }
                } catch {}
            }

            $EntryPath = Join-Path $DirectPath $Entry
            if (-not (Test-Path $EntryPath)) {
                if (Test-Path (Join-Path $DirectPath "run.ps1")) { $EntryPath = Join-Path $DirectPath "run.ps1" }
                elseif (Test-Path (Join-Path $DirectPath "run.bat")) { $EntryPath = Join-Path $DirectPath "run.bat" }
            }

            if (Test-Path $EntryPath) {
                if ($EntryPath -like "*.ps1") {
                    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $EntryPath
                } else {
                    & $EntryPath
                }
                return
            }
        }

        Show-ToolkitStatus "FAIL" "Module not found: $Folder"
        Pause-Toolkit
    }
}

# ============================================================
# IMPORTANT TOOLS
# ============================================================

function Show-ImportantTools {

    $Registry = Get-MainRegistry

    $ImportantTools = @(
        Get-ToolkitVisibleUserModules $Registry |
        Where-Object { (Get-ToolkitPropertyValue $_ 'important' $false) -eq $true } |
        Sort-Object category, name
    )

    while ($true) {

        Show-ToolkitHeader "IMPORTANT TOOLS"

        $Categories = @(
            $ImportantTools |
            ForEach-Object { [string](Get-ToolkitPropertyValue $_ 'category' '') } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )

        $Index = 1

        foreach ($Category in $Categories) {

            $Count = @(
                $ImportantTools |
                Where-Object {
                    $_.category -eq $Category
                }
            ).Count

            Write-Host "[$Index] $Category ($Count)"
            $Index++
        }

        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""

        $Selection = Read-Host "Select category"

        if ($Selection.ToUpper() -eq "B") { return }
        if ($Selection.ToUpper() -eq "Q") { return }
        if ($Selection -notmatch '^\d+$') { continue }

        $SelectedCategory = $Categories[[int]$Selection - 1]

        if (!$SelectedCategory) { continue }

        while ($true) {

            Show-ToolkitHeader "IMPORTANT - $SelectedCategory"

            $Tools = @(
                $ImportantTools |
                Where-Object {
                    $_.category -eq $SelectedCategory
                } |
                Sort-Object name
            )

            Show-ToolkitModuleList $Tools

            Write-Host "[B] Back"
                Write-Host ""

            $Choice = Read-Host "Select tool"

            if ($Choice.ToUpper() -eq "B") { break }
            if ($Choice.ToUpper() -eq "Q") { return }
            if ($Choice -notmatch '^\d+$') { continue }

            $Selected = $Tools[[int]$Choice - 1]

            if ($Selected) {
                Start-ToolkitModule $Selected
            }
        }
    }
}

# ============================================================
# VALIDATORS AND HEALTH
# ============================================================

function Show-Validators {

    $Registry = Get-MainRegistry

    $Tools = @(
        $Registry |
        Where-Object {
            $_.name -match "Validator|Validate|Health|Dashboard|Analytics"
        } |
        Sort-Object name
    )

    while ($true) {

        Show-ToolkitHeader "VALIDATORS AND HEALTH"

        Show-ToolkitModuleList $Tools

        Write-Host "[B] Back"
        Write-Host ""

        $Choice = Read-Host "Select tool"

        if ($Choice.ToUpper() -eq "B") { return }
        if ($Choice.ToUpper() -eq "Q") { return }

        if ($Choice -match '^\d+$') {

            $Selected = $Tools[[int]$Choice - 1]

            if ($Selected) {
                Start-ToolkitModule $Selected
            }
        }
    }
}

# ============================================================
# TOOLKIT MAINTENANCE
# ============================================================

function Show-Maintenance {

    $Registry = Get-MainRegistry

    $Tools = @(
        $Registry |
        Where-Object {
            $_.category -eq "Toolkit Management" -or
            $_.name -match "Registry|Cleanup|Metadata|Architecture|Rationalization|Auditor|Manager|Integration|Normalizer"
        } |
        Sort-Object name
    )

    while ($true) {

        Show-ToolkitHeader "TOOLKIT MAINTENANCE"

        Show-ToolkitModuleList $Tools

        Write-Host "[B] Back"
        Write-Host ""

        $Choice = Read-Host "Select tool"

        if ($Choice.ToUpper() -eq "B") { return }
        if ($Choice.ToUpper() -eq "Q") { return }

        if ($Choice -match '^\d+$') {

            $Selected = $Tools[[int]$Choice - 1]

            if ($Selected) {
                Start-ToolkitModule $Selected
            }
        }
    }
}



function Wait-ToolkitBack {
    Write-Host ""
    Write-Host "[B] Back"
    Write-Host ""
    while ($true) {
        $Choice = Read-Host "Selection"
        if ($Choice.ToUpper() -eq "B") { return }
    }
}

# ============================================================
# SUPPORT CENTER
# ============================================================

function Export-ToolkitDiagnostics {
    $ExportRoot = Join-Path $Root "Exports"
    if (!(Test-Path $ExportRoot)) { New-Item -ItemType Directory -Path $ExportRoot -Force | Out-Null }

    $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Work = Join-Path $ExportRoot "Toolkit_Diagnostics_$Stamp"
    $Zip  = Join-Path $ExportRoot "Toolkit_Diagnostics_$Stamp.zip"

    New-Item -ItemType Directory -Path $Work -Force | Out-Null

    foreach ($Name in @("Cache","Config","Logs")) {
        $Src = Join-Path $Root $Name
        if (Test-Path $Src) {
            Copy-Item -Path $Src -Destination (Join-Path $Work $Name) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $Summary = @()
    $Summary += "WINDOWS MODULAR TOOLKIT - DIAGNOSTICS EXPORT"
    $Summary += "Created: $(Get-Date)"
    $Summary += "Root: $Root"
    $Summary += ""
    $Summary += "This export is intended for troubleshooting framework state."
    $Summary += "It should not include module scripts, installers, downloads, or user-created content."
    $Summary | Set-Content -Path (Join-Path $Work "README.txt") -Encoding UTF8

    try {
        if (Test-Path $Zip) { Remove-Item $Zip -Force }
        Compress-Archive -Path (Join-Path $Work "*") -DestinationPath $Zip -Force
        Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
        Show-ToolkitHeader "DIAGNOSTICS EXPORTED"
        Write-Host "Created:"
        Write-Host $Zip
    }
    catch {
        Show-ToolkitHeader "DIAGNOSTICS EXPORT FAILED"
        Write-Host $_.Exception.Message
        Write-Host "Partial export folder: $Work"
    }
    Wait-ToolkitBack
}

function Show-SupportPage {
    param([string]$Title, [string[]]$Lines)
    Show-ToolkitHeader $Title
    foreach ($Line in $Lines) { Write-Host $Line }
    Wait-ToolkitBack
}

function Get-ToolkitDocsRoot {
    $DocsRoot = Join-Path (Get-ToolkitRootText) "Docs"
    if (-not (Test-Path $DocsRoot)) { New-Item -ItemType Directory -Path $DocsRoot -Force | Out-Null }
    return $DocsRoot
}

function Get-ToolkitRootText {
    if ($Global:ToolkitRoot) {
        try {
            $Resolved = Resolve-Path -Path ([string]$Global:ToolkitRoot) -ErrorAction Stop
            return [string]$Resolved.ProviderPath
        }
        catch {
            return [string]$Global:ToolkitRoot
        }
    }
    return [string]$Root
}

function Get-ToolkitRelativePath {
    param([string]$Path)

    $RootText = Get-ToolkitRootText
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }

    try { $FullPath = [string](Resolve-Path -Path $Path -ErrorAction Stop).ProviderPath }
    catch { $FullPath = [string]$Path }

    if (-not [string]::IsNullOrWhiteSpace($RootText)) {
        $Prefix = $RootText.TrimEnd('\','/') + '\'
        if ($FullPath.StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $FullPath.Substring($Prefix.Length)
        }
    }

    return $FullPath
}

function Show-ToolkitDocFile {
    param(
        [string]$Title,
        [string]$RelativePath
    )
    Show-ToolkitHeader $Title
    $DocsRoot = Get-ToolkitDocsRoot
    $DocPath = Join-Path (Get-ToolkitRootText) $RelativePath
    if (-not (Test-Path $DocPath)) { $DocPath = Join-Path $DocsRoot $RelativePath }
    if (Test-Path $DocPath) {
        Get-Content $DocPath | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Host "Document not found:" -ForegroundColor Red
        Write-Host "  $RelativePath"
    }
    Write-Host ""
    Wait-ToolkitBack
}

function Show-ToolkitDocsMenu {
    param(
        [string]$Title,
        [string]$FolderRelativeToDocs
    )

    while ($true) {
        Show-ToolkitHeader $Title
        $DocsRoot = Get-ToolkitDocsRoot
        $Folder = if ([string]::IsNullOrWhiteSpace($FolderRelativeToDocs)) { $DocsRoot } else { Join-Path $DocsRoot $FolderRelativeToDocs }
        if (-not (Test-Path $Folder)) {
            Write-Host "No documents found for this section."
            Write-Host ""
            Write-Host "[B] Back"
            $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
            if ($Choice -eq 'B') { return }
            continue
        }

        $Docs = @(Get-ChildItem -Path $Folder -File -Recurse -Include *.txt,*.md,*.rtf -ErrorAction SilentlyContinue |
            Sort-Object FullName)

        if (-not $Docs -or $Docs.Count -eq 0) {
            Write-Host "No documents found for this section."
        }
        else {
            $i = 1
            foreach ($Doc in $Docs) {
                $Display = [IO.Path]::GetFileNameWithoutExtension($Doc.Name) -replace '_',' '
                Write-Host "[$i] $Display"
                Write-Host "    $(Get-ToolkitRelativePath $Doc.FullName)" -ForegroundColor DarkGray
                $i++
            }
        }
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        if ($Choice -eq 'B') { return }
        $Index = 0
        if ([int]::TryParse($Choice, [ref]$Index)) {
            if ($Index -ge 1 -and $Index -le $Docs.Count) {
                $Selected = $Docs[$Index-1]
                $Rel = Get-ToolkitRelativePath $Selected.FullName
                Show-ToolkitDocFile ([IO.Path]::GetFileNameWithoutExtension($Selected.Name).ToUpperInvariant()) $Rel
            }
        }
    }
}

function Show-AllToolkitDocs {
    Show-ToolkitDocsMenu "ALL TOOLKIT DOCUMENTS" ""
}


function Show-SupportCenter {

    while ($true) {

        Show-ToolkitHeader "HELP & SUPPORT"

        Write-Host "Documentation, tutorials, troubleshooting, diagnostics, and project information."
        Write-Host "Every release document should be reachable from this Help & Support area."
        Write-Host ""
        Write-Host "Start Here"
        Write-Host "----------"
        Write-Host "[1] Quick Start"
        Write-Host "[2] How The Framework Works"
        Write-Host "[3] How To Make A Module"
        Write-Host "[4] Repository Formats & Detection"
        Write-Host ""
        Write-Host "Guides By Section"
        Write-Host "-----------------"
        Write-Host "[5] User Guides"
        Write-Host "[6] Repository Guide"
        Write-Host "[7] GitHub Puller Guide"
        Write-Host "[8] Winget Puller Guide"
        Write-Host "[9] Metadata Library Guide"
        Write-Host "[10] Recovery & Reset Guide"
        Write-Host "[11] Troubleshooting & FAQ"
        Write-Host ""
        Write-Host "Reference"
        Write-Host "---------"
        Write-Host "[12] Standards"
        Write-Host "[13] Architecture"
        Write-Host "[14] All Documents"
        Write-Host ""
        Write-Host "Diagnostics"
        Write-Host "-----------"
        Write-Host "[15] Open Logs Folder"
        Write-Host "[16] Export Diagnostics"
        Write-Host "[17] Open Toolkit Folder"
        Write-Host ""
        Write-Host "Project"
        Write-Host "-------"
        Write-Host "[18] Project Information"
        Write-Host "[19] Open GitHub Repository"
        Write-Host "[20] Open Discussions & Feedback"
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""

        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()

        switch ($Choice) {
            "1"  { Show-ToolkitDocFile "GETTING STARTED" "Docs\User\01_GETTING_STARTED.md" }
            "2"  { Show-ToolkitDocFile "HOW THE FRAMEWORK WORKS" "Docs\User\09_HOW_THE_FRAMEWORK_WORKS.md" }
            "3"  { Show-ToolkitDocFile "HOW TO MAKE A MODULE" "Docs\User\05_MODULE_CREATION_GUIDE.md" }
            "4"  { Show-ToolkitDocFile "REPOSITORY FORMATS & DETECTION" "Docs\Software Deployment\Supported_Formats.txt" }
            "5"  { Show-ToolkitDocsMenu "USER GUIDES" "User" }
            "6"  { Show-ToolkitDocFile "REPOSITORY MANAGER GUIDE" "Docs\User\02_REPOSITORY_MANAGER_GUIDE.md" }
            "7"  { Show-ToolkitDocFile "GITHUB PULLER GUIDE" "Docs\User\03_GITHUB_PULLER_GUIDE.md" }
            "8"  { Show-ToolkitDocFile "WINGET PULLER GUIDE" "Docs\User\16_WINGET_PULLER_GUIDE.md" }
            "9"  { Show-ToolkitDocFile "METADATA LIBRARY MANAGER GUIDE" "Docs\User\04_METADATA_LIBRARY_MANAGER_GUIDE.md" }
            "10" { Show-ToolkitDocFile "RECOVERY & RESET GUIDE" "Docs\User\08_RECOVERY_AND_RESET_GUIDE.md" }
            "11" { Show-ToolkitDocFile "TROUBLESHOOTING & FAQ" "Docs\User\10_TROUBLESHOOTING_FAQ.md" }
            "12" { Show-ToolkitDocsMenu "STANDARDS" "Standards" }
            "13" { Show-ToolkitDocsMenu "ARCHITECTURE" "Architecture" }
            "14" { Show-AllToolkitDocs }
            "15" {
                $LogsPath = Join-Path $Global:ToolkitRoot "Logs"
                if (-not (Test-Path $LogsPath)) { New-Item -ItemType Directory -Path $LogsPath -Force | Out-Null }
                Invoke-Item $LogsPath
            }
            "16" { Export-ToolkitDiagnostics }
            "17" { Invoke-Item $Global:ToolkitRoot }
            "18" {
                Show-SupportPage "PROJECT INFORMATION" @(
                    "Windows Modular Toolkit - Framework Edition 2.0",
                    "A USB-friendly framework for organizing, managing, validating, and running modular tools.",
                    "",
                    "Core idea:",
                    "- The framework manages itself.",
                    "- Users manage the content.",
                    "",
                    "Release documentation is stored in Docs\User and reachable from Help Center."
                )
            }
            "19" { Start-Process "https://github.com/rageoftheday/IT-Modular-Tool" }
            "20" { Start-Process "https://github.com/rageoftheday/IT-Modular-Tool/discussions/1" }
            "B"  { return }
            default { Show-ToolkitStatus "WARN" "Unknown selection: $Choice"; Start-Sleep -Milliseconds 700 }
        }
    }
}

# ============================================================
# TOOLKIT MANAGEMENT
# ============================================================

function Get-ToolkitManagementModules {
    param([array]$Registry)

    return @(
        $Registry |
        Where-Object {
            $Scope = [string](Get-ToolkitPropertyValue $_ 'module_scope' '')
            $Protected = [bool](Get-ToolkitPropertyValue $_ 'framework_protected' $false)
            $Category = [string](Get-ToolkitPropertyValue $_ 'category' '')
            $Name = [string](Get-ToolkitPropertyValue $_ 'name' '')

            $Scope -eq "Framework" -or
            $Protected -eq $true -or
            $Category -eq "Toolkit Management" -or
            $Category -eq "Toolkit Operations" -or
            $Name -match "Registry|Validator|Validate|Health|Wizard|Manager|Metadata|Dashboard|Audit|Architecture|Integration|Normalizer|Rationalization|Support|Repair|Logger|Recommendation|Chain"
        } |
        Sort-Object `
            @{Expression = { Get-ToolkitPropertyValue $_ 'framework_priority' '' }}, `
            @{Expression = { Get-ToolkitPropertyValue $_ 'framework_category' '' }}, `
            @{Expression = { Get-ToolkitPropertyValue $_ 'name' '' }}
    )
}

function Show-ToolkitManagement {

    $Registry = Get-MainRegistry
    $Tools = @(Get-ToolkitManagementModules $Registry)

    while ($true) {

        Show-ToolkitHeader "TOOLKIT MANAGEMENT"
        Write-Host "Framework tools used to create, organize, validate, repair, automate, update, and maintain the toolkit."
        Write-Host ""
        Write-Host "Framework Centers"
        Write-Host "-----------------"
        Write-Host "[1] Validation Center"
        Write-Host "    Check toolkit health, metadata, modules, and framework issues." -ForegroundColor DarkGray
        Write-Host "[2] Tool Manager"
        Write-Host "    Create, edit, organize, clone, hide, and remove modules." -ForegroundColor DarkGray
        Write-Host "[3] Category Manager"
        Write-Host "    Create and organize module categories." -ForegroundColor DarkGray
        Write-Host "[4] Dashboard & Health"
        Write-Host "    View toolkit status, counts, health, and summaries." -ForegroundColor DarkGray
        Write-Host "[5] Registry Manager"
        Write-Host "    Rebuild and inspect the toolkit registry/cache." -ForegroundColor DarkGray
        Write-Host "[6] Metadata Engine"
        Write-Host "    Generate, validate, repair, and edit metadata attached to real objects." -ForegroundColor DarkGray
        Write-Host "[7] Search Foundation"
        Write-Host "    Search modules, workspace items, installers, documentation, and metadata." -ForegroundColor DarkGray
        Write-Host "[7] Audit Center"
        Write-Host "    Review toolkit structure, duplicates, and framework/module findings." -ForegroundColor DarkGray
        Write-Host "[9] Compatibility Center"
        Write-Host "    Verify Windows, PowerShell, portable mode, and dependency readiness." -ForegroundColor DarkGray
        Write-Host "[10] Framework Repair"
        Write-Host "    Repair missing folders, configs, cache, and framework-owned data." -ForegroundColor DarkGray
        Write-Host "[11] Release Candidate Validation"
        Write-Host "    Run final framework readiness checks." -ForegroundColor DarkGray
        Write-Host "[12] Repository Manager"
        Write-Host "    Scan Incoming, organize Repository items, and manage deployment workflows." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "High Priority"
        Write-Host "-------------"
        Write-Host "[13] Validation & Health"
        Write-Host "    Run validation, health checks, and diagnostics." -ForegroundColor DarkGray
        Write-Host "[14] Backup & Recovery"
        Write-Host "    Backup framework data and recover lost components." -ForegroundColor DarkGray
        Write-Host "[15] Compatibility & Requirements"
        Write-Host "    Verify Windows, PowerShell, dependencies, and requirements." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Medium Priority"
        Write-Host "---------------"
        Write-Host "[16] Builders"
        Write-Host "    Create modules, installers, websites, and framework objects." -ForegroundColor DarkGray
        Write-Host "[17] Configuration"
        Write-Host "    Manage settings, profiles, aliases, and behavior configuration." -ForegroundColor DarkGray
        Write-Host "[18] Import & Export"
        Write-Host "    Move toolkit packs, modules, reports, and backups in or out." -ForegroundColor DarkGray
        Write-Host "[19] Audit & Reporting"
        Write-Host "    Generate reports and review framework/module audit results." -ForegroundColor DarkGray
        Write-Host "[20] Support & Documentation"
        Write-Host "    Open help guides, documentation, logs, and diagnostics." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Low Priority"
        Write-Host "------------"
        Write-Host "[23] Development & Testing"
        Write-Host "    Open testing, analyzers, runners, and development utilities." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Search"
        Write-Host "------"
        Write-Host "[21] Search Toolkit Management Tools"
        Write-Host "    Search framework tools by name and purpose." -ForegroundColor DarkGray
        Write-Host "[22] View Test Log"
        Write-Host "    Open the temporary testing log for sending results back." -ForegroundColor DarkGray
        Write-Host "[24] Capability Audit"
        Write-Host "    Review framework tools for keep, merge, retire, or review decisions." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""

        $Choice = Read-Host "Selection"

        switch ($Choice.ToUpper()) {
            "1" { Start-ModuleByFolder "Validation_Center" }
            "2" { Start-ModuleByFolder "Tool_Manager" }
            "3" { Start-ModuleByFolder "Category_Manager" }
            "4" { Start-ModuleByFolder "Dashboard_Health_Center" }
            "5" { Start-ModuleByFolder "Registry_Manager" }
            "6" { Start-ModuleByFolder "Metadata_Foundation" }
            "7" { Start-ModuleByFolder "Search_Foundation" }
            "8" { Start-ModuleByFolder "Audit_Center" }
            "9" { Start-ModuleByFolder "Compatibility_Center" }
            "10" { Start-ModuleByFolder "Framework_Repair" }
            "11" { Start-ModuleByFolder "RC1_Validation" }
            "12" { Start-ModuleByFolder "Repository_Manager" }
            "13" { Show-ToolkitManagementCategory "Validation & Health" $Tools }
            "14" { Show-ToolkitManagementCategory "Backup & Recovery" $Tools }
            "15" { Show-ToolkitManagementCategory "Compatibility & Requirements" $Tools }
            "16" { Show-ToolkitManagementCategory "Builders" $Tools }
            "17" { Show-ToolkitManagementCategory "Configuration" $Tools }
            "18" { Show-ToolkitManagementCategory "Import & Export" $Tools }
            "19" { Show-ToolkitManagementCategory "Audit & Reporting" $Tools }
            "20" { Show-ToolkitManagementCategory "Support & Documentation" $Tools }
            "23" { Show-ToolkitManagementCategory "Development & Testing" $Tools }
            "21" { Show-ToolkitManagementSearch $Tools }
            "22" { Start-ModuleByFolder "Test_Log_Viewer" }
            "24" { Start-ModuleByFolder "Capability_Audit" }
            "B" { return }
        }
    }
}

function Show-ToolkitManagementCategory {
    param(
        [string]$Category,
        [array]$Tools
    )

    $Filtered = @(
        $Tools |
        Where-Object {
            $FrameworkCategory = [string](Get-ToolkitPropertyValue $_ 'framework_category' '')
            $Name = [string](Get-ToolkitPropertyValue $_ 'name' '')

            $FrameworkCategory -eq $Category -or
            ($Category -eq "Validation & Health" -and $Name -match "Validator|Validate|Health|Registry|Audit|Status|Integrity") -or
            ($Category -eq "Backup & Recovery" -and $Name -match "Backup|Restore|Export|Import|Deleted") -or
            ($Category -eq "Compatibility & Requirements" -and $Name -match "Compatibility|Requirement|Dependency|Portable|PowerShell|Operating System|OS|Installer|Package") -or
            ($Category -eq "Builders" -and $Name -match "Wizard|Builder|Manager|Metadata|Architecture|Normalizer|Integration|Cleanup|Remove") -or
            ($Category -eq "Configuration" -and $Name -match "Settings|Recommendation|Alias|Logger") -or
            ($Category -eq "Audit & Reporting" -and $Name -match "Audit|Inventory|Dashboard|Report|Duplicate|Export") -or
            ($Category -eq "Support & Documentation" -and $Name -match "Guide|Support|Release|Notes|Help") -or
            ($Category -eq "Development & Testing" -and $Name -match "Development|Testing|Legacy|Analyzer|Runner|Launcher|Rationalization")
        } |
        Sort-Object @{Expression = { Get-ToolkitPropertyValue $_ 'name' '' }}
    )

    while ($true) {
        Show-ToolkitHeader "TOOLKIT MANAGEMENT - $Category"

        if (!$Filtered -or $Filtered.Count -eq 0) {
            Write-Host "No tools found for this category yet."
            Write-Host ""
        }
        else {
            Show-ToolkitModuleList $Filtered
        }

        Write-Host "[B] Back"
        Write-Host ""

        $Choice = Read-Host "Select tool"

        if ($Choice.ToUpper() -eq "B") { return }
        if ($Choice.ToUpper() -eq "Q") { return }

        if ($Choice -match '^\d+$') {
            $Selected = $Filtered[[int]$Choice - 1]
            if ($Selected) { Start-ToolkitModule $Selected }
        }
    }
}

function Show-ToolkitManagementSearch {
    param([array]$Tools)

    $LastNoResult = $null

    while ($true) {
        Show-ToolkitHeader "SEARCH TOOLKIT MANAGEMENT"
        Write-Host "Search framework tools only."
        Write-Host ""
        if ($LastNoResult) {
            Write-Host "No framework tools found for:"
            Write-Host ""
            Write-Host $LastNoResult -ForegroundColor Yellow
            Write-Host ""
            $LastNoResult = $null
        }
        Write-Host "[B] Back"
        Write-Host ""

        $Search = Read-Host "Search"
        if ($Search.ToUpper() -eq "B") { return }
        if ($Search.ToUpper() -eq "Q") { return }
        if ([string]::IsNullOrWhiteSpace($Search)) { continue }

        $Matches = @(
            $Tools |
            Where-Object {
                [string](Get-ToolkitPropertyValue $_ 'name' '') -match [regex]::Escape($Search) -or
                [string](Get-ToolkitPropertyValue $_ 'folder' '') -match [regex]::Escape($Search) -or
                [string](Get-ToolkitPropertyValue $_ 'category' '') -match [regex]::Escape($Search) -or
                [string](Get-ToolkitPropertyValue $_ 'subcategory' '') -match [regex]::Escape($Search) -or
                [string](Get-ToolkitPropertyValue $_ 'description' '') -match [regex]::Escape($Search) -or
                (@(Get-ToolkitPropertyValue $_ 'keywords' @()) -join " ") -match [regex]::Escape($Search)
            } |
            Sort-Object name
        )

        if (!$Matches -or $Matches.Count -eq 0) {
            $Suggestions = @()
            if (Get-Command Get-ToolkitSmartSuggestions -ErrorAction SilentlyContinue) {
                $Suggestions = @(Get-ToolkitSmartSuggestions -Query $Search -Registry $Tools -MaxResults 5)
            }

            if (!$Suggestions -or $Suggestions.Count -eq 0) {
                $LastNoResult = $Search
                continue
            }

            $Matches = $Suggestions
            $Title = "SEARCH SUGGESTIONS - TOOLKIT MANAGEMENT"
        }
        else {
            $Title = "SEARCH RESULTS - TOOLKIT MANAGEMENT"
        }

        while ($true) {
            Show-ToolkitHeader $Title
            Show-ToolkitModuleList $Matches
            Write-Host "[S] Search Again"
            Write-Host "[B] Back"
                Write-Host ""
            $Choice = Read-Host "Selection"
            if ($Choice.ToUpper() -eq "S") { break }
            if ($Choice.ToUpper() -eq "B") { return }
            if ($Choice.ToUpper() -eq "Q") { return }
            if ($Choice -match '^\d+$') {
                $Selected = $Matches[[int]$Choice - 1]
                if ($Selected) { Start-ToolkitModule $Selected }
            }
        }
    }
}

# ============================================================
# FAVORITES
# ============================================================

function Show-Favorites {

    $Registry = Get-MainRegistry

    try {
        $Favorites = @(Get-Content $FavoritesPath -Raw | ConvertFrom-Json)
    }
    catch {
        $Favorites = @()
    }

    while ($true) {

        Show-ToolkitHeader "FAVORITES"

        $FavoriteModules = @(
            $Registry |
            Where-Object {
                $Favorites -contains $_.folder
            } |
            Sort-Object name
        )

        if (!$FavoriteModules -or $FavoriteModules.Count -eq 0) {
            Write-Host "No favorites added yet."
            Write-Host ""
        }
        else {
            Show-ToolkitModuleList $FavoriteModules
        }

        Write-Host "[A] Add Favorite"
        Write-Host "[R] Remove Favorite"
        Write-Host "[B] Back"
        Write-Host ""

        $Choice = Read-Host "Selection"

        switch ($Choice.ToUpper()) {

            "A" {

                $Search = Read-Host "Search tool name"

                if ([string]::IsNullOrWhiteSpace($Search)) {
                    continue
                }

                $Matches = @(
                    $Registry |
                    Where-Object {
                        $_.name -match $Search -or
                        $_.folder -match $Search
                    } |
                    Sort-Object name
                )

                Show-ToolkitHeader "ADD FAVORITE"

                if (!$Matches -or $Matches.Count -eq 0) {
                    Write-Host "No matching tools found."
                    Pause-Toolkit
                    continue
                }

                Show-ToolkitModuleList $Matches

                Write-Host "[B] Back"
                Write-Host ""

                $Pick = Read-Host "Select tool number"

                if ($Pick.ToUpper() -eq "B") {
                    continue
                }

                if ($Pick -match '^\d+$') {

                    $Selected = $Matches[[int]$Pick - 1]

                    if ($Selected) {

                        $Favorites = @(
                            $Favorites + $Selected.folder |
                            Select-Object -Unique
                        )

                        $Favorites |
                            ConvertTo-Json |
                            Set-Content $FavoritesPath -Encoding UTF8
                    }
                }
            }

            "R" {

                $FavoriteModules = @(
                    $Registry |
                    Where-Object {
                        $Favorites -contains $_.folder
                    } |
                    Sort-Object name
                )

                Show-ToolkitHeader "REMOVE FAVORITE"

                if (!$FavoriteModules -or $FavoriteModules.Count -eq 0) {
                    Write-Host "No favorites to remove."
                    Pause-Toolkit
                    continue
                }

                Show-ToolkitModuleList $FavoriteModules

                Write-Host "[B] Back"
                Write-Host ""

                $Pick = Read-Host "Select tool number"

                if ($Pick.ToUpper() -eq "B") {
                    continue
                }

                if ($Pick -match '^\d+$') {

                    $Selected = $FavoriteModules[[int]$Pick - 1]

                    if ($Selected) {

                        $Favorites = @(
                            $Favorites |
                            Where-Object {
                                $_ -ne $Selected.folder
                            }
                        )

                        $Favorites |
                            ConvertTo-Json |
                            Set-Content $FavoritesPath -Encoding UTF8
                    }
                }
            }

            "B" {
                return
            }

            "Q" {
                exit
            }

            default {

                if ($Choice -match '^\d+$') {

                    $Selected = $FavoriteModules[[int]$Choice - 1]

                    if ($Selected) {
                        Start-ToolkitModule $Selected
                    }
                }
            }
        }
    }
}

# ============================================================
# RECENT TOOLS
# ============================================================

function Show-RecentTools {

    $Registry = Get-MainRegistry

    $LogPath = Join-Path $Root "logs\toolkit_runtime.log"

    if (!(Test-Path $LogPath)) {

        while ($true) {
            Show-ToolkitHeader "RECENT TOOLS"
            Write-Host "No runtime data available yet."
            Write-Host ""
            Write-Host "[B] Back"
            Write-Host ""
            $Choice = Read-Host "Selection"
            if ($Choice.ToUpper() -eq "B") { return }
        }
    }

    $Lines = Get-Content $LogPath -ErrorAction SilentlyContinue

    $RecentNames = @()

    foreach ($Line in $Lines) {

        if ($Line -match "Launching module:\s*(.+)$") {
            $RecentNames += $Matches[1].Trim()
        }
        elseif ($Line -match "Launching:\s*(.+)$") {
            $RecentNames += $Matches[1].Trim()
        }
        elseif ($Line -match "\[START\]\s+\[(.+?)\]") {
            $RecentNames += $Matches[1].Trim()
        }
    }

    if (!$RecentNames -or $RecentNames.Count -eq 0) {

        while ($true) {
            Show-ToolkitHeader "RECENT TOOLS"
            Write-Host "No recent tools found."
            Write-Host ""
            Write-Host "[B] Back"
            Write-Host ""
            $Choice = Read-Host "Selection"
            if ($Choice.ToUpper() -eq "B") { return }
        }
    }

    $RecentNames = @(
        $RecentNames |
        Select-Object -Unique |
        Select-Object -Last 15
    )

    $RecentModules = @(
        foreach ($Name in $RecentNames) {

            $Registry |
            Where-Object {
                $_.name -eq $Name -or
                $_.name.ToUpper() -eq $Name.ToUpper()
            } |
            Select-Object -First 1
        }
    )

    $RecentModules = @(
        $RecentModules |
        Where-Object {
            $_ -ne $null
        }
    )

    while ($true) {

        Show-ToolkitHeader "RECENT TOOLS"

        if (!$RecentModules -or $RecentModules.Count -eq 0) {

            Write-Host "No recent tools matched the current registry."
            Pause-Toolkit
            return
        }

        Show-ToolkitModuleList $RecentModules

        Write-Host "[B] Back"
        Write-Host ""

        $Choice = Read-Host "Select tool"

        if ($Choice.ToUpper() -eq "B") { return }
        if ($Choice.ToUpper() -eq "Q") { return }

        if ($Choice -match '^\d+$') {

            $Selected = $RecentModules[[int]$Choice - 1]

            if ($Selected) {
                Start-ToolkitModule $Selected
            }
        }
    }
}


# ============================================================
# STARTUP FRAMEWORK STATUS
# ============================================================

function Get-ToolkitMainCounts {
    $Registry = Get-MainRegistry
    $FrameworkCount = @($Registry | Where-Object { (Get-ToolkitPropertyValue $_ 'module_scope' '') -eq "Framework" -or (Get-ToolkitPropertyValue $_ 'framework_protected' $false) -eq $true }).Count

    # Use the same live module scan as Open Modules so the main menu count matches what users can actually open.
    $LiveUserModules = @(Get-LiveUserModuleRegistry)
    if ($LiveUserModules.Count -gt 0) {
        $UserCount = $LiveUserModules.Count
        $CategoryCount = @($LiveUserModules | ForEach-Object { [string](Get-ToolkitPropertyValue $_ 'category' '') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique).Count
    }
    else {
        $UserCount = @(Get-ToolkitVisibleUserModules $Registry).Count
        $CategoryCount = @(Get-ToolkitUserCategories $Registry).Count
    }

    $Integrity = Test-ToolkitFrameworkIntegrity
    $RegistryLoaded = $false
    if (Test-Path $RegistryPath) {
        try {
            $Raw = Get-Content $RegistryPath -Raw
            if (-not [string]::IsNullOrWhiteSpace($Raw)) { $RegistryLoaded = $true }
        } catch { $RegistryLoaded = $false }
    }

    [PSCustomObject]@{
        FrameworkCount = $FrameworkCount
        UserCount = $UserCount
        CategoryCount = $CategoryCount
        FrameworkFiles = $(if ($Integrity.Passed) { "PASS" } else { "FAIL" })
        Registry = $(if ($RegistryLoaded) { "PASS" } else { "FAIL" })
        Status = $(if ($Integrity.Passed -and $RegistryLoaded) { "HEALTHY" } elseif ($Integrity.Passed) { "WARNING" } else { "REPAIR REQUIRED" })
    }
}

function Show-FrameworkStatusMenu {
    while ($true) {
        $Registry = Get-MainRegistry
        $Choice = Show-ToolkitFrameworkStatus $Registry
        switch ($Choice.ToUpper()) {
            "1" { continue }
            "2" { Start-ModuleByFolder "Toolkit_Health_Center" }
            "B" { return }
        }
    }
}

function Show-StartupWarningIfNeeded {
    $Counts = Get-ToolkitMainCounts
    if ($Counts.Status -eq "HEALTHY") { return }

    Show-ToolkitHeader "FRAMEWORK WARNING"
    if ($Counts.FrameworkFiles -eq "PASS") { Show-ToolkitStatus "PASS" "Framework files found" } else { Show-ToolkitStatus "FAIL" "Framework files missing" }
    if ($Counts.Registry -eq "PASS") { Show-ToolkitStatus "PASS" "Registry loaded" } else { Show-ToolkitStatus "FAIL" "Registry missing or empty" }
    Write-Host ""
    Write-Host "Status: $($Counts.Status)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Impact: Some toolkit features may not appear or run correctly."
    Write-Host "Recommended Action: Run Framework Repair."
    Write-Host ""
    Write-Host "[1] Repair Now"
    Write-Host "[2] Continue Anyway"
    Write-Host ""
    $Choice = Read-Host "Selection"
    if ($Choice -eq "1") { Start-ModuleByFolder "Framework_Repair" }
}

Show-StartupWarningIfNeeded

# ============================================================

# ============================================================
# FRAMEWORK 2.0 CENTERS AND NAVIGATION - BUILD 40C
# ============================================================

function Invoke-ToolkitCenterTool {
    param(
        [string]$Folder,
        [string]$DisplayName = $null
    )

    if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = $Folder }

    $FrameworkPath = Join-Path $Global:ToolkitRoot "Framework\$Folder"
    $ModulePath    = Join-Path $Global:ToolkitRoot "Modules\$Folder"

    if ((Test-Path $FrameworkPath) -or (Test-Path $ModulePath)) {
        Start-ModuleByFolder $Folder
        return
    }

    Show-ToolkitHeader "NOT AVAILABLE"
    Show-ToolkitStatus "WARN" "$DisplayName is not available in this build."
    Write-Host ""
    Write-Host "This menu location is reserved by the Framework 2.0 House Map."
    Write-Host "No existing capability was removed."
    Pause-Toolkit
}

function Show-SearchCenter {
    while ($true) {
        Show-ToolkitHeader "SEARCH CENTER"
        Write-Host "Find tools, modules, documentation, repository items, workspace links, and framework resources."
        Write-Host "Search should teach where things live, not just open them."
        Write-Host ""
        Write-Host "[1] Search Everything"
        Write-Host "    Search indexed toolkit objects across modules, repository records, workspace, and docs." -ForegroundColor DarkGray
        Write-Host "[2] Browse Module Categories"
        Write-Host "    Browse runnable modules by category." -ForegroundColor DarkGray
        Write-Host "[3] Browse Repository"
        Write-Host "    Browse stored repository items by type: software, scripts, documents, images, and archives." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = Read-Host "Selection"
        switch ($Choice.ToUpper()) {
            "1" { Invoke-ToolkitCenterTool "Search_Foundation" "Search Everything" }
            "2" { Invoke-ToolkitCenterTool "Category_Browser" "Browse Module Categories" }
            "3" { Invoke-ToolkitCenterTool "Repository_Browser" "Browse Repository" }
            "B" { return }
        }
    }
}



function Invoke-OpenModuleAndReturn {
    param([object]$Module)

    if ($null -eq $Module) { return }

    Start-ToolkitModule $Module
}

function Show-OpenModules {
    while ($true) {
        Show-ToolkitHeader "OPEN MODULES"
        Write-Host "Browse and run available user modules."
        Write-Host ""
        Write-Host "[1] Browse by Category"
        Write-Host "    Pick a category first, then choose a module to run." -ForegroundColor DarkGray
        Write-Host "[2] All Modules"
        Write-Host "    Show all modules grouped by category." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""

        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()

        switch ($Choice) {
            "1" { Show-OpenModulesByCategory }
            "2" { Show-AllOpenModules }
            "B" { return }
            default { Show-ToolkitStatus "WARN" "Unknown selection: $Choice"; Start-Sleep -Milliseconds 700 }
        }
    }
}

function Show-OpenModulesByCategory {
    while ($true) {
        $Modules = @(Get-LiveUserModuleRegistry | Sort-Object category, name)

        Show-ToolkitHeader "OPEN MODULES - CATEGORIES"

        if ($Modules.Count -eq 0) {
            Show-ToolkitStatus "WARN" "No visible user modules found."
            Pause-Toolkit
            return
        }

        $Categories = @(
            $Modules |
            ForEach-Object { [string](Get-ToolkitPropertyValue $_ 'category' 'Uncategorized') } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )

        for ($i = 0; $i -lt $Categories.Count; $i++) {
            $Category = $Categories[$i]
            $Count = @($Modules | Where-Object { [string](Get-ToolkitPropertyValue $_ 'category' 'Uncategorized') -eq $Category }).Count
            Write-Host "[$($i + 1)] $Category ($Count)"
        }

        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""

        $Choice = (Read-Host "Select category").Trim().ToUpperInvariant()
        if ($Choice -eq "B") { return }
        if ($Choice -notmatch '^\d+$') { continue }

        $Index = [int]$Choice - 1
        if ($Index -lt 0 -or $Index -ge $Categories.Count) { continue }

        Show-OpenModulesInCategory -Category $Categories[$Index]
    }
}

function Show-OpenModulesInCategory {
    param([string]$Category)

    while ($true) {
        $Modules = @(
            Get-LiveUserModuleRegistry |
            Where-Object { [string](Get-ToolkitPropertyValue $_ 'category' 'Uncategorized') -eq $Category } |
            Sort-Object name
        )

        Show-ToolkitHeader "OPEN MODULES - $Category"

        if ($Modules.Count -eq 0) {
            Show-ToolkitStatus "WARN" "No modules found in this category."
            Pause-Toolkit
            return
        }

        Show-ToolkitModuleList $Modules
        Write-Host "[B] Back"
        Write-Host ""

        $Choice = (Read-Host "Select module to run").Trim().ToUpperInvariant()
        if ($Choice -eq "B") { return }
        if ($Choice -notmatch '^\d+$') { continue }

        $Index = [int]$Choice - 1
        if ($Index -lt 0 -or $Index -ge $Modules.Count) { continue }

        Invoke-OpenModuleAndReturn $Modules[$Index]
    }
}

function Show-AllOpenModules {
    while ($true) {
        $Modules = @(Get-LiveUserModuleRegistry | Sort-Object category, name)

        Show-ToolkitHeader "OPEN MODULES - ALL MODULES"

        if ($Modules.Count -eq 0) {
            Show-ToolkitStatus "WARN" "No visible user modules found."
            Pause-Toolkit
            return
        }

        $NumberedModules = @()
        $Index = 1
        $Categories = @(
            $Modules |
            ForEach-Object { [string](Get-ToolkitPropertyValue $_ 'category' 'Uncategorized') } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )

        foreach ($Category in $Categories) {
            Write-Host ""
            Write-Host "== $Category ==" -ForegroundColor Cyan

            $CategoryModules = @(
                $Modules |
                Where-Object { [string](Get-ToolkitPropertyValue $_ 'category' 'Uncategorized') -eq $Category } |
                Sort-Object name
            )

            foreach ($Module in $CategoryModules) {
                $DisplayName = Get-ToolkitPropertyValue $Module 'name' $Module.folder
                $Risk = Get-ToolkitPropertyValue $Module 'risk' ''
                $Admin = Get-ToolkitPropertyValue $Module 'requires_admin' $false
                $AdminText = $(if ($Admin -eq $true) { " [ADMIN]" } else { "" })
                $RiskColor = Get-ToolkitRiskColor $Risk

                Write-Host "[$Index] $DisplayName$AdminText" -ForegroundColor $RiskColor
                $Description = Get-ToolkitPropertyValue $Module 'description' ''
                if (-not [string]::IsNullOrWhiteSpace($Description)) { Write-Host "     $Description" }

                $NumberedModules += $Module
                $Index++
            }
        }

        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""

        $Choice = (Read-Host "Select module to run").Trim().ToUpperInvariant()
        if ($Choice -eq "B") { return }
        if ($Choice -notmatch '^\d+$') { continue }

        $SelectedIndex = [int]$Choice - 1
        if ($SelectedIndex -lt 0 -or $SelectedIndex -ge $NumberedModules.Count) { continue }

        Invoke-OpenModuleAndReturn $NumberedModules[$SelectedIndex]
    }
}

function Show-DashboardCenter {
    while ($true) {
        Show-ToolkitHeader "DASHBOARD CENTER"
        Write-Host "View toolkit status, health summaries, statistics, recommendations, and recent activity."
        Write-Host ""
        Write-Host "[1] Dashboard Overview"
        Write-Host "    Main dashboard with toolkit/system snapshot and health/recommendation links." -ForegroundColor DarkGray
        Write-Host "[2] Smart Recommendations"
        Write-Host "    Recommendation engine and summary view." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = Read-Host "Selection"
        switch ($Choice.ToUpper()) {
            "1" { Invoke-ToolkitCenterTool "Dashboard_Health_Center" "Dashboard Overview" }
            "2" { Invoke-ToolkitCenterTool "Smart_Recommendations_Engine" "Smart Recommendations" }
            "B" { return }
        }
    }
}

function New-RepositoryQATestPack {
    $Incoming = Join-Path $Global:ToolkitRoot 'Incoming'
    if (-not (Test-Path $Incoming)) { New-Item -ItemType Directory -Path $Incoming -Force | Out-Null }
    $Extensions = @(
        'exe','msi','appx','appxbundle','msix','msixbundle','ps1',
        'txt','md','pdf','rtf','doc','docx','dot','dotx','xls','xlsx','xlsm','xltx','csv','tsv','ods','ppt','pptx','pptm','potx',
        'zip','7z','rar','cab','tar','gz','bz2','xz','tgz','tbz','txz','iso','img','wim','esd','ffu','vhd','vhdx','foo'
    )
    foreach ($Ext in $Extensions) {
        $Path = Join-Path $Incoming ("QA_Test_{0}.{0}" -f $Ext)
        "QA Test File for .$Ext" | Set-Content -Path $Path -Encoding UTF8
    }
    $DetectionFiles = @{
        'QA_Detect_Photoshop.psd' = 'Photoshop detection test'
        'QA_Detect_Blender.blend' = 'Blender detection test'
        'QA_Detect_CAD.dwg' = 'CAD detection test'
        'QA_Detect_3DModel.stl' = '3D model detection test'
        'QA_Detect_GameMod.pak' = 'Game mod detection test'
    }
    foreach ($Name in $DetectionFiles.Keys) {
        Set-Content -Path (Join-Path $Incoming $Name) -Value $DetectionFiles[$Name] -Encoding UTF8
    }
    $ProjectFolders = @{
        'QA_Project_DotNet' = @('Sample.sln','Sample.csproj')
        'QA_Project_Python' = @('pyproject.toml','requirements.txt')
        'QA_Project_NodeJS' = @('package.json','package-lock.json')
        'QA_Project_Rust' = @('Cargo.toml')
        'QA_Project_Go' = @('go.mod')
    }
    foreach ($FolderName in $ProjectFolders.Keys) {
        $Folder = Join-Path $Incoming $FolderName
        if (-not (Test-Path $Folder)) { New-Item -ItemType Directory -Path $Folder -Force | Out-Null }
        foreach ($FileName in $ProjectFolders[$FolderName]) {
            Set-Content -Path (Join-Path $Folder $FileName) -Value 'QA project detection marker' -Encoding UTF8
        }
    }
    Write-Host "Repository and Detection QA test files generated in Incoming\." -ForegroundColor Green
    Read-Host "Press Enter to continue" | Out-Null
}

function Remove-RepositoryQATestPack {
    $Incoming = Join-Path $Global:ToolkitRoot 'Incoming'
    if (Test-Path $Incoming) {
        Get-ChildItem -Path $Incoming -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'QA_Test_*' -or $_.Name -like 'QA_Detect_*' -or $_.Name -like 'QA_Project_*' } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Repository QA test files removed from Incoming\." -ForegroundColor Green
    Read-Host "Press Enter to continue" | Out-Null
}

function Clear-RepositoryQATestData {
    $Repo = Join-Path $Global:ToolkitRoot 'Repository'
    if (Test-Path $Repo) {
        Get-ChildItem -Path $Repo -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'QA_Test_*' -or $_.Name -like 'QA_Detect_*' -or $_.Name -like 'QA_Project_*' } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    $Config = Join-Path $Global:ToolkitRoot 'Config'
    foreach ($File in @('software.records.json','document.records.json','script.records.json','package.records.json','archive.records.json','diskimage.records.json')) {
        $P = Join-Path $Config $File
        if (Test-Path $P) {
            try {
                $Data = Get-Content $P -Raw | ConvertFrom-Json
                $Filtered = @($Data | Where-Object { $_.source_name -notlike 'QA_Test_*' -and $_.source_name -notlike 'QA_Detect_*' -and $_.source_name -notlike 'QA_Project_*' -and $_.name -notlike 'QA Test*' -and $_.name -notlike 'QA Detect*' -and $_.name -notlike 'QA Project*' -and $_.path -notlike '*QA_Test_*' -and $_.path -notlike '*QA_Detect_*' -and $_.path -notlike '*QA_Project_*' })
                $Filtered | ConvertTo-Json -Depth 20 | Set-Content -Path $P -Encoding UTF8
            } catch { }
        }
    }
    Write-Host "Repository QA test data cleared." -ForegroundColor Green
    Read-Host "Press Enter to continue" | Out-Null
}

function Show-DevelopmentTools {
    while ($true) {
        Show-ToolkitHeader "DEVELOPMENT TOOLS"
        Write-Host "Development-only tools used for QA and framework validation."
        Write-Host "Remove generated QA data before public release builds." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[1] Generate All Repository / Detection QA Files"
        Write-Host "    Create tiny QA files/folders for supported repository formats and Detection Library rules in Incoming\." -ForegroundColor DarkGray
        Write-Host "[2] Remove Repository QA Pack"
        Write-Host "    Remove QA_Test_* files from Incoming\." -ForegroundColor DarkGray
        Write-Host "[3] Clear Repository Test Data"
        Write-Host "    Remove QA_Test_* files and records from Repository/Config." -ForegroundColor DarkGray
        Write-Host "[B] Back"
        $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()
        switch ($Choice) {
            '1' { New-RepositoryQATestPack }
            '2' { Remove-RepositoryQATestPack }
            '3' { Clear-RepositoryQATestData }
            'B' { return }
        }
    }
}

function Show-FrameworkCenter {
    while ($true) {
        Show-ToolkitHeader "FRAMEWORK CENTER"
        Write-Host "Maintain, repair, audit, and configure the framework itself."
        Write-Host "Framework Center is the house maintenance room."
        Write-Host ""
        Write-Host "Integrity & Health"
        Write-Host "------------------"
        Write-Host "[1] Framework Integrity Check"
        Write-Host "    Verify required framework structure and protected components." -ForegroundColor DarkGray
        Write-Host "[2] Toolkit Health Center"
        Write-Host "    Check framework folders, registry, logs, and required paths." -ForegroundColor DarkGray
        Write-Host "[3] Compatibility Center"
        Write-Host "    Verify Windows, PowerShell, portable mode, dependencies, and readiness." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Repair & Registry"
        Write-Host "-----------------"
        Write-Host "[4] Framework Repair"
        Write-Host "    Repair framework-owned folders, configs, cache, and data." -ForegroundColor DarkGray
        Write-Host "[5] Registry Manager"
        Write-Host "    Rebuild and inspect toolkit registry/cache." -ForegroundColor DarkGray
        Write-Host "[6] Rebuild Toolkit Cache"
        Write-Host "    Rebuild cached framework/toolkit data." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Audit & Migration"
        Write-Host "-----------------"
        Write-Host "[7] Audit Center"
        Write-Host "    Review toolkit structure, modules, and framework findings." -ForegroundColor DarkGray
        Write-Host "[8] Capability Audit"
        Write-Host "    Review framework tools for keep, merge, absorb, hide, or retire decisions." -ForegroundColor DarkGray
        Write-Host "[9] Core Integration Manager"
        Write-Host "    Review framework/core integration points." -ForegroundColor DarkGray
        Write-Host "[10] Legacy Menu Auditor"
        Write-Host "    Find old/deprecated menu patterns and migration targets." -ForegroundColor DarkGray
        Write-Host "[11] Release Candidate Validation"
        Write-Host "    Run final readiness checks before release candidate builds." -ForegroundColor DarkGray
        Write-Host "[12] Metadata Library Manager"
        Write-Host "    Manage learned metadata, backups, and restore framework defaults." -ForegroundColor DarkGray
        Write-Host "[13] Development Tools"
        Write-Host "    Generate/remove QA packs and development-only validation data." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = Read-Host "Selection"
        switch ($Choice.ToUpper()) {
            "1" { Invoke-ToolkitCenterTool "Framework_Integrity_Check" "Framework Integrity Check" }
            "2" { Invoke-ToolkitCenterTool "Toolkit_Health_Center" "Toolkit Health Center" }
            "3" { Invoke-ToolkitCenterTool "Compatibility_Center" "Compatibility Center" }
            "4" { Invoke-ToolkitCenterTool "Framework_Repair" "Framework Repair" }
            "5" { Invoke-ToolkitCenterTool "Registry_Manager" "Registry Manager" }
            "6" { Invoke-ToolkitCenterTool "Rebuild_Toolkit_Cache" "Rebuild Toolkit Cache" }
            "7" { Invoke-ToolkitCenterTool "Audit_Center" "Audit Center" }
            "8" { Invoke-ToolkitCenterTool "Capability_Audit" "Capability Audit" }
            "9" { Invoke-ToolkitCenterTool "Core_Integration_Manager" "Core Integration Manager" }
            "10" { Invoke-ToolkitCenterTool "Legacy_Menu_Auditor" "Legacy Menu Auditor" }
            "11" { Invoke-ToolkitCenterTool "RC1_Validation" "Release Candidate Validation" }
            "12" { Invoke-ToolkitCenterTool "Metadata_Library_Manager" "Metadata Library Manager" }
            "13" { Show-DevelopmentTools }
            "B" { return }
        }
    }
}

function Show-ModuleToolManager {
    while ($true) {
        Show-ToolkitHeader "MODULE TOOL MANAGER"
        Write-Host "Create, validate, package, repair, and maintain modules."
        Write-Host "Module Tool Manager may manage modules. It may NOT modify framework structure."
        Write-Host ""
        Write-Host "Builder"
        Write-Host "-------"
        Write-Host "[1] Add Module Builder"
        Write-Host "    Create modules from pasted scripts, imported scripts, installers, websites, or templates." -ForegroundColor DarkGray
        Write-Host "[2] Module Manager"
        Write-Host "    Manage module records and module lifecycle tasks." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Metadata"
        Write-Host "--------"
        Write-Host "[3] Metadata Manager"
        Write-Host "    View and manage metadata attached to real toolkit objects." -ForegroundColor DarkGray
        Write-Host "[4] Metadata Repair"
        Write-Host "    Repair missing or invalid module metadata." -ForegroundColor DarkGray
        Write-Host "[5] Metadata Description Fixer"
        Write-Host "    Improve missing or weak descriptions for module metadata." -ForegroundColor DarkGray
        Write-Host "[6] Risk Classification"
        Write-Host "    Review and assign module risk classification." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Validation"
        Write-Host "----------"
        Write-Host "[7] Validation Center"
        Write-Host "    Validate modules and related toolkit objects." -ForegroundColor DarkGray
        Write-Host "[8] Module Validator"
        Write-Host "    Validate module structure and required files." -ForegroundColor DarkGray
        Write-Host "[9] Module Health Check"
        Write-Host "    Check user modules for run.bat, run.ps1, tool.json, schema, and entry health." -ForegroundColor DarkGray
        Write-Host "[10] Module Audit"
        Write-Host "    Audit user modules for legacy patterns, deprecated JSON, weak metadata, and duplicates." -ForegroundColor DarkGray
        Write-Host "[11] Validate Modules"
        Write-Host "    Run legacy module validation checks." -ForegroundColor DarkGray
        Write-Host "[12] Runtime Validator"
        Write-Host "    Test runtime launch readiness." -ForegroundColor DarkGray
        Write-Host "[13] Smart Module Validator"
        Write-Host "    Advanced/smart module validation." -ForegroundColor DarkGray
        Write-Host "[14] Static Code Analyzer"
        Write-Host "    Analyze module scripts without running them." -ForegroundColor DarkGray
        Write-Host "[15] Dry Run Module Validator"
        Write-Host "    Simulate module run behavior without making changes." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Reports"
        Write-Host "-------"
        Write-Host "[16] Module Inventory Report"
        Write-Host "    Generate inventory details for modules." -ForegroundColor DarkGray
        Write-Host "[17] Module Rationalization Engine"
        Write-Host "    Review module overlap and rationalization opportunities." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = Read-Host "Selection"
        switch ($Choice.ToUpper()) {
            "1" { Invoke-ToolkitCenterTool "Add_Module_Builder" "Add Module Builder" }
            "2" { Invoke-ToolkitCenterTool "Module_Manager" "Module Manager" }
            "3" { Invoke-ToolkitCenterTool "Metadata_Manager" "Metadata Manager" }
            "4" { Invoke-ToolkitCenterTool "Metadata_Repair_Tool" "Metadata Repair" }
            "5" { Invoke-ToolkitCenterTool "Metadata_Description_Fixer" "Metadata Description Fixer" }
            "6" { Invoke-ToolkitCenterTool "Risk_Classification_Assistant" "Risk Classification Assistant" }
            "7" { Invoke-ToolkitCenterTool "Validation_Center" "Validation Center" }
            "8" { Invoke-ToolkitCenterTool "Module_Validator" "Module Validator" }
            "9" { Invoke-ToolkitCenterTool "Module_Health_Check" "Module Health Check" }
            "10" { Invoke-ToolkitCenterTool "Module_Audit" "Module Audit" }
            "11" { Invoke-ToolkitCenterTool "Validate_Modules" "Validate Modules" }
            "12" { Invoke-ToolkitCenterTool "Runtime_Validator" "Runtime Validator" }
            "13" { Invoke-ToolkitCenterTool "Smart_Module_Validator" "Smart Module Validator" }
            "14" { Invoke-ToolkitCenterTool "Static_Code_Analyzer" "Static Code Analyzer" }
            "15" { Invoke-ToolkitCenterTool "Dry_Run_Module_Validator" "Dry Run Module Validator" }
            "16" { Invoke-ToolkitCenterTool "Module_Inventory_Report" "Module Inventory Report" }
            "17" { Invoke-ToolkitCenterTool "Module_Rationalization_Engine" "Module Rationalization Engine" }
            "B" { return }
        }
    }
}

function Show-RepositoryManagerCenter {
    while ($true) {
        Show-ToolkitHeader "REPOSITORY MANAGER"
        Write-Host "Import, store, organize, and manage toolkit repository content."
        Write-Host "Repository Manager owns Incoming, Repository storage, and software deployment workflows."
        Write-Host ""
        Write-Host "[1] Repository Manager"
        Write-Host "    Scan Incoming, browse Repository, and access software deployment tools." -ForegroundColor DarkGray
        Write-Host "[2] GitHub Puller"
        Write-Host "    Acquire software, releases, source code, and projects from GitHub." -ForegroundColor DarkGray
        Write-Host "[3] Winget Puller"
        Write-Host "    Search Winget packages, install on request, create modules, or save package records." -ForegroundColor DarkGray
        Write-Host "[4] Repository Builder"
        Write-Host "    Create and repair repository folder structure." -ForegroundColor DarkGray
        Write-Host "[5] Repository Help"
        Write-Host "    Open offline repository and deployment help." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = Read-Host "Selection"
        switch ($Choice.ToUpper()) {
            "1" { Invoke-ToolkitCenterTool "Repository_Manager" "Repository Manager" }
            "2" { Invoke-ToolkitCenterTool "GitHub_Puller" "GitHub Puller" }
            "3" { Invoke-ToolkitCenterTool "Winget_Puller" "Winget Puller" }
            "4" { Invoke-ToolkitCenterTool "Installer_Repository_Builder" "Repository Builder" }
            "5" {
                $HelpPath = Join-Path (Join-Path $Global:ToolkitRoot "Framework\Repository_Manager") "run.ps1"
                if (Test-Path $HelpPath) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HelpPath -HelpOnly }
                else { Invoke-ToolkitCenterTool "Repository_Manager" "Repository Manager" }
            }
            "B" { return }
        }
    }
}

function Show-ToolManagerCenter {
    while ($true) {
        Show-ToolkitHeader "TOOL MANAGER"
        Write-Host "Organize, rename, move, clone, hide, remove, scan, and manage existing tools."
        Write-Host "Tool Manager organizes furniture. Module Tool Manager builds furniture."
        Write-Host ""
        Write-Host "[1] Tool Manager"
        Write-Host "    Main tool management center." -ForegroundColor DarkGray
        Write-Host "[2] Tool Modifier"
        Write-Host "    Modify existing tool records and settings." -ForegroundColor DarkGray
        Write-Host "[3] Remove Tool Wizard"
        Write-Host "    Remove tools safely through guided workflow." -ForegroundColor DarkGray
        Write-Host "[4] Duplicate Tool Scanner"
        Write-Host "    Find possible duplicate tools." -ForegroundColor DarkGray
        Write-Host "[5] Category Manager"
        Write-Host "    Create, rename, merge, and manage tool categories." -ForegroundColor DarkGray
        Write-Host "[6] Category Architecture Manager"
        Write-Host "    Manage category structure and architecture." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = Read-Host "Selection"
        switch ($Choice.ToUpper()) {
            "1" { Invoke-ToolkitCenterTool "Tool_Manager" "Tool Manager" }
            "2" { Invoke-ToolkitCenterTool "Tool_Modifier" "Tool Modifier" }
            "3" { Invoke-ToolkitCenterTool "Remove_Tool_Wizard" "Remove Tool Wizard" }
            "4" { Invoke-ToolkitCenterTool "Duplicate_Tool_Scanner" "Duplicate Tool Scanner" }
            "5" { Invoke-ToolkitCenterTool "Category_Manager" "Category Manager" }
            "6" { Invoke-ToolkitCenterTool "Category_Architecture_Manager" "Category Architecture Manager" }
            "B" { return }
        }
    }
}

function Show-HelpCenter {
    while ($true) {
        Show-ToolkitHeader "HELP CENTER"
        Write-Host "Documentation, tutorials, troubleshooting, standards, architecture, and guidance."
        Write-Host ""
        Write-Host "[1] Help & Support"
        Write-Host "    Open the existing support center and guides." -ForegroundColor DarkGray
        Write-Host "[2] How To Guide"
        Write-Host "    Open the toolkit how-to guide." -ForegroundColor DarkGray
        Write-Host "[3] Open Docs Folder"
        Write-Host "    Open framework documentation folder." -ForegroundColor DarkGray
        Write-Host "[4] Open Logs Folder"
        Write-Host "    Open logs folder for diagnostics." -ForegroundColor DarkGray
        Write-Host "[5] View Test Log"
        Write-Host "    Open the testing log for sending results back." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        $Choice = Read-Host "Selection"
        switch ($Choice.ToUpper()) {
            "1" { Show-SupportCenter }
            "2" { Show-ToolkitDocFile "HOW TO USE TOOLKIT" "HOW_TO_USE_TOOLKIT.txt" }
            "3" {
                $DocsPath = Join-Path $Global:ToolkitRoot "Docs"
                if (-not (Test-Path $DocsPath)) { $DocsPath = Join-Path $Global:ToolkitRoot "Docs" }
                if (Test-Path $DocsPath) { Invoke-Item $DocsPath } else { Write-Host "Docs folder not found." -ForegroundColor Yellow; Wait-ToolkitBack }
            }
            "4" {
                $LogsPath = Join-Path $Global:ToolkitRoot "Logs"
                if (-not (Test-Path $LogsPath)) { New-Item -ItemType Directory -Path $LogsPath -Force | Out-Null }
                Invoke-Item $LogsPath
            }
            "5" {
                $LogCandidates = @(
                    (Join-Path (Get-ToolkitRootText) "Logs\test.log"),
                    (Join-Path (Get-ToolkitRootText) "Logs\toolkit_test.log"),
                    (Join-Path (Get-ToolkitRootText) "Logs\test_results.log")
                )
                $FoundLog = $LogCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
                if ($FoundLog) {
                    Show-ToolkitHeader "TEST LOG"
                    Get-Content -Path $FoundLog -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
                    Wait-ToolkitBack
                }
                else {
                    Show-SupportPage "TEST LOG" @(
                        "No test log was found yet.",
                        "",
                        "Logs folder:",
                        ("  " + (Join-Path (Get-ToolkitRootText) "Logs")),
                        "",
                        "Run a validation, audit, or QA workflow first, then return here."
                    )
                }
            }
            "B" { return }
        }
    }
}

# ============================================================
# MAIN MENU - FRAMEWORK 2.0 HOUSE
# ============================================================

while ($true) {

    Show-ToolkitHeader "WINDOWS MODULAR TOOLKIT"

    $Counts = Get-ToolkitMainCounts
    Write-Host "Framework Status ...... $($Counts.Status)"
    Write-Host ""
    Write-Host "Framework Components .. $($Counts.FrameworkCount)"
    Write-Host "Available Modules ..... $($Counts.UserCount)"
    Write-Host "Module Categories ..... $($Counts.CategoryCount)"
    Write-Host ""

    Write-Host "[S] Search Center"
    Write-Host "    Find tools, modules, documentation, repository items, workspace links, and framework resources." -ForegroundColor DarkGray
    Write-Host "[L] Launch Center"
    Write-Host "    Browse and launch toolkit modules, software deployments, installers, and utilities." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host ""
    Write-Host "[W] Workspace Center"
    Write-Host "    Open personal toolkit shortcuts and linked items. Workspace links by default; it does not move/copy modules." -ForegroundColor DarkGray
    Write-Host "[D] Dashboard Center"
    Write-Host "    View toolkit status, health summaries, statistics, recommendations, and recent activity." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host ""
    Write-Host "[F] Framework Center"
    Write-Host "    Maintain, repair, audit, and configure the framework itself." -ForegroundColor DarkGray
    Write-Host "[M] Module Tool Manager"
    Write-Host "    Create, validate, package, repair, and maintain modules." -ForegroundColor DarkGray
    Write-Host "[R] Repository Manager"
    Write-Host "    Scan Incoming, organize Repository items, and manage software deployments." -ForegroundColor DarkGray
    Write-Host "[T] Tool Manager"
    Write-Host "    Organize, rename, move, clone, hide, remove, scan, and manage existing tools." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host ""
    Write-Host "[H] Help Center"
    Write-Host "    Documentation, tutorials, troubleshooting, standards, architecture, and guidance." -ForegroundColor DarkGray
    Write-Host "[Q] Quit"
    Write-Host ""

    $Choice = (Read-Host "Selection").Trim().ToUpperInvariant()

    if ($Choice -eq "Q") {
        Write-Host ""
        Write-Host "Exiting Windows Modular Toolkit..."
        exit 0
    }

    switch ($Choice) {
        "S" { Show-SearchCenter }
        "L" { Show-OpenModules }
        "W" { Invoke-ToolkitCenterTool "Workspace" "Workspace Center" }
        "D" { Show-DashboardCenter }
        "F" { Show-FrameworkCenter }
        "M" { Show-ModuleToolManager }
        "R" { Show-RepositoryManagerCenter }
        "T" { Show-ToolManagerCenter }
        "H" { Show-HelpCenter }
        "Q" { exit 0 }
        default { Show-ToolkitStatus "WARN" "Unknown selection: $Choice"; Start-Sleep -Milliseconds 700 }
    }
}
