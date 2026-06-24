$ErrorActionPreference = "Continue"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Show-CenterHeader {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "============================================================"
    Write-Host (" " + $Title)
    Write-Host "============================================================"
    Write-Host ""
}

function Invoke-FrameworkTool {
    param([string]$Folder)
    $ToolPath = Join-Path $Root "Framework\$Folder"
    $PS1 = Join-Path $ToolPath "run.ps1"
    $BAT = Join-Path $ToolPath "run.bat"
    if (Test-Path $PS1) {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PS1
        return
    }
    if (Test-Path $BAT) {
        cmd /c "`"$BAT`""
        return
    }
    Write-Host "[FAIL] Framework tool not found: $Folder" -ForegroundColor Red
    Read-Host "Press Enter to continue"
}

function Read-Choice {
    param([string]$Prompt = "Selection")
    return (Read-Host $Prompt).Trim()
}

function Get-RegistryData {
    $Path = Join-Path $Root "Cache\toolkit_registry.json"
    if (!(Test-Path $Path)) { return @() }
    try {
        $Data = Get-Content $Path -Raw | ConvertFrom-Json
        if ($null -eq $Data) { return @() }
        return @($Data)
    } catch { return @() }
}
function Get-Prop { param($Obj,[string]$Name,$Default=$null)
    if ($Obj.PSObject.Properties.Name -contains $Name) { return $Obj.$Name }
    return $Default
}
function Show-Dashboard {
    Show-CenterHeader "DASHBOARD & HEALTH CENTER"
    $Reg = @(Get-RegistryData)
    $Framework = @($Reg | Where-Object { (Get-Prop $_ 'module_scope' '') -eq 'Framework' -or (Get-Prop $_ 'framework_protected' $false) -eq $true })
    $Users = @($Reg | Where-Object { (Get-Prop $_ 'module_scope' '') -ne 'Framework' -and (Get-Prop $_ 'framework_protected' $false) -ne $true })
    $VisibleUsers = @($Users | Where-Object { (Get-Prop $_ 'hidden' $false) -ne $true })
    $Cats = @($VisibleUsers | ForEach-Object { Get-Prop $_ 'category' '' } | Where-Object { $_ } | Sort-Object -Unique)
    Write-Host "Toolkit Snapshot"
    Write-Host "------------------------------------------------------------"
    Write-Host "Framework Components : $($Framework.Count)"
    Write-Host "User Modules         : $($Users.Count)"
    Write-Host "User Categories      : $($Cats.Count)"
    Write-Host "Total Registry Items : $($Reg.Count)"
    Write-Host "Admin User Modules   : $(@($Users | Where-Object { (Get-Prop $_ 'requires_admin' $false) -eq $true }).Count)"
    Write-Host "Hidden User Modules  : $(@($Users | Where-Object { (Get-Prop $_ 'hidden' $false) -eq $true }).Count)"
    Write-Host ""
    Write-Host "System Snapshot"
    Write-Host "------------------------------------------------------------"
    try {
        $OS = Get-CimInstance Win32_OperatingSystem
        $CPU = Get-CimInstance Win32_Processor | Select-Object -First 1
        Write-Host "Computer       : $env:COMPUTERNAME"
        Write-Host "User           : $env:USERNAME"
        Write-Host "OS             : $($OS.Caption) $($OS.Version)"
        Write-Host "Last Boot      : $($OS.LastBootUpTime)"
        Write-Host "CPU            : $($CPU.Name)"
        Write-Host "RAM            : $([math]::Round($OS.TotalVisibleMemorySize/1MB,2)) GB"
    } catch { Write-Host "System snapshot unavailable." }
    Write-Host ""
    Write-Host "Disk Snapshot"
    Write-Host "------------------------------------------------------------"
    try {
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID,VolumeName,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},@{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,2)}},@{n='FreePercent';e={if($_.Size){[math]::Round(($_.FreeSpace/$_.Size)*100,1)}else{0}}} | Format-Table -AutoSize
    } catch { Write-Host "Disk snapshot unavailable." }
    Write-Host ""
    Write-Host "Smart Recommendations Summary"
    Write-Host "------------------------------------------------------------"
    try {
        $Low = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Where-Object { $_.Size -and (($_.FreeSpace/$_.Size)*100) -lt 10 })
        if ($Low.Count -gt 0) {
            $i=1
            foreach($d in $Low){
                $pct=[math]::Round(($d.FreeSpace/$d.Size)*100,1)
                Write-Host "[$i] Low disk space on $($d.DeviceID)"
                Write-Host "    Reason: Only $pct% free space remains."
                Write-Host "    Tools : Disk Usage, Large Files, Quick Cleanup"
                $i++
            }
        } else { Write-Host "No urgent smart recommendations detected." }
    } catch { Write-Host "Recommendations unavailable." }
}
while ($true) {
    Show-Dashboard
    Write-Host ""
    Write-Host "[1] Open Health Center"
    Write-Host "[2] Open Smart Recommendations"
    Write-Host "[3] Open Validation Center"
    Write-Host "[R] Refresh"
    Write-Host "[B] Back"
    Write-Host ""
    $Choice = Read-Choice
    switch ($Choice.ToUpper()) {
        "1" { Invoke-FrameworkTool "Toolkit_Health_Center" }
        "2" { Invoke-FrameworkTool "Smart_Recommendations_Engine" }
        "3" { Invoke-FrameworkTool "Validation_Center" }
        "R" { continue }
        "B" { return }
    }
}
