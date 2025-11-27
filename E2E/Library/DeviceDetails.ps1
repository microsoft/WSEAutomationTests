<#
DESCRIPTION:
    This function gathers device-specific details related to camera scenarios, video/photo resolutions,
    power states, voice focus, and AI effects. It dynamically checks supported configurations
    and returns them in a structured format.

INPUT PARAMETERS:
    - None

RETURN TYPE:
    - Hashtable: Contains supported configurations for camera scenarios, resolutions, power states,
      voice focus, and AI effects.
#>
function GetDeviceDetails()
{
   # Initialize an ArrayList for efficient result accumulation
   $results = New-Object System.Collections.ArrayList

   $deviceData = @{}

   $deviceData.CameraScenario   = @("Recording" , "Previewing") #We run for Recording only if there are many scenarios to be covered
   $deviceData.VideoResolutions = GetVideoResList
   $deviceData.PhotoResolutions = GetPhotoResList
   $deviceData.PowerStates      = @("Pluggedin", "Unplugged")
   $voiceFocusExists = CheckVoiceFocusPolicy 
   if($voiceFocusExists -eq $false)
   {
      $deviceData.VoiceFocus    = @("NA")
   }
   else
   {
      $deviceData.VoiceFocus    = @("On", "Off")
   }
   $testScenarios = Generate-Combinations
   $deviceData.ToggleAiEffect = $testScenarios
   
   return $deviceData
}
<#
DESCRIPTION:
    Generates all valid combinations of camera features based on WSEV2 policy state
    Each combination is a '+'-joined string of selected features.

INPUT:
    - None

RETURN TYPE:
    - [string[]] : An array of non-empty feature combinations.

NOTES:
    - Feature options change depending on whether the WSEV2 policy is enabled.
    - Skips empty combinations (i.e., when no features are selected).
#>
function Generate-Combinations {
    $wsev2PolicyState = CheckWSEV2Policy

    # Use conditional assignments based on the policy state
    $AFOptions   = @("", "AF")
    $PLOptions   = if ($wsev2PolicyState) { @("", "PL") } else { @("") }
    $ECOptions   = if ($wsev2PolicyState) { @("", "ECT", "ECS") } else { @("", "ECS") }
    $BlurOptions = @("", "BBP", "BBS")
    $CFOptions   = if ($wsev2PolicyState) { @("", "CF-I", "CF-A", "CF-W") } else { @("") }

    $combinations = @()

    foreach ($af in $AFOptions) {
        foreach ($pl in $PLOptions) {
            foreach ($ec in $ECOptions) {
                foreach ($blur in $BlurOptions) {
                    foreach ($cf in $CFOptions) {
                        $selected = @($af, $pl, $ec, $blur, $cf) | Where-Object { $_ -ne "" }
                        if ($selected.Count -eq 0) { continue }
                        $comboString = $selected -join "+"
                        $combinations += $comboString
                    }
                }
            }
        }
    }
    return $combinations
}
<#
DESCRIPTION:
    This function retrieves the list of supported video resolutions from the Camera app settings.
    It opens the Camera app, switches to video mode, and checks the available video quality options.

RETURN TYPE:
    - Array: List of supported video resolutions.
#>
Function GetVideoResList()
{
     #Open Camera App
     $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
     Start-Sleep -s 1

     #Switch to video mode if not in video mode(Note until we switch to video mode the changes made in video resolution does not persist)
     $return = CheckIfElementExists $ui ToggleButton "Take video" 
     if ($return -eq $null){
        FindAndClick $ui Button "Switch to video mode" 
     }
     #Get video quality 
     FindAndClick $ui Button "Open Settings Menu"    
     #Find video settings and click
     FindAndClickList -uiEle $ui -clsNme Microsoft.UI.Xaml.Controls.Expander -proptyNmeLst @('Videos settings','Video settings')     
     FindAndClick $ui ComboBox "Video quality"
     $vdoRes = FindAllElementsNameWithClassName $ui ComboBoxItem
	 $vdoResList = $vdoRes | Where-Object { $_ -match 'aspect' }
     Stop-Process -Name 'WindowsCamera'
     start-sleep -s 1
     return $vdoResList
}

<#
DESCRIPTION:
    This function retrieves the list of supported photo resolutions from the Camera app settings.
    It opens the Camera app and checks the available photo quality options.

RETURN TYPE:
    - Array: List of supported photo resolutions.
#>
Function GetPhotoResList()
{
   #Open Camera App
   $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
   Start-Sleep -s 1

   #Get photo quality
   FindAndClick $ui Button "Open Settings Menu" 
   #Find Photo settings and click
   FindAndClickList -uiEle $ui -clsNme Microsoft.UI.Xaml.Controls.Expander -proptyNmeLst @('Photos settings','Photo settings')
   FindAndClick $ui ComboBox "Photo quality"
   Start-Sleep -s 1
   $ptoRes = FindAllElementsNameWithClassName $ui ComboBoxItem
   $ptoResList = $ptoRes | Where-Object { $_ -match 'aspect' }
   Stop-Process -Name 'WindowsCamera'
   start-sleep -s 1
   return $ptoResList
}

<#
DESCRIPTION:
    Filters and selects resolutions based on user input or strategic defaults.
    Automatically selects highest, middle, and lowest resolutions when no specific resolutions are provided.

INPUT PARAMETERS:
    - requestedResolutions: Array of resolution strings requested by user
    - availableResolutions: Array of all available resolutions on the device
    - resolutionType: String indicating "video" or "photo" for logging purposes

RETURN TYPE:
    - Array: Filtered array of resolution strings to be used for testing
#>
function Filter-Resolutions {
    param(
        [string[]]$requestedResolutions,
        [string[]]$availableResolutions,
        [string]$resolutionType
    )

    if (-not $requestedResolutions) { $requestedResolutions = @() }
    if (-not $availableResolutions) { $availableResolutions = @() }

    # Robust scoring:
    # 1) megapixels (photo)
    # 2) real WxH resolution (only if text says "resolution")
    # 3) 1080p / 1440p / 720p style for video
    function Get-ResolutionScore {
        param([string]$s)
        if (-not $s) { return 0.0 }
        $t = $s.ToString()

        # 1) megapixels: "12.2 megapixels", "2.1MP"
        $m = [regex]::Match($t, '(\d+(?:\.\d+)?)\s*(?:MP\b|MPs\b|megapixel\b|megapixels\b)', 'IgnoreCase')
        if ($m.Success) {
            return [double]$m.Groups[1].Value * 1e6
        }

        # 2) real pixel resolution only when followed by "resolution"
        #    e.g. "4032 by 3024 resolution", "3840 by 2160 resolution"
        $r = [regex]::Match($t, '(\d+)\s*by\s*(\d+)\s*resolution', 'IgnoreCase')
        if (-not $r.Success) {
            $r = [regex]::Match($t, '(\d+)\s*[x×]\s*(\d+)\s*resolution', 'IgnoreCase')
        }
        if ($r.Success) {
            return [double]$r.Groups[1].Value * [double]$r.Groups[2].Value
        }

        # 3) height-based p-style for video: "1440p", "1080p", "720p", "360p"
        $p = [regex]::Match($t, '(^|\D)(\d{3,4})p(\D|$)', 'IgnoreCase')
        if ($p.Success) {
            return [double]$p.Groups[2].Value * 1000.0
        }

        return 0.0
    }

    function Build-SortedList {
        param([string[]]$list)
        $objs = @()
        foreach ($item in $list) {
            $score = 0.0
            try { $score = Get-ResolutionScore $item } catch { $score = 0.0 }
            $objs += [PSCustomObject]@{ Text = $item; Score = $score }
        }
        # Sort by Score desc, then Text asc (stable)
        return $objs | Sort-Object -Property @{Expression='Score';Descending=$true}, @{Expression='Text';Descending=$false}
    }

    Write-Host "`n=== $($resolutionType.ToUpper()) RESOLUTION SELECTION ===" -ForegroundColor Cyan

    $filtered = New-Object System.Collections.Generic.List[String]

    # NO user requested resolutions: use your rules
    if ($requestedResolutions.Count -eq 0) {
        if ($availableResolutions.Count -eq 0) {
            Write-Host "No available $resolutionType resolutions found." -ForegroundColor Red
            Write-Host "==============================`n" -ForegroundColor Cyan
            return @()
        }

        $sortedObjs = Build-SortedList -list $availableResolutions
        $sorted     = $sortedObjs | ForEach-Object { $_.Text }

        if ($resolutionType -eq "video") {
            # 1) Highest resolution (by score)
            if ($sortedObjs.Count -gt 0) {
                $filtered.Add($sortedObjs[0].Text)
            }

            # 2) 720p and 360p if present
            $res720 = $sorted | Where-Object {
                [regex]::IsMatch($_, '(^|\D)720p(\D|$)', 'IgnoreCase') -or
                [regex]::IsMatch($_, '1280\s*[x×]\s*720', 'IgnoreCase')
            } | Select-Object -First 1

            $res360 = $sorted | Where-Object {
                [regex]::IsMatch($_, '(^|\D)360p(\D|$)', 'IgnoreCase') -or
                [regex]::IsMatch($_, '640\s*[x×]\s*360', 'IgnoreCase')
            } | Select-Object -First 1

            if ($res720 -and ($filtered -notcontains $res720)) {
                $filtered.Add($res720)
            }
            if ($res360 -and ($filtered -notcontains $res360)) {
                $filtered.Add($res360)
            }

            # 3) If neither 720p nor 360p, add lowest
            if (-not $res720 -and -not $res360) {
                $lowest = $sortedObjs[-1].Text
                if ($lowest -and ($filtered -notcontains $lowest)) {
                    $filtered.Add($lowest)
                }
            }
        }
        elseif ($resolutionType -eq "photo") {
            # Prefer 2.1MP if available (any "2.1" in megapixel string)
            $res21 = $availableResolutions |
                     Where-Object { $_ -match '2\.1' -and $_ -match 'megapixel|MP' } |
                     Select-Object -First 1

            if ($res21) {
                $filtered.Add($res21)
            } else {
                # Otherwise highest by score
                if ($sortedObjs.Count -gt 0) {
                    $filtered.Add($sortedObjs[0].Text)
                }
            }
        }

        # Print defaults
        if ($filtered.Count -eq 0) {
            Write-Host "Selected $resolutionType Resolutions (0): none" -ForegroundColor Yellow
        } else {
            Write-Host "Selected $resolutionType Resolutions ($($filtered.Count)):" -ForegroundColor Yellow
            foreach ($r in $filtered) {
                Write-Host "  • $r" -ForegroundColor Green
            }
        }
        Write-Host "==============================`n" -ForegroundColor Cyan
        return $filtered.ToArray()
    }

    # User passed requested resolutions: keep your existing behavior
    foreach ($requestedRes in $requestedResolutions) {
        $full = $null
        try { $full = RetrieveValue($requestedRes) } catch {}
        $search = if ($full) { $full } else { $requestedRes }

        if ($availableResolutions -contains $search) {
            if ($filtered -notcontains $search) {
                $filtered.Add($search)
            }
        } else {
            $match = $availableResolutions |
                     Where-Object { $_ -like "*$requestedRes*" } |
                     Select-Object -First 1
            if ($match -and $filtered -notcontains $match) {
                $filtered.Add($match)
            }
        }
    }

    if ($filtered.Count -eq 0) {
        Write-Host "Selected $resolutionType Resolutions (0): none" -ForegroundColor Yellow
    } else {
        Write-Host "Selected $resolutionType Resolutions ($($filtered.Count)):" -ForegroundColor Yellow
        foreach ($r in $filtered) {
            Write-Host "  • $r" -ForegroundColor Green
        }
    }
    Write-Host "==============================`n" -ForegroundColor Cyan

    return $filtered.ToArray()
}