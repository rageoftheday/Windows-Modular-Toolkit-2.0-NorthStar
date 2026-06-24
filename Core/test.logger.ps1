# ============================================================
# FRAMEWORK TEST LOGGER - TEMPORARY TESTING SUPPORT
# ============================================================

function Get-ToolkitTestLogPath {
    $Root = Resolve-Path "$PSScriptRoot\.."
    $Logs = Join-Path $Root "Logs"
    if (!(Test-Path $Logs)) { New-Item -ItemType Directory -Path $Logs | Out-Null }
    return (Join-Path $Logs "framework_test.log")
}

function Write-ToolkitTestLog {
    param(
        [string]$Area,
        [string]$Action,
        [string]$Result = "INFO",
        [string]$Details = ""
    )
    try {
        $Path = Get-ToolkitTestLogPath
        $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $Line = "$Stamp | $Result | $Area | $Action | $Details"
        Add-Content -Path $Path -Value $Line -Encoding UTF8
    } catch {}
}

function Initialize-ToolkitTestLog {
    try {
        $Path = Get-ToolkitTestLogPath
        if (!(Test-Path $Path)) {
            "# Windows Modular Toolkit Framework 2.0 - Test Log" | Set-Content -Path $Path -Encoding UTF8
            "# Send this file back when testing fails: Logs\framework_test.log" | Add-Content -Path $Path -Encoding UTF8
        }
        Write-ToolkitTestLog -Area "Startup" -Action "Toolkit launched" -Result "INFO" -Details "Test logger initialized"
    } catch {}
}
