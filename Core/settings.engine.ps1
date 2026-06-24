# ============================================================
# TOOLKIT SETTINGS ENGINE
# ============================================================

function Get-ToolkitSettings {

    $Root = Resolve-Path "$PSScriptRoot\.."
    $SettingsPath = Join-Path $Root "config\toolkit.settings.json"

    if (!(Test-Path $SettingsPath)) {
        throw "Toolkit settings file not found."
    }

    return Get-Content $SettingsPath -Raw | ConvertFrom-Json
}

function Get-ToolkitSetting {

    param(
        [string]$Section,
        [string]$Name
    )

    $Settings = Get-ToolkitSettings

    if ($Settings.$Section.$Name -ne $null) {
        return $Settings.$Section.$Name
    }

    return $null
}

function Test-ToolkitDebugMode {

    $Settings = Get-ToolkitSettings

    return [bool]$Settings.runtime.debug_mode
}

function Test-ToolkitSafeMode {

    $Settings = Get-ToolkitSettings

    return [bool]$Settings.runtime.safe_mode
}