<#
DESCRIPTION:
    OCR Helper module for Studio Effects automation.
    Uses Windows.Media.Ocr.OcrEngine (built-in Windows OCR) to detect text in screenshots.
    Designed to work with Quick Settings / Studio Effects flyout panels that are NOT exposed
    in the UI Automation tree (see experiment findings 1 & 2).

DEPENDENCIES:
    - ScreenCapture.ps1 (Capture-ScreenRegion, Capture-RightScreenRegion)
    - Windows 10/11 with Windows.Media.Ocr runtime
#>

# Load WinRT OCR types (guard against duplicate Add-Type calls — experiment 6 fix)
# Also guard against environments where WinRT OCR is unavailable (e.g., PowerShell 7.6+)
if (-not ([System.Management.Automation.PSTypeName]'Windows.Media.Ocr.OcrEngine').Type) {
    try {
        Add-Type -AssemblyName 'System.Runtime.WindowsRuntime'

        $null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
        $null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType = WindowsRuntime]
        $null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Foundation, ContentType = WindowsRuntime]
        $null = [Windows.Storage.Streams.RandomAccessStream, Windows.Foundation, ContentType = WindowsRuntime]
        $null = [Windows.Globalization.Language, Windows.Foundation, ContentType = WindowsRuntime]
    } catch {
        Write-Warning "OCR WinRT types could not be loaded. Quick Settings OCR automation will not be available. Error: $_"
        $script:OcrAvailable = $false
        return
    }
}
$script:OcrAvailable = $true

# Helper to await WinRT async operations from PowerShell using AsTask pattern
function Await-WinRTAsync {
    param ([object]$AsyncOp, [type]$ResultType)
    try {
        $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
            Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.IsGenericMethod })[0]
        $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
        $task = $asTask.Invoke($null, @($AsyncOp))
        $task.Wait()
        return $task.Result
    } catch {
        # Fallback to awaiter pattern for older runtimes
        $awaiter = $AsyncOp.GetAwaiter()
        while (-not $awaiter.IsCompleted) { Start-Sleep -Milliseconds 50 }
        return $awaiter.GetResult()
    }
}


<#
DESCRIPTION:
    Converts a System.Drawing.Bitmap to a WinRT SoftwareBitmap for use with OcrEngine.
INPUT PARAMETERS:
    - Bitmap [System.Drawing.Bitmap] :- The GDI+ bitmap to convert.
RETURN TYPE:
    - [Windows.Graphics.Imaging.SoftwareBitmap]
#>
function ConvertTo-SoftwareBitmap {
    param ([System.Drawing.Bitmap]$Bitmap)

    # Save bitmap to a memory stream as PNG
    $memStream = New-Object System.IO.MemoryStream
    $Bitmap.Save($memStream, [System.Drawing.Imaging.ImageFormat]::Png)
    $memStream.Position = 0

    # Convert to WinRT IRandomAccessStream
    $winrtStream = [Windows.Storage.Streams.InMemoryRandomAccessStream]::new()
    $writer = [Windows.Storage.Streams.DataWriter]::new($winrtStream.GetOutputStreamAt(0))
    $bytes = $memStream.ToArray()
    $writer.WriteBytes($bytes)
    $null = Await-WinRTAsync -AsyncOp $writer.StoreAsync() -ResultType ([uint32])
    $null = Await-WinRTAsync -AsyncOp $writer.FlushAsync() -ResultType ([bool])
    $winrtStream.Seek(0)

    # Decode to SoftwareBitmap
    $decoder = Await-WinRTAsync -AsyncOp ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($winrtStream)) -ResultType ([Windows.Graphics.Imaging.BitmapDecoder])
    $softwareBitmap = Await-WinRTAsync -AsyncOp $decoder.GetSoftwareBitmapAsync() -ResultType ([Windows.Graphics.Imaging.SoftwareBitmap])

    $memStream.Dispose()
    return $softwareBitmap
}


<#
DESCRIPTION:
    Runs OCR on a System.Drawing.Bitmap and returns all detected text lines with their
    bounding rectangles. Each result contains: Text, X, Y, Width, Height (in pixels
    relative to the bitmap).
INPUT PARAMETERS:
    - Bitmap [System.Drawing.Bitmap] :- The screenshot bitmap to OCR.
    - Language [string] :- BCP-47 language tag (default: "en-US").
RETURN TYPE:
    - [array] :- Array of objects with properties: Text, X, Y, Width, Height
#>
function Invoke-OCR {
    param (
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Language = "en-US"
    )

    $softwareBitmap = ConvertTo-SoftwareBitmap -Bitmap $Bitmap

    # Create OCR engine
    $lang = [Windows.Globalization.Language]::new($Language)
    $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($lang)
    if (-not $ocrEngine) {
        Write-Error "OCR engine could not be created for language '$Language'. Ensure the language pack is installed."
        return @()
    }

    # Run OCR
    $ocrResult = Await-WinRTAsync -AsyncOp $ocrEngine.RecognizeAsync($softwareBitmap) -ResultType ([Windows.Media.Ocr.OcrResult])

    # Extract results with bounding boxes (type-safe — experiment 5 fix)
    $results = @()
    foreach ($line in $ocrResult.Lines) {
        $words = $line.Words
        if ($words.Count -eq 0) { continue }

        # Compute bounding rect for the entire line
        $minX = [double]::MaxValue
        $minY = [double]::MaxValue
        $maxX = 0.0
        $maxY = 0.0

        foreach ($word in $words) {
            $rect = $word.BoundingRect
            $wx = [double]$rect.X
            $wy = [double]$rect.Y
            $ww = [double]$rect.Width
            $wh = [double]$rect.Height

            if ($wx -lt $minX) { $minX = $wx }
            if ($wy -lt $minY) { $minY = $wy }
            if (($wx + $ww) -gt $maxX) { $maxX = $wx + $ww }
            if (($wy + $wh) -gt $maxY) { $maxY = $wy + $wh }
        }

        $results += [PSCustomObject]@{
            Text   = $line.Text
            X      = [int]$minX
            Y      = [int]$minY
            Width  = [int]($maxX - $minX)
            Height = [int]($maxY - $minY)
        }
    }

    return $results
}


<#
DESCRIPTION:
    Captures the right portion of the screen and runs OCR on it. Returns detected text
    with bounding coordinates adjusted to absolute screen coordinates.
    This is the primary function for detecting Studio Effects panel content.
INPUT PARAMETERS:
    - Fraction [double] :- Fraction of screen width to capture from right (default: 0.4).
    - Language [string] :- OCR language (default: "en-US").
RETURN TYPE:
    - [array] :- Array of objects with properties: Text, ScreenX, ScreenY, Width, Height
                 (coordinates are absolute screen positions for click targeting)
#>
function Get-RightScreenOCR {
    param (
        [double]$Fraction = 0.4,
        [string]$Language = "en-US"
    )

    $screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $captureWidth = [int]($screenWidth * $Fraction)
    $offsetX = $screenWidth - $captureWidth

    $bitmap = Capture-RightScreenRegion -Fraction $Fraction
    $ocrResults = Invoke-OCR -Bitmap $bitmap -Language $Language
    $bitmap.Dispose()

    # Adjust coordinates from bitmap-relative to absolute screen coordinates
    $adjusted = @()
    foreach ($r in $ocrResults) {
        $adjusted += [PSCustomObject]@{
            Text    = $r.Text
            ScreenX = $r.X + $offsetX
            ScreenY = $r.Y
            Width   = $r.Width
            Height  = $r.Height
        }
    }

    return $adjusted
}


<#
DESCRIPTION:
    Searches OCR results for a specific text string (case-insensitive partial match).
    Returns the first matching result with screen coordinates.
INPUT PARAMETERS:
    - OcrResults [array] :- Array of OCR result objects from Get-RightScreenOCR or Invoke-OCR.
    - SearchText [string] :- The text to search for (case-insensitive, partial match).
RETURN TYPE:
    - [object] :- The first matching OCR result, or $null if not found.
#>
function Find-OCRText {
    param (
        [array]$OcrResults,
        [string]$SearchText
    )

    $match = $OcrResults | Where-Object { $_.Text -like "*$SearchText*" } | Select-Object -First 1
    return $match
}


<#
DESCRIPTION:
    Clicks at a specific screen coordinate using mouse_event Win32 API.
    Uses absolute coordinates with SendInput for reliable click delivery to
    flyout panels not in the UI Automation tree.
INPUT PARAMETERS:
    - X [int] :- Absolute screen X coordinate.
    - Y [int] :- Absolute screen Y coordinate.
RETURN TYPE:
    - void
#>
function Click-AtPosition {
    param (
        [int]$X,
        [int]$Y
    )

    # Load user32.dll methods if not already loaded
    if (-not ([System.Management.Automation.PSTypeName]'NativeMethods_OCR').Type) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;

public class NativeMethods_OCR {
    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, int dwExtraInfo);

    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP   = 0x0004;

    public static void ClickAt(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
        System.Threading.Thread.Sleep(50);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
    }
}
"@
    }

    [NativeMethods_OCR]::ClickAt($X, $Y)
    Write-Log -Message "Clicked at screen position ($X, $Y)" -IsOutput
}


<#
DESCRIPTION:
    Finds a text label on screen via OCR and clicks on it or near it.
    Combines Get-RightScreenOCR, Find-OCRText, and Click-AtPosition.
INPUT PARAMETERS:
    - SearchText [string] :- The text to find on screen.
    - OffsetX [int] :- Horizontal pixel offset from the center of the found text (default: 0).
    - OffsetY [int] :- Vertical pixel offset from the center of the found text (default: 0).
    - Fraction [double] :- Screen capture fraction (default: 0.4).
RETURN TYPE:
    - [bool] :- $true if text was found and clicked, $false otherwise.
#>
function Find-AndClickOCR {
    param (
        [string]$SearchText,
        [int]$OffsetX = 0,
        [int]$OffsetY = 0,
        [double]$Fraction = 0.4
    )

    $ocrResults = Get-RightScreenOCR -Fraction $Fraction
    $match = Find-OCRText -OcrResults $ocrResults -SearchText $SearchText

    if (-not $match) {
        Write-Warning "OCR: Text '$SearchText' not found on screen."
        return $false
    }

    # Calculate click position (center of the detected text + offset)
    $clickX = $match.ScreenX + [int]($match.Width / 2) + $OffsetX
    $clickY = $match.ScreenY + [int]($match.Height / 2) + $OffsetY

    Write-Log -Message "OCR: Found '$SearchText' at ($($match.ScreenX), $($match.ScreenY)) size ($($match.Width)x$($match.Height)). Clicking at ($clickX, $clickY)" -IsOutput
    Click-AtPosition -X $clickX -Y $clickY

    return $true
}
