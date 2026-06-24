# Windows Modular Toolkit Framework 2.0
# Winget Puller - RC Safe Package ID Workflow v4
# Replaces fragile parsed-search workflow with Package ID validation.
# Portable: runs from this module folder; no hardcoded toolkit path.

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

# --- Console / encoding safety for Windows PowerShell 5.1 ---
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
} catch {}

$env:WINGET_DISABLE_INTERACTIVITY = '1'
$env:COLUMNS = '999'

$Script:ModuleFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:ToolkitRoot = Resolve-Path (Join-Path $Script:ModuleFolder '..\..') -ErrorAction SilentlyContinue
if (-not $Script:ToolkitRoot) { $Script:ToolkitRoot = $Script:ModuleFolder }
$Script:ToolkitRoot = [string]$Script:ToolkitRoot

$Script:ModulesFolder = Join-Path $Script:ToolkitRoot 'Modules'
$Script:RepositoryFolder = Join-Path $Script:ToolkitRoot 'Repository'
$Script:WingetRepoFile = Join-Path $Script:RepositoryFolder 'winget.repository.json'
$Script:LogFolder = Join-Path $Script:ToolkitRoot 'Logs'
$Script:LogFile = Join-Path $Script:LogFolder 'winget_puller.log'

foreach ($Folder in @($Script:ModulesFolder, $Script:RepositoryFolder, $Script:LogFolder)) {
    if (-not (Test-Path -LiteralPath $Folder)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    }
}

function Pause-Toolkit {
    Write-Host ''
    Read-Host 'Press Enter to continue' | Out-Null
}

function Write-LogLine([string]$Text) {
    try {
        $Stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath $Script:LogFile -Value "[$Stamp] $Text" -Encoding UTF8
    } catch {}
}

function Show-Header([string]$Title) {
    Clear-Host
    Write-Host '============================================================'
    Write-Host " $Title"
    Write-Host '============================================================'
    Write-Host ''
}

function Get-WingetCommand {
    $Cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($Cmd) { return $Cmd.Source }
    $Fallback = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $Fallback) { return $Fallback }
    return $null
}

function Test-WingetAvailable {
    $Winget = Get-WingetCommand
    if (-not $Winget) { return $false }
    try {
        $null = & $Winget --version 2>$null
        return $true
    } catch {
        return $false
    }
}

function Remove-AnsiText([string]$Text) {
    if ($null -eq $Text) { return '' }
    return ([regex]::Replace($Text, "`e\[[0-9;?]*[ -/]*[@-~]", ''))
}

function Invoke-WingetRaw([string[]]$Arguments) {
    $Winget = Get-WingetCommand
    if (-not $Winget) { return @('Winget is not installed or could not be found.') }
    try {
        return @(& $Winget @Arguments 2>&1 | ForEach-Object { Remove-AnsiText ([string]$_) })
    } catch {
        return @("Winget command failed: $($_.Exception.Message)")
    }
}

function Read-WingetShowOutput([string[]]$Raw, [string]$FallbackId, [string]$FallbackName) {
    $Result = [ordered]@{
        Valid = $false
        Input = $FallbackId
        Id = $FallbackId
        Name = $FallbackName
        Version = 'Unknown'
        Publisher = ''
        Source = 'winget'
        Raw = @($Raw)
        Error = ''
    }

    $Joined = (($Raw | ForEach-Object { [string]$_ }) -join "`n")
    if ($Joined -match 'No package found|No applicable|not found|failed|error|not recognized') {
        $Result.Error = 'Winget could not find a matching package.'
        return [pscustomobject]$Result
    }

    foreach ($Line in @($Raw)) {
        $T = (([string]$Line) -replace '[\u00A0]', ' ').Trim()
        if ([string]::IsNullOrWhiteSpace($T)) { continue }

        # Common winget show format: Found 7-Zip [7zip.7zip]
        if ($T -match '^Found\s+(.+?)\s+\[(.+?)\]\s*$') {
            $Result.Name = $Matches[1].Trim()
            $Result.Id = $Matches[2].Trim()
            $Result.Valid = $true
            continue
        }

        if ($T -match '^Name:\s*(.+)$') { $Result.Name = $Matches[1].Trim(); continue }
        if ($T -match '^(Id|ID):\s*(.+)$') { $Result.Id = $Matches[2].Trim(); $Result.Valid = $true; continue }
        if ($T -match '^Version:\s*(.+)$') { $Result.Version = $Matches[1].Trim(); continue }
        if ($T -match '^Publisher:\s*(.+)$') { $Result.Publisher = $Matches[1].Trim(); continue }
    }

    # Fallback: if show returned useful package fields but no ID line, keep exact fallback ID only if it looks like a real package ID.
    if (-not $Result.Valid -and $FallbackId -match '^[A-Za-z0-9][A-Za-z0-9_.-]+\.[A-Za-z0-9_.-]+$') {
        if ($Joined -match [regex]::Escape($FallbackId) -or $Joined -match '^Name:') {
            $Result.Id = $FallbackId
            $Result.Valid = $true
        }
    }

    if ([string]::IsNullOrWhiteSpace($Result.Name)) { $Result.Name = $Result.Id }
    if ([string]::IsNullOrWhiteSpace($Result.Id)) { $Result.Id = $FallbackId }

    return [pscustomobject]$Result
}

function Invoke-WingetShow([string]$PackageId) {
    $Result = [ordered]@{
        Valid = $false
        Input = $PackageId
        Id = $PackageId
        Name = $PackageId
        Version = 'Unknown'
        Publisher = ''
        Source = 'winget'
        Raw = @()
        Error = ''
    }

    $Winget = Get-WingetCommand
    if (-not $Winget) {
        $Result.Error = 'Winget is not installed or could not be found.'
        return [pscustomobject]$Result
    }

    $CleanId = (($PackageId -replace '[\u00A0]', ' ') -replace '^[\s"'']+|[\s"'']+$', '').Trim()
    if ([string]::IsNullOrWhiteSpace($CleanId)) {
        $Result.Error = 'Package ID was blank.'
        return [pscustomobject]$Result
    }

    Write-LogLine "Validate Package Input: $CleanId"

    # First try the RC-safe exact Package ID path.
    $ExactArgs = @('show','--id',$CleanId,'--source','winget','--accept-source-agreements','--disable-interactivity')
    $RawExact = Invoke-WingetRaw $ExactArgs
    $Exact = Read-WingetShowOutput $RawExact $CleanId $CleanId
    if ($Exact.Valid) { return $Exact }

    # If the user typed a search term/moniker like "7zip", try winget show as a query.
    # This does not install anything; it only asks Winget to resolve details.
    $QueryArgs = @('show',$CleanId,'--source','winget','--accept-source-agreements','--disable-interactivity')
    $RawQuery = Invoke-WingetRaw $QueryArgs
    $Query = Read-WingetShowOutput $RawQuery $CleanId $CleanId
    if ($Query.Valid -and $Query.Id -match '^[A-Za-z0-9][A-Za-z0-9_.-]+\.[A-Za-z0-9_.-]+$') { return $Query }

    # Last fallback for common moniker/name inputs: use winget search only to show guidance, not to select automatically.
    $RawSearch = Invoke-WingetRaw @('search','--source','winget','--accept-source-agreements','--disable-interactivity',$CleanId)
    $Result.Raw = @($RawExact + '' + $RawQuery + '' + $RawSearch)
    $Result.Error = 'Input was not validated as an exact Package ID. Use a full ID such as 7zip.7zip.'
    return [pscustomobject]$Result
}

function Convert-ToSafeFolderName([string]$Text) {
    $Safe = ($Text.ToUpperInvariant() -replace '[^A-Z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($Safe)) { $Safe = 'PACKAGE' }
    return $Safe
}

function Convert-ToJsonString($Object) {
    return ($Object | ConvertTo-Json -Depth 8)
}

function Get-WingetModuleBaseName([string]$PackageId, [string]$PackageName) {
    # Folder rule for RC: use the product part of the Winget ID, not vendor_product.
    # Examples:
    #   7zip.7zip                  -> 7ZIP
    #   Microsoft.PowerShell       -> POWERSHELL
    #   Microsoft.VisualStudioCode -> VISUALSTUDIOCODE
    #   Google.Chrome              -> CHROME
    #   Git.Git                    -> GIT
    $CleanId = (($PackageId -replace '[\u00A0]', ' ') -replace '^[\s"'']+|[\s"'']+$', '').Trim()
    $Base = ''

    if (-not [string]::IsNullOrWhiteSpace($CleanId)) {
        $Parts = @($CleanId -split '\.' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($Parts.Count -ge 1) {
            $Base = $Parts[-1]
        }
    }

    if ([string]::IsNullOrWhiteSpace($Base) -and -not [string]::IsNullOrWhiteSpace($PackageName)) {
        $Base = $PackageName
    }

    return (Convert-ToSafeFolderName $Base)
}

function New-WingetModule($Package) {
    $NameSafe = Get-WingetModuleBaseName $Package.Id $Package.Name
    $ModuleName = "WINGET_INSTALL_$NameSafe"
    $ModuleFolder = Join-Path $Script:ModulesFolder $ModuleName
    New-Item -ItemType Directory -Path $ModuleFolder -Force | Out-Null

    $RunPs1 = @"
# Auto-generated Winget install module
# Package: $($Package.Name)
# ID: $($Package.Id)

Set-StrictMode -Version 2.0
`$ErrorActionPreference = 'Continue'
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(`$false)
    `$OutputEncoding = [System.Text.UTF8Encoding]::new(`$false)
} catch {}

`$env:WINGET_DISABLE_INTERACTIVITY = '1'
`$PackageId = '$($Package.Id.Replace("'", "''"))'

Write-Host 'Installing Winget package:' `$PackageId
Write-Host ''
winget install -e --id `$PackageId --source winget --accept-source-agreements --accept-package-agreements
Write-Host ''
Write-Host 'Winget command finished or returned.'
"@

    $RunBat = @"
@echo off
setlocal
cd /d `"%~dp0`"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0run.ps1`"
set `"TOOLKIT_MODULE_EXITCODE=%ERRORLEVEL%`"

REM If launched from inside the toolkit, the framework pauses after return.
REM If double-clicked or run directly, pause here so output stays visible.
if /I not `"%TOOLKIT_LAUNCHED%`"==`"1`" (
    echo.
    pause
)

endlocal & exit /b %TOOLKIT_MODULE_EXITCODE%
"@

    $ToolJson = [ordered]@{
        name = "Install $($Package.Name)"
        category = 'Software'
        subcategory = 'Winget'
        description = "Installs $($Package.Name) using Winget. Package ID: $($Package.Id)"
        keywords = @('winget','install','software',$Package.Name,$Package.Id)
        risk = 'Medium'
        requires_admin = $true
        supports_logs = $false
        supports_export = $false
        entry = 'run.bat'
        dependencies = @('winget')
        hidden = $false
    }

    Set-Content -LiteralPath (Join-Path $ModuleFolder 'run.ps1') -Value $RunPs1 -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $ModuleFolder 'run.bat') -Value $RunBat -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $ModuleFolder 'tool.json') -Value (Convert-ToJsonString $ToolJson) -Encoding UTF8

    Write-LogLine "Created module: $ModuleName for $($Package.Id)"

    # Best-effort registry/cache refresh marker. Different builds use different cache systems.
    try {
        $CacheFolder = Join-Path $Script:ToolkitRoot 'Cache'
        if (Test-Path -LiteralPath $CacheFolder) {
            Get-ChildItem -LiteralPath $CacheFolder -Filter '*module*cache*.json' -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}

    return $ModuleFolder
}

function Open-WingetWebsites([string]$Query) {
    $Encoded = [uri]::EscapeDataString($Query)
    $Urls = @(
        "https://winget.run/search?query=$Encoded",
        "https://winstall.app/apps?search=$Encoded",
        'https://learn.microsoft.com/windows/package-manager/winget/'
    )
    foreach ($Url in $Urls) {
        try { Start-Process $Url } catch {}
    }
}

function Show-WingetWebsitesMenu {
    while ($true) {
        Show-Header 'WINGET WEBSITES & HELP'
        Write-Host '[1] Open winget.run'
        Write-Host '[2] Open winstall.app'
        Write-Host '[3] Open Microsoft Winget Docs'
        Write-Host '[4] Open all'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch -Regex ($Choice) {
            '^(1)$' { Start-Process 'https://winget.run'; continue }
            '^(2)$' { Start-Process 'https://winstall.app'; continue }
            '^(3)$' { Start-Process 'https://learn.microsoft.com/windows/package-manager/winget/'; continue }
            '^(4)$' { Start-Process 'https://winget.run'; Start-Process 'https://winstall.app'; Start-Process 'https://learn.microsoft.com/windows/package-manager/winget/'; continue }
            '^(B|b)$' { return }
        }
    }
}

function Show-PackageActionMenu($Package) {
    while ($true) {
        Show-Header 'WINGET PACKAGE'
        Write-Host 'Name:'
        Write-Host "  $($Package.Name)"
        Write-Host 'Package ID:'
        Write-Host "  $($Package.Id)"
        Write-Host 'Version:'
        Write-Host "  $($Package.Version)"
        if ($Package.Publisher) {
            Write-Host 'Publisher:'
            Write-Host "  $($Package.Publisher)"
        }
        Write-Host 'Source:'
        Write-Host '  winget'
        Write-Host 'Command:'
        Write-Host "  winget install -e --id $($Package.Id) --source winget"
        Write-Host ''
        Write-Host '[1] Install Now'
        Write-Host '    Ask for confirmation, then run the Winget install command.'
        Write-Host '[2] Copy Command'
        Write-Host '    Copy the install command to the clipboard.'
        Write-Host '[3] Create Module'
        Write-Host '    Automatically create run.ps1, run.bat, and tool.json.'
        Write-Host '[4] Open Winget Package Websites'
        Write-Host '    Open winget.run and winstall searches for this package.'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'

        switch -Regex ($Choice) {
            '^(1)$' {
                Write-Host ''
                $Confirm = Read-Host "Install $($Package.Id) now? Type Y to continue"
                if ($Confirm -match '^(Y|y)$') {
                    Write-LogLine "Install started: $($Package.Id)"
                    winget install -e --id $Package.Id --source winget --accept-source-agreements --accept-package-agreements
                    Write-LogLine "Install finished/returned: $($Package.Id)"
                    Pause-Toolkit
                }
                continue
            }
            '^(2)$' {
                $Command = "winget install -e --id $($Package.Id) --source winget"
                try {
                    Set-Clipboard -Value $Command
                    Write-Host ''
                    Write-Host 'Copied to clipboard:'
                    Write-Host $Command
                } catch {
                    Write-Host ''
                    Write-Host 'Clipboard unavailable. Command:'
                    Write-Host $Command
                }
                Pause-Toolkit
                continue
            }
            '^(3)$' {
                $Folder = New-WingetModule $Package
                Write-Host ''
                Write-Host 'Module created:'
                Write-Host "  $Folder"
                Write-Host ''
                Write-Host 'Module uses standard triplet: run.ps1, run.bat, and tool.json.'
                Pause-Toolkit
                continue
            }
            '^(4)$' {
                Open-WingetWebsites $Package.Id
                continue
            }
            '^(B|b)$' { return }
        }
    }
}

function Start-InstallCreateById {
    while ($true) {
        Show-Header 'INSTALL / CREATE BY PACKAGE ID'
        Write-Host 'Enter the exact Winget Package ID.'
        Write-Host ''
        Write-Host 'Examples:'
        Write-Host '  7zip.7zip'
        Write-Host '  Microsoft.PowerShell'
        Write-Host '  Microsoft.VisualStudioCode'
        Write-Host '  Git.Git'
        Write-Host '  Mozilla.Firefox'
        Write-Host '  Google.Chrome'
        Write-Host ''
        Write-Host 'The toolkit will validate the ID with winget show before install/module creation.'
        Write-Host ''
        $PackageId = Read-Host 'Package ID (blank or B to go back)'
        if ([string]::IsNullOrWhiteSpace($PackageId) -or $PackageId -match '^(B|b)$') { return }

        Show-Header 'VALIDATING WINGET PACKAGE'
        Write-Host "Checking: $PackageId"
        Write-Host ''
        $Package = Invoke-WingetShow $PackageId

        if (-not $Package.Valid) {
            Write-Host 'Package ID could not be validated.'
            Write-Host ''
            if ($Package.Error) { Write-Host "Reason: $($Package.Error)" }
            Write-Host ''
            Write-Host '[1] Try Another Package ID'
            Write-Host '[2] Open Search Websites'
            Write-Host '[B] Back'
            Write-Host ''
            $Choice = Read-Host 'Selection'
            if ($Choice -eq '2') { Open-WingetWebsites $PackageId }
            elseif ($Choice -match '^(B|b)$') { return }
            continue
        }

        Show-PackageActionMenu $Package
    }
}

function Show-MainMenu {
    while ($true) {
        Show-Header 'WINGET PULLER'
        if (Test-WingetAvailable) {
            $Winget = Get-WingetCommand
            $Version = try { (& $Winget --version 2>$null | Select-Object -First 1) } catch { 'Unknown' }
            Write-Host 'Winget Found:'
            Write-Host "  Path    : $Winget"
            Write-Host "  Version : $Version"
        } else {
            Write-Host 'Winget was not found on this computer.'
            Write-Host 'Install App Installer from Microsoft Store or use Microsoft Winget documentation.'
        }
        Write-Host ''
        Write-Host '[1] Install/Create By Package ID'
        Write-Host '    Validate exact Package ID, then install, copy command, create module, or save repository.'
        Write-Host '[2] Winget Websites & Search'
        Write-Host '    Open winget.run, winstall.app, or Microsoft documentation.'
        Write-Host '[3] Winget Help'
        Write-Host '[B] Back'
        Write-Host ''
        $Choice = Read-Host 'Selection'
        switch -Regex ($Choice) {
            '^(1)$' { Start-InstallCreateById; continue }
            '^(2)$' { Show-WingetWebsitesMenu; continue }
            '^(3)$' { Show-WingetHelp; continue }
            '^(B|b|Q|q)$' { return }
        }
    }
}

function Show-WingetHelp {
    Show-Header 'WINGET HELP'
    Write-Host 'Winget Puller RC-safe workflow:'
    Write-Host ''
    Write-Host '1. Use winget.run or winstall.app to find the exact Package ID.'
    Write-Host '2. Choose Install/Create By Package ID.'
    Write-Host '3. Paste the exact ID, for example 7zip.7zip.'
    Write-Host '4. Toolkit validates the ID with winget show before doing anything else.'
    Write-Host '5. After validation you can install, copy the command, create a module, or open Winget package websites.'
    Write-Host ''
    Write-Host 'Useful Package IDs:'
    Write-Host '  7zip.7zip'
    Write-Host '  Microsoft.PowerShell'
    Write-Host '  Microsoft.VisualStudioCode'
    Write-Host '  Git.Git'
    Write-Host '  Mozilla.Firefox'
    Write-Host '  Google.Chrome'
    Write-Host '  Notepad++.Notepad++'
    Write-Host '  VideoLAN.VLC'
    Write-Host ''
    Write-Host 'Troubleshooting:'
    Write-Host '  If validation fails, run: winget source update --name winget'
    Write-Host '  If Winget is missing, install App Installer from Microsoft Store.'
    Write-Host '  Corporate networks may block Winget sources.'
    Pause-Toolkit
}

Show-MainMenu
