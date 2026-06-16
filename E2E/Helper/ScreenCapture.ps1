Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Ensure DPI awareness is set for accurate screen coordinates
if (-not ([System.Management.Automation.PSTypeName]'ScreenCaptureDPI').Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class ScreenCaptureDPI {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
"@
    [ScreenCaptureDPI]::SetProcessDPIAware() | Out-Null
}

<#
DESCRIPTION:
    Captures a screenshot of a specific screen region and returns it as a System.Drawing.Bitmap.
    If no region is specified, captures the full virtual screen.
INPUT PARAMETERS:
    - X [int] :- Left coordinate of capture region (default: 0).
    - Y [int] :- Top coordinate of capture region (default: 0).
    - Width [int] :- Width of capture region (default: full screen width).
    - Height [int] :- Height of capture region (default: full screen height).
RETURN TYPE:
    - [System.Drawing.Bitmap] :- The captured screenshot bitmap.
#>
function Capture-ScreenRegion {
    param (
        [int]$X = [System.Windows.Forms.SystemInformation]::VirtualScreen.X,
        [int]$Y = [System.Windows.Forms.SystemInformation]::VirtualScreen.Y,
        [int]$Width  = [System.Windows.Forms.SystemInformation]::VirtualScreen.Width,
        [int]$Height = [System.Windows.Forms.SystemInformation]::VirtualScreen.Height
    )

    $bitmap   = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($X, $Y, 0, 0, [System.Drawing.Size]::new($Width, $Height))
    $graphics.Dispose()

    return $bitmap
}


<#
DESCRIPTION:
    Captures the right portion of the primary screen. Useful for targeting the Studio Effects /
    Quick Settings flyout panels which appear on the right side of the screen.
    Experiment 4 showed that capturing right ~40% avoids console noise and improves OCR accuracy.
INPUT PARAMETERS:
    - Fraction [double] :- Fraction of screen width to capture from the right (default: 0.4 = right 40%).
RETURN TYPE:
    - [System.Drawing.Bitmap] :- The captured screenshot bitmap of the right region.
#>
function Capture-RightScreenRegion {
    param (
        [double]$Fraction = 0.4
    )

    $screenWidth  = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
    $captureWidth = [int]($screenWidth * $Fraction)
    $captureX     = $screenWidth - $captureWidth

    return Capture-ScreenRegion -X $captureX -Y 0 -Width $captureWidth -Height $screenHeight
}


<#
DESCRIPTION:
    Saves a screenshot region to a PNG file in the scenario logs folder.
INPUT PARAMETERS:
    - FileName [string] :- File name (without extension).
    - ScnrName [string] :- Scenario name for the log folder.
    - X [int] :- Left coordinate (optional, defaults to full screen).
    - Y [int] :- Top coordinate (optional, defaults to full screen).
    - Width [int] :- Capture width (optional, defaults to full screen).
    - Height [int] :- Capture height (optional, defaults to full screen).
RETURN TYPE:
    - [string] :- The full file path of the saved screenshot.
#>
function Take-RegionScreenshot {
    param (
        [string]$FileName,
        [string]$ScnrName,
        [int]$X = [System.Windows.Forms.SystemInformation]::VirtualScreen.X,
        [int]$Y = [System.Windows.Forms.SystemInformation]::VirtualScreen.Y,
        [int]$Width  = [System.Windows.Forms.SystemInformation]::VirtualScreen.Width,
        [int]$Height = [System.Windows.Forms.SystemInformation]::VirtualScreen.Height
    )

    $scenarioName = "$ScnrName\Screenshots"
    CreateScenarioLogsFolder $scenarioName
    $screenshotDir  = "$pathLogsFolder\$scenarioName"
    $screenshotPath = Resolve-Path $screenshotDir
    $filePath       = Join-Path -Path $screenshotPath -ChildPath "$FileName.png"

    $bitmap = Capture-ScreenRegion -X $X -Y $Y -Width $Width -Height $Height
    $bitmap.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()

    Write-Log -Message "Region screenshot saved to $filePath" -IsOutput
    return $filePath
}
