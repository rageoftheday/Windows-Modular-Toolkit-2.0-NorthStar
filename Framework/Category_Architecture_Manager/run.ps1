# ============================================================
# CATEGORY ARCHITECTURE MANAGER
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "CATEGORY ARCHITECTURE MANAGER" `
    -RequiresAdmin $false `
    -ScriptBlock {

    $ModulesPath = Join-Path $Root "modules"

    function Get-CategorySuggestion {

        param(
            [string]$Folder,
            [string]$Name,
            [string]$Subcategory
        )

        $Text = "$Folder $Name $Subcategory".ToLower()

        if ($Text -match "account|logon|logged|kerberos|privs|users|groups|audit|policy|defender|threat|unsigned|bitlocker|firewall|fw_") {
            return "Security Tools"
        }

        if ($Text -match "adapter|arp|dns|net_|network|ping|pkt|port|proxy|wifi|winrm|internet|tcp|smb|domain|cert|mdm") {
            return "Network Tools"
        }

        if ($Text -match "clear|cleanup|temp|thumb|recent|recycle|prefetch|browser|cache|wsreset") {
            return "Cleanup Tools"
        }

        if ($Text -match "disk|chkdsk|defrag|storage|vss|large_files|folder_size") {
            return "Disk and Storage"
        }

        if ($Text -match "dism|sfc|repair|wmi|system_file|comp_store") {
            return "Windows Repair"
        }

        if ($Text -match "winget|psmod|rsat|setup|install|dependency") {
            return "Setup and Dependencies"
        }

        if ($Text -match "battery|bios|boot|cpu|gpu|ram|uptime|power|hardware|sysinfo|tpm|wake|smart_status|quick_summary") {
            return "System Information"
        }

        if ($Text -match "service|svc|process|startup|task|kill|pid") {
            return "Process and Services"
        }

        if ($Text -match "wsl|sandbox|hyperv|feature|feat_") {
            return "Windows Features"
        }

        if ($Text -match "powershell|remote_signed|exec_policy") {
            return "PowerShell Utilities"
        }

        if ($Text -match "print") {
            return "Printer Tools"
        }

        if ($Text -match "kernel|driver") {
            return "Drivers and Kernel"
        }

        if ($Text -match "safemode|activation") {
            return "Boot and Recovery"
        }

        if ($Text -match "toolkit|validator|registry|metadata|dashboard|runtime|bootstrap|category|search|manager") {
            return "Toolkit Management"
        }

        return $null
    }

    function Show-CategoryStats {

        Clear-Host

        Write-Host "============================================================"
        Write-Host "              CATEGORY ARCHITECTURE STATS"
        Write-Host "============================================================"
        Write-Host ""

        $Items = @()

        Get-ChildItem $ModulesPath -Directory | ForEach-Object {

            $JsonPath = Join-Path $_.FullName "tool.json"

            if (Test-Path $JsonPath) {

                try {
                    $Json = Get-Content $JsonPath -Raw | ConvertFrom-Json

                    $Items += [PSCustomObject]@{
                        Category = $Json.category
                        Folder = $_.Name
                    }
                }
                catch {}
            }
        }

        $Items |
            Group-Object Category |
            Sort-Object Count -Descending |
            ForEach-Object {
                Write-Host ("{0,-30} {1}" -f $_.Name, $_.Count)
            }

        Write-Host ""
        Pause-Toolkit
    }

    function Analyze-CategoryMoves {

        Clear-Host

        Write-Host "============================================================"
        Write-Host "              CATEGORY MOVE ANALYSIS"
        Write-Host "============================================================"
        Write-Host ""

        $Moves = 0

        Get-ChildItem $ModulesPath -Directory | ForEach-Object {

            $Module = $_
            $JsonPath = Join-Path $Module.FullName "tool.json"

            if (Test-Path $JsonPath) {

                try {
                    $Json = Get-Content $JsonPath -Raw | ConvertFrom-Json

                    $Suggested = Get-CategorySuggestion `
                        -Folder $Module.Name `
                        -Name $Json.name `
                        -Subcategory $Json.subcategory

                    if ($Suggested -and $Suggested -ne $Json.category) {

                        Write-Host "$($Module.Name)" -ForegroundColor Yellow
                        Write-Host "  Current   : $($Json.category)"
                        Write-Host "  Suggested : $Suggested"
                        Write-Host ""

                        $Moves++
                    }
                }
                catch {}
            }
        }

        Write-Host "============================================================"
        Write-Host "Suggested Moves: $Moves"
        Write-Host "============================================================"
        Write-Host ""

        Pause-Toolkit
    }

    function Apply-CategoryMoves {

        Clear-Host

        Write-Host "============================================================"
        Write-Host "              APPLY CATEGORY ARCHITECTURE"
        Write-Host "============================================================"
        Write-Host ""

        Write-Host "This will update module category fields using metadata rules."
        Write-Host "Back up your toolkit first if you want a restore point."
        Write-Host ""

        $Confirm = Read-Host "Type APPLY to continue"

        if ($Confirm -ne "APPLY") {
            Write-Host ""
            Write-Host "Cancelled."
            Pause-Toolkit
            return
        }

        $Updated = 0

        Get-ChildItem $ModulesPath -Directory | ForEach-Object {

            $Module = $_
            $JsonPath = Join-Path $Module.FullName "tool.json"

            if (Test-Path $JsonPath) {

                try {
                    $Json = Get-Content $JsonPath -Raw | ConvertFrom-Json

                    $Suggested = Get-CategorySuggestion `
                        -Folder $Module.Name `
                        -Name $Json.name `
                        -Subcategory $Json.subcategory

                    if ($Suggested -and $Suggested -ne $Json.category) {

                        $Json.category = $Suggested

                        $Json |
                            ConvertTo-Json -Depth 10 |
                            Set-Content $JsonPath -Encoding UTF8

                        Write-Host "[MOVED] $($Module.Name) -> $Suggested" -ForegroundColor Green

                        $Updated++
                    }
                }
                catch {
                    Write-Host "[FAIL] $($Module.Name)" -ForegroundColor Red
                }
            }
        }

        Write-Host ""
        Write-Host "Category Moves Applied: $Updated"
        Write-Host ""

        Pause-Toolkit
    }

    while ($true) {

        Clear-Host

        Write-Host "============================================================"
        Write-Host "          CATEGORY ARCHITECTURE MANAGER"
        Write-Host "============================================================"
        Write-Host ""
        Write-Host "[1] Show Category Stats"
        Write-Host "[2] Analyze Suggested Moves"
        Write-Host "[3] Apply Suggested Moves"
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        Write-Host "============================================================"
        Write-Host ""

        $Choice = Read-Host "Selection"

        switch ($Choice.ToUpper()) {

            "1" {
                Show-CategoryStats
            }

            "2" {
                Analyze-CategoryMoves
            }

            "3" {
                Apply-CategoryMoves
            }

            "B" {
                $Global:ToolkitSuppressCompletion = $true
                return
            }
            "Q" {
                $Global:ToolkitSuppressCompletion = $true
                return
            }
        }
    }
}