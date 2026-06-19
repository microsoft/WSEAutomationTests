<#
DESCRIPTION:
    Studio Effects Handler for Quick Settings panel.
    The Studio Effects flyout in Windows Quick Settings is NOT accessible via
    UI Automation (experiments 1 & 2 confirmed this). This module uses OCR-based
    detection and native mouse clicks to interact with the Studio Effects panel.

DEPENDENCIES:
    - OcrHelper.ps1 (Get-RightScreenOCR, Find-OCRText, Click-AtPosition, Find-AndClickOCR)
    - ScreenCapture.ps1 (Capture-RightScreenRegion)
    - Helper-library.ps1 (Write-Log)
#>

# Ensure native methods are loaded once at module scope
if (-not ([System.Management.Automation.PSTypeName]'QuickSettingsNative').Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class QuickSettingsNative {
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);

    public const byte VK_LWIN = 0x5B;
    public const byte VK_A = 0x41;
    public const uint KEYEVENTF_KEYUP = 0x0002;

    public static void OpenQuickSettings() {
        keybd_event(VK_LWIN, 0, 0, 0);
        keybd_event(VK_A, 0, 0, 0);
        System.Threading.Thread.Sleep(50);
        keybd_event(VK_A, 0, KEYEVENTF_KEYUP, 0);
        keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, 0);
    }

    public static void CloseQuickSettings() {
        keybd_event(0x1B, 0, 0, 0);           // VK_ESCAPE
        System.Threading.Thread.Sleep(50);
        keybd_event(0x1B, 0, KEYEVENTF_KEYUP, 0);
    }
}
"@
}


<#
DESCRIPTION:
    Opens the Windows Quick Settings panel using the Win+A keyboard shortcut.
    Waits for the panel to render before returning.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - void
#>
function Open-QuickSettings {
    Write-Log -Message "Opening Quick Settings (Win+A)..." -IsOutput | Out-Null
    [QuickSettingsNative]::OpenQuickSettings()
    Start-Sleep -Seconds 2
    Write-Log -Message "Quick Settings panel should be open." -IsOutput | Out-Null
}


<#
DESCRIPTION:
    Closes the Quick Settings panel by pressing Escape.
    Note: Closing Quick Settings also closes Studio Effects flyout (experiment 3 finding).
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - void
#>
function Close-QuickSettings {
    Write-Log -Message "Closing Quick Settings (Escape)..." -IsOutput | Out-Null
    [QuickSettingsNative]::CloseQuickSettings()
    Start-Sleep -Milliseconds 500
}


<#
DESCRIPTION:
    Opens the Studio Effects flyout from Quick Settings. First opens Quick Settings,
    then uses OCR to find and click the "Studio effects" button. Verifies the flyout
    opened by checking for expected effect labels like "Background effects".
INPUT PARAMETERS:
    - MaxRetries [int] :- Number of retry attempts to find Studio Effects button (default: 3).
RETURN TYPE:
    - [bool] :- $true if Studio Effects panel opened and verified, $false otherwise.
#>
function Open-StudioEffects {
    param (
        [int]$MaxRetries = 3
    )

    Open-QuickSettings

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Write-Log -Message "Looking for Studio Effects button (attempt $attempt/$MaxRetries)..." -IsOutput | Out-Null

        $ocrResults = Get-RightScreenOCR -Fraction 0.4
        $studioMatch = Find-OCRText -OcrResults $ocrResults -SearchText "Studio effects"
        if (-not $studioMatch) {
            $studioMatch = Find-OCRText -OcrResults $ocrResults -SearchText "Studio Effects"
        }

        if ($studioMatch) {
            Write-Log -Message "Found 'Studio Effects' at ($($studioMatch.ScreenX), $($studioMatch.ScreenY))" -IsOutput | Out-Null
            $clickX = $studioMatch.ScreenX + [int]($studioMatch.Width / 2)
            $clickY = $studioMatch.ScreenY + [int]($studioMatch.Height / 2)
            Click-AtPosition -X $clickX -Y $clickY
            Start-Sleep -Seconds 2

            # Verify the flyout actually opened by looking for known effect labels
            $verifyOcr = Get-RightScreenOCR -Fraction 0.4
            $verified = (Find-OCRText -OcrResults $verifyOcr -SearchText "Background effects") -or
                        (Find-OCRText -OcrResults $verifyOcr -SearchText "Automatic framing") -or
                        (Find-OCRText -OcrResults $verifyOcr -SearchText "Eye contact")
            if ($verified) {
                Write-Log -Message "Studio Effects flyout verified open." -IsOutput | Out-Null
                return $true
            }
            Write-Log -Message "Studio Effects flyout not verified, retrying..." -IsOutput | Out-Null
        } else {
            Write-Log -Message "Studio Effects button not found, retrying..." -IsOutput | Out-Null
        }
        Start-Sleep -Seconds 1
    }

    Write-Warning "Could not open Studio Effects panel in Quick Settings after $MaxRetries attempts."
    Close-QuickSettings
    return $false
}


<#
DESCRIPTION:
    Detects whether a Studio Effects toggle is currently On or Off by looking for
    nearby "On"/"Off" text in the OCR results near the effect label's Y position.
INPUT PARAMETERS:
    - OcrResults [array] :- OCR results from Get-RightScreenOCR.
    - EffectMatch [object] :- The OCR match object for the effect label.
RETURN TYPE:
    - [string] :- "On", "Off", or "Unknown" if state cannot be determined.
#>
function Get-ToggleState {
    param (
        [array]$OcrResults,
        [object]$EffectMatch
    )

    $labelY = $EffectMatch.ScreenY
    $tolerance = 40  # pixels vertical tolerance for same-row matching

    # Look for "On" or "Off" text on the same row (within Y tolerance) and to the right
    foreach ($r in $OcrResults) {
        if ([Math]::Abs($r.ScreenY - $labelY) -le $tolerance -and $r.ScreenX -gt $EffectMatch.ScreenX) {
            if ($r.Text -match '\bOn\b') { return "On" }
            if ($r.Text -match '\bOff\b') { return "Off" }
        }
    }

    # Fallback: check within a wider range below the label (some layouts stack vertically)
    foreach ($r in $OcrResults) {
        $vertDist = $r.ScreenY - $labelY
        if ($vertDist -ge 0 -and $vertDist -le 60 -and $r.ScreenX -gt ($EffectMatch.ScreenX + $EffectMatch.Width - 50)) {
            if ($r.Text -match '\bOn\b') { return "On" }
            if ($r.Text -match '\bOff\b') { return "Off" }
        }
    }

    return "Unknown"
}


<#
DESCRIPTION:
    Sets a Studio Effects toggle to a desired state. Uses OCR to detect current state
    and only clicks the toggle if the current state differs from the desired state.
    This makes the function idempotent — calling it multiple times produces the same result.

    The toggle control is located relative to the right edge of the captured region
    to be more resilient across resolutions and DPI settings.
INPUT PARAMETERS:
    - EffectName [string] :- The display name of the effect (e.g., "Background effects").
    - DesiredState [string] :- The desired state ("On" or "Off").
    - MaxRetries [int] :- Max retry attempts (default: 3).
RETURN TYPE:
    - [bool] :- $true if the effect was set to the desired state, $false if not found.
#>
function Set-StudioEffectState {
    param (
        [string]$EffectName,
        [string]$DesiredState = "On",
        [int]$MaxRetries = 3
    )

    $screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Write-Log -Message "Setting '$EffectName' to $DesiredState (attempt $attempt)..." -IsOutput | Out-Null

        $ocrResults = Get-RightScreenOCR -Fraction 0.4
        $match = Find-OCRText -OcrResults $ocrResults -SearchText $EffectName
        if (-not $match) {
            Write-Log -Message "'$EffectName' not found on screen, retrying..." -IsOutput | Out-Null
            Start-Sleep -Seconds 1
            continue
        }

        Write-Log -Message "Found '$EffectName' at ($($match.ScreenX), $($match.ScreenY))" -IsOutput | Out-Null

        # Check current state
        $currentState = Get-ToggleState -OcrResults $ocrResults -EffectMatch $match
        Write-Log -Message "'$EffectName' current state: $currentState, desired: $DesiredState" -IsOutput | Out-Null

        if ($currentState -eq $DesiredState) {
            Write-Log -Message "'$EffectName' is already $DesiredState, no click needed." -IsOutput | Out-Null
            return $true
        }

        # Click toggle: try multiple candidate X positions relative to the right edge.
        # The toggle switch is typically near the right edge of the flyout panel but
        # exact position varies by DPI, resolution, and Windows build.
        $clickY = $match.ScreenY + [int]($match.Height / 2)
        $toggleOffsets = @(60, 45, 80, 100)  # pixels from right edge to try

        $toggleSuccess = $false
        foreach ($offset in $toggleOffsets) {
            $clickX = $screenWidth - $offset
            Click-AtPosition -X $clickX -Y $clickY
            Start-Sleep -Milliseconds 800

            # Verify the toggle changed
            $verifyOcr = Get-RightScreenOCR -Fraction 0.4
            $verifyMatch = Find-OCRText -OcrResults $verifyOcr -SearchText $EffectName
            if ($verifyMatch) {
                $newState = Get-ToggleState -OcrResults $verifyOcr -EffectMatch $verifyMatch
                if ($newState -eq $DesiredState) {
                    Write-Log -Message "'$EffectName' successfully set to $DesiredState (offset=$offset)." -IsOutput | Out-Null
                    return $true
                }
                Write-Log -Message "'$EffectName' state after click at offset $offset`: $newState (expected $DesiredState)" -IsOutput | Out-Null
            }
        }
        Write-Log -Message "'$EffectName' toggle click did not achieve desired state, retrying full attempt..." -IsOutput | Out-Null
    }

    Write-Warning "Could not set '$EffectName' to $DesiredState after $MaxRetries attempts."
    return $false
}


<#
DESCRIPTION:
    Verifies the current state of all visible Studio Effects toggles by reading OCR.
    Returns a hashtable of effect names and their detected states.
    Useful for confirming effects are set correctly after toggling.
INPUT PARAMETERS:
    - EffectNames [string[]] :- Array of effect label names to check.
RETURN TYPE:
    - [hashtable] :- Keys are effect names, values are "On", "Off", or "Unknown".
#>
function Verify-StudioEffectsState {
    param (
        [string[]]$EffectNames = @("Automatic framing", "Background effects", "Eye contact", "Portrait light", "Creative filters")
    )

    $ocrResults = Get-RightScreenOCR -Fraction 0.4
    $states = @{}

    foreach ($name in $EffectNames) {
        $match = Find-OCRText -OcrResults $ocrResults -SearchText $name
        if ($match) {
            $state = Get-ToggleState -OcrResults $ocrResults -EffectMatch $match
            $states[$name] = $state
            Write-Log -Message "Verify: '$name' = $state" -IsOutput | Out-Null
        } else {
            $states[$name] = "NotFound"
            Write-Log -Message "Verify: '$name' not found on screen" -IsOutput | Out-Null
        }
    }

    return $states
}


<#
DESCRIPTION:
    Selects a radio-button style sub-option within Studio Effects panel by clicking on its label text.
    Used for options like "Standard blur" vs "Portrait blur", or "Standard" vs "Teleprompter"
    for Eye Contact.
INPUT PARAMETERS:
    - OptionName [string] :- The text of the sub-option to select (e.g., "Standard blur").
    - MaxRetries [int] :- Max retry attempts (default: 3).
RETURN TYPE:
    - [bool] :- $true if option found and clicked, $false otherwise.
#>
function Select-StudioEffectOption {
    param (
        [string]$OptionName,
        [int]$MaxRetries = 3
    )

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $result = Find-AndClickOCR -SearchText $OptionName -Fraction 0.4
        if ($result) {
            Write-Log -Message "Selected Studio Effects option: '$OptionName'" -IsOutput | Out-Null
            return $true
        }
        Start-Sleep -Seconds 1
    }

    Write-Warning "Could not find Studio Effects option '$OptionName'."
    return $false
}


<#
DESCRIPTION:
    Toggles all AI camera effects via the Quick Settings Studio Effects panel.
    This is the Quick Settings equivalent of ToggleAIEffectsInSettingsApp.
    Parameter order matches ToggleAIEffectsInSettingsApp for interchangeability.
    Opens Studio Effects, sets each effect to the desired state, then closes.
    Note: Voice Focus (VFVal) is not available in the Quick Settings Studio Effects panel;
    it is handled separately through the Settings app.
INPUT PARAMETERS:
    - AFVal [string] :- "On"/"Off" for Automatic Framing.
    - AFSVal [string] :- "On"/"Off" for Standard Framing (sub-option).
    - AFCVal [string] :- "On"/"Off" for Cinematic Framing (sub-option).
    - PLVal [string] :- "On"/"Off" for Portrait Light.
    - BBVal [string] :- "On"/"Off" for Background Effects.
    - BSVal [string] :- "On"/"Off" for Standard Blur (sub-option).
    - BPVal [string] :- "On"/"Off" for Portrait Blur (sub-option).
    - ECVal [string] :- "On"/"Off" for Eye Contact.
    - ECSVal [string] :- "On"/"Off" for Standard Eye Contact style.
    - ECTVal [string] :- "On"/"Off" for Teleprompter Eye Contact style.
    - VFVal [string] :- Voice Focus (ignored in Quick Settings, handled via Settings app).
    - CF [string] :- "On"/"Off" for Creative Filters.
    - CFI [string] :- "On"/"Off" for Illustrated filter.
    - CFA [string] :- "On"/"Off" for Animated filter.
    - CFW [string] :- "On"/"Off" for Watercolor filter.
RETURN TYPE:
    - [bool] :- $true if all requested effects were set successfully, $false if any failed.
#>
function ToggleAIEffectsInQuickSettings {
    param (
        [string]$AFVal  = "Off",
        [string]$AFSVal = "Off",
        [string]$AFCVal = "Off",
        [string]$PLVal  = "Off",
        [string]$BBVal  = "Off",
        [string]$BSVal  = "Off",
        [string]$BPVal  = "Off",
        [string]$ECVal  = "Off",
        [string]$ECSVal = "Off",
        [string]$ECTVal = "Off",
        [string]$VFVal  = "Off",
        [string]$CF     = "Off",
        [string]$CFI    = "Off",
        [string]$CFA    = "Off",
        [string]$CFW    = "Off"
    )

    Write-Log -Message "Entering ToggleAIEffectsInQuickSettings" -IsOutput | Out-Null
    $allSuccess = $true

    try {
        # Open Studio Effects panel
        $opened = Open-StudioEffects
        if (-not $opened) {
            Write-Error "Failed to open Studio Effects panel in Quick Settings."
            return $false
        }

        # Set main effects with state verification
        # Only treat as failure if the effect is visible but cannot be toggled.
        # Effects not found on screen are skipped (device may not support them).
        $afResult = Set-StudioEffectState -EffectName "Automatic framing" -DesiredState $AFVal
        if ($afResult -eq $false -and $AFVal -eq "On") { $allSuccess = $false }
        if ($AFVal -eq "On") {
            if ($AFSVal -eq "On" -and -not (Select-StudioEffectOption -OptionName "Standard framing")) { $allSuccess = $false }
            if ($AFCVal -eq "On" -and -not (Select-StudioEffectOption -OptionName "Cinematic framing")) { $allSuccess = $false }
        }

        $bbResult = Set-StudioEffectState -EffectName "Background effects" -DesiredState $BBVal
        if ($bbResult -eq $false -and $BBVal -eq "On") { $allSuccess = $false }
        if ($BBVal -eq "On") {
            if ($BSVal -eq "On" -and -not (Select-StudioEffectOption -OptionName "Standard blur")) { $allSuccess = $false }
            if ($BPVal -eq "On" -and -not (Select-StudioEffectOption -OptionName "Portrait blur")) { $allSuccess = $false }
        }

        $ecResult = Set-StudioEffectState -EffectName "Eye contact" -DesiredState $ECVal
        if ($ecResult -eq $false -and $ECVal -eq "On") { $allSuccess = $false }
        if ($ECVal -eq "On") {
            if ($ECSVal -eq "On" -and -not (Select-StudioEffectOption -OptionName "Standard")) { $allSuccess = $false }
            if ($ECTVal -eq "On" -and -not (Select-StudioEffectOption -OptionName "Teleprompter")) { $allSuccess = $false }
        }

        # Portrait light and Creative filters may not exist on all devices
        $plResult = Set-StudioEffectState -EffectName "Portrait light" -DesiredState $PLVal
        if ($plResult -eq $false -and $PLVal -eq "On") {
            Write-Log -Message "Portrait light not available on this device, skipping." -IsOutput | Out-Null
        }

        $cfResult = Set-StudioEffectState -EffectName "Creative filters" -DesiredState $CF
        if ($cfResult -eq $false -and $CF -eq "On") {
            Write-Log -Message "Creative filters not available on this device, skipping." -IsOutput | Out-Null
        }
        if ($CF -eq "On" -and $cfResult) {
            if ($CFI -eq "On" -and -not (Select-StudioEffectOption -OptionName "Illustrated")) { $allSuccess = $false }
            if ($CFA -eq "On" -and -not (Select-StudioEffectOption -OptionName "Animated")) { $allSuccess = $false }
            if ($CFW -eq "On" -and -not (Select-StudioEffectOption -OptionName "Watercolor")) { $allSuccess = $false }
        }

        # VFVal is intentionally not handled here — Voice Focus is not in the Quick Settings
        # Studio Effects panel. It must be toggled separately via VoiceFocusToggleSwitch.
        if ($VFVal -ne "Off") {
            Write-Log -Message "Note: Voice Focus ($VFVal) is not available in Quick Settings. Use VoiceFocusToggleSwitch separately." -IsOutput | Out-Null
        }

    } finally {
        # Always close Quick Settings to prevent UI state pollution
        Close-QuickSettings
    }

    if ($allSuccess) {
        Write-Log -Message "All AI effects set successfully in Quick Settings." -IsOutput | Out-Null
    } else {
        Write-Warning "Some effects could not be set in Quick Settings. Check logs for details."
    }

    return $allSuccess
}
