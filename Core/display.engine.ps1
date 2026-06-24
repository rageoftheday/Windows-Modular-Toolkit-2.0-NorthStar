# ============================================================
# TOOLKIT DISPLAY ENGINE
# ============================================================
# Dynamic console auto-fit was retired before release because it caused
# cursor/input placement issues in Windows Terminal and some PowerShell hosts.
# This compatibility function intentionally does nothing so older scripts that
# call it do not fail.
function Resize-ToolkitWindowAuto {
    param(
        [string]$SourcePath = $PSCommandPath,
        [string[]]$MenuLines = $null,
        [int]$MinWidth = 100,
        [int]$MinHeight = 30,
        [int]$MaxWidth = 180,
        [int]$MaxHeight = 50,
        [int]$WidthPadding = 8,
        [int]$HeightPadding = 6
    )
    return
}

function Show-ToolkitPause {
    param([string]$Message = "Press Enter to continue")
    Read-Host $Message | Out-Null
}
