$Root = Resolve-Path "$PSScriptRoot\..\.."
. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "METADATA DESCRIPTION FIXER" `
    -RequiresAdmin $false `
    -ScriptBlock {

    $Modules = Get-ChildItem "$Root\modules" -Recurse -Filter "tool.json"
    $Updated = 0

    function Get-Description {
        param($Name)

        $Clean = $Name -replace "_", " "

        switch -Regex ($Name) {

            # --- WINGET INSTALLS ---
            "Winget.*7zip|Winget.*7-Zip" { return "Installs 7-Zip using Winget." }
            "Winget.*Git" { return "Installs Git using Winget." }
            "Winget.*Nmap" { return "Installs Nmap using Winget." }
            "Winget.*NPP|Winget.*Notepad" { return "Installs Notepad++ using Winget." }
            "Winget.*Sysinternals" { return "Installs Microsoft Sysinternals using Winget." }
            "Winget.*Windirstat" { return "Installs WinDirStat using Winget." }
            "Winget.*LHM|LibreHardware" { return "Installs LibreHardwareMonitor using Winget." }

            # --- POWERSHELL MODULES ---
            "Psmod.*Carbon" { return "Installs the Carbon PowerShell module." }
            "Psmod.*Excel|ImportExcel" { return "Installs the ImportExcel PowerShell module." }
            "Psmod.*Wupdate|PSWindowsUpdate" { return "Installs the PSWindowsUpdate PowerShell module." }

            # --- RSAT ---
            "RSAT.*DNS" { return "Installs RSAT DNS management tools." }
            "RSAT.*AD" { return "Installs RSAT Active Directory management tools." }
            "RSAT.*GP" { return "Installs RSAT Group Policy management tools." }
            "RSAT.*Hyperv|RSAT.*Hyper-V" { return "Installs RSAT Hyper-V management tools." }

            # --- SYSTEM / REPAIR ---
            "DNS.*Flush" { return "Clears the Windows DNS resolver cache." }
            "DISM" { return "Repairs the Windows component store using DISM." }
            "SFC|System.*File" { return "Scans and repairs Windows system files." }
            "Net.*Reset" { return "Resets Windows network configuration." }
            "Ping|Trace" { return "Tests network connectivity and route path." }
            "Port.*Test" { return "Tests connectivity to a remote TCP port." }
            "Check.*Disk|Chkdsk" { return "Scans disk volumes for file system errors." }
            "Bitlocker" { return "Displays BitLocker encryption status." }
            "Startup" { return "Lists configured startup programs." }
            "Service|Svc" { return "Displays Windows service information." }
            "Driver" { return "Displays installed driver information." }
            "WMI" { return "Checks or repairs Windows Management Instrumentation." }
            "WSL" { return "Runs a Windows Subsystem for Linux management task." }

            default {
                return "Runs the $Clean toolkit utility."
            }
        }
    }

    foreach ($File in $Modules) {

        try {
            $Json = Get-Content $File.FullName -Raw | ConvertFrom-Json
        }
        catch {
            Write-Host "[SKIP] Invalid JSON: $($File.FullName)" -ForegroundColor Yellow
            continue
        }

        # 🔥 IMPROVED MATCHING LOGIC
        if (
            -not $Json.description -or
            $Json.description.Length -lt 20 -or
            $Json.description -match "rebuild|original bat|tool|module|does|stuff|Manages software packages using Winget|Manages PowerShell modules|Installs or manages RSAT tools|Executes system diagnostics"
        ) {

            $NewDesc = Get-Description $Json.name

            $Json.description = $NewDesc

            $Json | ConvertTo-Json -Depth 5 | Set-Content $File.FullName -Encoding UTF8

            Write-Host "[FIXED] $($Json.name)" -ForegroundColor Green
            $Updated++
        }
    }

    Write-Host ""
    Write-Host "Descriptions fixed: $Updated"
    Write-Host ""

    # 39D_STANDARD_BACK_PAUSE
    Write-Host ""
    Write-Host "[B] Back"
    do { $BackChoice = (Read-Host "Selection").Trim().ToUpper() } until ($BackChoice -eq "B")
}