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
    $WSE8480Policy = Check8480Policy

    # Use conditional assignments based on the policy state
    $AFOptions   = if ($WSE8480Policy) { @("", "AFS", "AFC") } else { @("", "AFS") }
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
    
    if ($requestedResolutions.Count -eq 0) {
        # Apply custom strategic defaults based on resolution type
        $filtered = [System.Collections.Generic.List[string]]::new()
        
        if ($availableResolutions.Count -gt 0) {
            if ($resolutionType -eq "video") {
                # Video: Max, Min, and 720p (if available)
                $filtered.Add($availableResolutions[0])        # Max (first)
                
                # Add Min (last) if different from Max
                if ($availableResolutions.Count -gt 1) {
                    $minRes = $availableResolutions[-1]
                    if ($filtered -notcontains $minRes) {
                        $filtered.Add($minRes)
                    }
                }
                
                # Add 720p if available and not already included
                $resolution720p = $availableResolutions | Where-Object { $_ -like "*720p*" } | Select-Object -First 1
                if ($resolution720p -and $filtered -notcontains $resolution720p) {
                    $filtered.Add($resolution720p)
                }
                
            } elseif ($resolutionType -eq "photo") {
                # Photo: Highest resolution only
                $filtered.Add($availableResolutions[0])
                
            } else {
                # Default behavior: highest, middle, lowest
                $filtered.Add($availableResolutions[0])
                
                # Add middle resolution if available
                if ($availableResolutions.Count -gt 2) {
                    $middleIndex = [Math]::Floor($availableResolutions.Count / 2)
                    if ($filtered -notcontains $availableResolutions[$middleIndex]) {
                        $filtered.Add($availableResolutions[$middleIndex])
                    }
                }
                
                # Add lowest resolution if different from highest
                if ($availableResolutions.Count -gt 1) {
                    $lowestRes = $availableResolutions[-1]  # Last element
                    if ($filtered -notcontains $lowestRes) {
                        $filtered.Add($lowestRes)
                    }
                }
            }
        }
        
        Write-Log -Message "No $resolutionType resolutions specified. Using strategic defaults: $($filtered -join ', ')" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
        
        if ($filtered.Count -eq 0) {
            $filtered.Add($availableResolutions[0])
        }
    }
    # Check for wildcard (all resolutions)
    elseif ($requestedResolutions -contains "All" -or $requestedResolutions -contains "*") {
        Write-Log -Message "Using ALL available $resolutionType resolutions as requested" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
        $filtered = [System.Collections.Generic.List[string]]::new()
        $filtered.AddRange($availableResolutions)
    }
    # Process requested resolutions
    else {
        $filtered = [System.Collections.Generic.List[string]]::new()
        $invalid = [System.Collections.Generic.List[string]]::new()
        
        foreach ($requestedRes in $requestedResolutions) {
            $found = $false
            
            # Try direct lookup first (RetrieveValue)
            $fullResString = RetrieveValue($requestedRes)
            $searchTarget = if ($fullResString) { $fullResString } else { $requestedRes }
            
            # Check exact match
            if ($availableResolutions -contains $searchTarget) {
                if ($filtered -notcontains $searchTarget) {
                    $filtered.Add($searchTarget)
                    Write-Log -Message "$resolutionType resolution '$requestedRes' found and selected" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
                }
                $found = $true
            } else {
            # Try partial matching
            $partialMatch = $availableResolutions | Where-Object { $_ -like "*$requestedRes*" } | Select-Object -First 1
            if ($partialMatch) {
                if ($filtered -notcontains $partialMatch) {
                    $filtered.Add($partialMatch)
                    Write-Log -Message "$resolutionType resolution '$requestedRes' matched to '$partialMatch'" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
                }
                $found = $true
            }
        }
        
        if (-not $found) {
            $invalid.Add($requestedRes)
        }
    }
    
    # Handle invalid resolutions
    if ($invalid.Count -gt 0) {
        Write-Warning "The following $resolutionType resolutions are not available on this device:"
        $invalid | ForEach-Object { Write-Warning "  ✗ '$_'" }
        
        Write-Host "`nAvailable $resolutionType resolutions on this device:" -ForegroundColor Cyan
        foreach ($availableRes in $availableResolutions) {
            $shortKey = RetrieveValue($availableRes)
            $displayText = if ($shortKey) { "$shortKey -> $availableRes" } else { $availableRes }
            Write-Host "  • $displayText" -ForegroundColor Green
        }
        }
        
        # Validate we have at least one valid resolution
        if ($filtered.Count -eq 0) {
            Write-Error "CRITICAL: None of the requested $resolutionType resolutions are available on this device."
            Write-Host "Please use one of the available $resolutionType resolutions listed above, or use -${resolutionType}Resolutions @('All') to test all available resolutions." -ForegroundColor Red
            Write-Host "Example: .\ReleaseTest.ps1 -videoResolutions @('1080p', '720p') -photoResolutions @('12.2MP')" -ForegroundColor Yellow
            exit 1
        }
    }
    
    # Log and display selected resolutions (common for all paths)
    $selectedResolutionsText = $filtered.ToArray() -join ', '
    Write-Log -Message "Selected $resolutionType Resolutions: $selectedResolutionsText" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
    
    # Display selected resolutions to console
    Write-Host "`n=== $($resolutionType.ToUpper()) RESOLUTION SELECTION ===" -ForegroundColor Cyan
    Write-Host "Selected $resolutionType Resolutions ($($filtered.Count)):" -ForegroundColor Yellow
    foreach ($res in $filtered) {
        $resDetails = RetrieveValue($res)
        $displayText = if ($resDetails) { "$resDetails -> $res" } else { $res }
        Write-Host "  • $displayText" -ForegroundColor Green
    }
    Write-Host "==============================`n" -ForegroundColor Cyan
    
    return $filtered.ToArray()
}