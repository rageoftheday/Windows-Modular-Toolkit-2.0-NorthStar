# ============================================================
# RISK CLASSIFICATION ASSISTANT
# ============================================================

$Root = Resolve-Path "$PSScriptRoot\..\.."

. "$Root\core\bootstrap.ps1"

Invoke-ToolkitModule `
    -ModuleName "RISK CLASSIFICATION ASSISTANT" `
    -RequiresAdmin $false `
    -ScriptBlock {

    $ModulesPath = Join-Path $Root "modules"

    # ========================================================
    # RISK SUGGESTIONS
    # ========================================================

    function Get-RiskSuggestion {

        param(
            [string]$Name,
            [bool]$RequiresAdmin
        )

        $Lower = $Name.ToLower()

        # ----------------------------------------------------
        # MODERATE
        # ----------------------------------------------------

        if (
            $Lower -match "rebuild|repair|reset|delete|kill|flush|format|dism|wmi|bitlocker"
        ) {

            return "Moderate"
        }

        # ----------------------------------------------------
        # DANGEROUS
        # ----------------------------------------------------

        if (
            $Lower -match "disk_fix|fullrepair|reregister"
        ) {

            return "Dangerous"
        }

        # ----------------------------------------------------
        # ADMIN-ONLY
        # ----------------------------------------------------

        if ($RequiresAdmin) {

            return "Moderate"
        }

        # ----------------------------------------------------
        # SAFE
        # ----------------------------------------------------

        return "Safe"
    }

    # ========================================================
    # SUBCATEGORY SUGGESTIONS
    # ========================================================

    function Get-SubcategorySuggestion {

        param(
            [string]$Name
        )

        $Lower = $Name.ToLower()

        # ----------------------------------------------------
        # PREFIX RULES
        # ----------------------------------------------------

        if ($Lower.StartsWith("powershell_")) {
            return "PowerShell Utilities"
        }

        if ($Lower.StartsWith("winget_")) {
            return "Package Management"
        }

        if ($Lower.StartsWith("wmi_")) {
            return "WMI Management"
        }

        if ($Lower.StartsWith("wsl_")) {
            return "WSL Management"
        }

        if ($Lower.StartsWith("rsat_")) {
            return "RSAT Tools"
        }

        if ($Lower.StartsWith("setup_")) {
            return "Toolkit Setup"
        }

        if ($Lower.StartsWith("toolkit_")) {
            return "Toolkit Management"
        }

        # ----------------------------------------------------
        # SECURITY / ACCOUNTS
        # ----------------------------------------------------

        if ($Lower -match "account|logon|logged|kerberos|privs|users|groups|audit|policy") {
            return "Security and Accounts"
        }

        # ----------------------------------------------------
        # NETWORK
        # ----------------------------------------------------

        if ($Lower -match "adapter|arp|dns|net_|network|ping|pkt|port|proxy|wifi|winrm|internet|tcp") {
            return "Network Tools"
        }

        # ----------------------------------------------------
        # CLEANUP
        # ----------------------------------------------------

        if ($Lower -match "clear|cleanup|temp|thumb|recent|recycle|prefetch|browser|cache") {
            return "Cleanup Tools"
        }

        # ----------------------------------------------------
        # DISK / STORAGE
        # ----------------------------------------------------

        if ($Lower -match "disk|chkdsk|defrag|storage|vss|large_files|folder_size") {
            return "Disk and Storage"
        }

        # ----------------------------------------------------
        # WINDOWS REPAIR
        # ----------------------------------------------------

        if ($Lower -match "dism|sfc|repair|wmi|system_file|comp_store") {
            return "Windows Repair"
        }

        # ----------------------------------------------------
        # SETUP / DEPENDENCIES
        # ----------------------------------------------------

        if ($Lower -match "winget|psmod|rsat|setup|install") {
            return "Setup and Dependencies"
        }

        # ----------------------------------------------------
        # SYSTEM INFORMATION
        # ----------------------------------------------------

        if ($Lower -match "battery|bios|boot|cpu|gpu|ram|uptime|power|hardware|sysinfo|tpm") {
            return "System Information"
        }

        # ----------------------------------------------------
        # PROCESSES / SERVICES
        # ----------------------------------------------------

        if ($Lower -match "service|svc|process|startup|task|kill|pid") {
            return "Process and Services"
        }

        # ----------------------------------------------------
        # SECURITY TOOLS
        # ----------------------------------------------------

        if ($Lower -match "firewall|fw_|defender|threat|unsigned|bitlocker") {
            return "Security Tools"
        }

        # ----------------------------------------------------
        # WINDOWS FEATURES
        # ----------------------------------------------------

        if ($Lower -match "wsl|sandbox|hyperv|feature|feat_") {
            return "Windows Features"
        }

        # ----------------------------------------------------
        # PRINTERS
        # ----------------------------------------------------

        if ($Lower -match "print") {
            return "Printer Tools"
        }

        # ----------------------------------------------------
        # NETWORK / IDENTITY
        # ----------------------------------------------------

        if ($Lower -match "cert|domain|mdm|smb|named_pipes") {
            return "Network and Identity"
        }

        # ----------------------------------------------------
        # DRIVERS / KERNEL
        # ----------------------------------------------------

        if ($Lower -match "kernel|driver") {
            return "Drivers and Kernel"
        }

        # ----------------------------------------------------
        # SYSTEM INFORMATION
        # ----------------------------------------------------

        if ($Lower -match "wake|smart_status|quick_summary") {
            return "System Information"
        }

        # ----------------------------------------------------
        # POWERSHELL CONFIG
        # ----------------------------------------------------

        if ($Lower -match "remote_signed") {
            return "PowerShell Configuration"
        }

        # ----------------------------------------------------
        # BOOT / RECOVERY
        # ----------------------------------------------------

        if ($Lower -match "safemode") {
            return "Boot and Recovery"
        }

        # ----------------------------------------------------
        # WINDOWS UTILITIES
        # ----------------------------------------------------

        if ($Lower -match "activation|wsreset") {
            return "Windows Utilities"
        }

        # ----------------------------------------------------
        # NEEDS REVIEW
        # ----------------------------------------------------

        if ($Lower -match "^invalid$") {
            return "Needs Review"
        }

        return $null
    }

    # ========================================================
    # MENU LOOP
    # ========================================================

    while ($true) {

        Clear-Host

        Write-Host "============================================================"
        Write-Host "         RISK CLASSIFICATION ASSISTANT"
        Write-Host "============================================================"
        Write-Host ""
        Write-Host "[1] Analyze Risk Suggestions"
        Write-Host "[2] Apply Suggested Risk Fixes"
        Write-Host "[3] Apply Suggested Subcategories"
        Write-Host "[4] Full Metadata Intelligence Pass"
        Write-Host ""
        Write-Host "[B] Back"
        Write-Host ""
        Write-Host "============================================================"
        Write-Host ""

        $Choice = Read-Host "Selection"

        switch ($Choice.ToUpper()) {

            # ------------------------------------------------
            # ANALYZE
            # ------------------------------------------------

            "1" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "            RISK ANALYSIS REPORT"
                Write-Host "============================================================"
                Write-Host ""

                $SuggestionsFound = 0

                Get-ChildItem $ModulesPath -Directory | ForEach-Object {

                    $JsonPath = Join-Path $_.FullName "tool.json"

                    if (Test-Path $JsonPath) {

                        try {

                            $Json = Get-Content `
                                $JsonPath `
                                -Raw | ConvertFrom-Json

                            if ($Json.risk -eq "Unknown") {

                                $Suggested = Get-RiskSuggestion `
                                    -Name $_.Name `
                                    -RequiresAdmin $Json.requires_admin

                                Write-Host "$($_.Name)" `
                                    -ForegroundColor Yellow

                                Write-Host "  Current Risk : Unknown"
                                Write-Host "  Suggested    : $Suggested"
                                Write-Host ""
                                $SuggestionsFound++
                            }
                        }
                        catch {}
                    }
                }

                if ($SuggestionsFound -eq 0) {
                    Write-Host "No risk suggestions found. Existing module risk values may already be classified." -ForegroundColor Green
                    Write-Host ""
                }

                Pause-Toolkit
            }

            # ------------------------------------------------
            # APPLY RISK FIXES
            # ------------------------------------------------

            "2" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "           APPLYING RISK CLASSIFICATIONS"
                Write-Host "============================================================"
                Write-Host ""

                $Fixed = 0

                Get-ChildItem $ModulesPath -Directory | ForEach-Object {

                    $JsonPath = Join-Path $_.FullName "tool.json"

                    if (Test-Path $JsonPath) {

                        try {

                            $Json = Get-Content `
                                $JsonPath `
                                -Raw | ConvertFrom-Json

                            if ($Json.risk -eq "Unknown") {

                                $Suggested = Get-RiskSuggestion `
                                    -Name $_.Name `
                                    -RequiresAdmin $Json.requires_admin

                                $Json.risk = $Suggested

                                $Json |
                                    ConvertTo-Json -Depth 10 |
                                    Set-Content `
                                        $JsonPath `
                                        -Encoding UTF8

                                Write-Host "[FIXED] $($_.Name) -> $Suggested" `
                                    -ForegroundColor Green

                                $Fixed++
                            }
                        }
                        catch {

                            Write-Host "[FAIL] $($_.Name)" `
                                -ForegroundColor Red
                        }
                    }
                }

                Write-Host ""
                Write-Host "Risk Fixes Applied: $Fixed"
                Write-Host ""

                Pause-Toolkit
            }

            # ------------------------------------------------
            # APPLY SUBCATEGORY FIXES
            # ------------------------------------------------

            "3" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "         APPLYING SUBCATEGORY FIXES"
                Write-Host "============================================================"
                Write-Host ""

                $Fixed = 0

                Get-ChildItem $ModulesPath -Directory | ForEach-Object {

                    $JsonPath = Join-Path $_.FullName "tool.json"

                    if (Test-Path $JsonPath) {

                        try {

                            $Json = Get-Content `
                                $JsonPath `
                                -Raw | ConvertFrom-Json

                            if ($Json.subcategory -eq "Migrated Modules") {

                                $Suggested = Get-SubcategorySuggestion `
                                    -Name $_.Name

                                if ($Suggested) {

                                    $Json.subcategory = $Suggested

                                    $Json |
                                        ConvertTo-Json -Depth 10 |
                                        Set-Content `
                                            $JsonPath `
                                            -Encoding UTF8

                                    Write-Host "[FIXED] $($_.Name) -> $Suggested" `
                                        -ForegroundColor Green

                                    $Fixed++
                                }
                            }
                        }
                        catch {

                            Write-Host "[FAIL] $($_.Name)" `
                                -ForegroundColor Red
                        }
                    }
                }

                Write-Host ""
                Write-Host "Subcategory Fixes Applied: $Fixed"
                Write-Host ""

                Pause-Toolkit
            }

            # ------------------------------------------------
            # FULL PASS
            # ------------------------------------------------

            "4" {

                Clear-Host

                Write-Host "============================================================"
                Write-Host "         FULL METADATA INTELLIGENCE PASS"
                Write-Host "============================================================"
                Write-Host ""

                $RiskFixed = 0
                $SubFixed = 0

                Get-ChildItem $ModulesPath -Directory | ForEach-Object {

                    $JsonPath = Join-Path $_.FullName "tool.json"

                    if (Test-Path $JsonPath) {

                        try {

                            $Json = Get-Content `
                                $JsonPath `
                                -Raw | ConvertFrom-Json

                            $Changed = $false

                            if ($Json.risk -eq "Unknown") {

                                $Json.risk = Get-RiskSuggestion `
                                    -Name $_.Name `
                                    -RequiresAdmin $Json.requires_admin

                                $RiskFixed++
                                $Changed = $true
                            }

                            if ($Json.subcategory -eq "Migrated Modules") {

                                $Suggested = Get-SubcategorySuggestion `
                                    -Name $_.Name

                                if ($Suggested) {

                                    $Json.subcategory = $Suggested

                                    $SubFixed++
                                    $Changed = $true
                                }
                            }

                            if ($Changed) {

                                $Json |
                                    ConvertTo-Json -Depth 10 |
                                    Set-Content `
                                        $JsonPath `
                                        -Encoding UTF8

                                Write-Host "[UPDATED] $($_.Name)" `
                                    -ForegroundColor Green
                            }
                        }
                        catch {

                            Write-Host "[FAIL] $($_.Name)" `
                                -ForegroundColor Red
                        }
                    }
                }

                Write-Host ""
                Write-Host "Risk Fixes Applied       : $RiskFixed"
                Write-Host "Subcategory Fixes Applied: $SubFixed"
                Write-Host ""

                Pause-Toolkit
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