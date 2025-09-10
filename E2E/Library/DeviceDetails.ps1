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
   $wsev2PolicyState = CheckWSEV2Policy
   if($wsev2PolicyState -eq $false)	  
   {
      $deviceData.ToggleAiEffect   = @("AF","EC","BBS", "BBP","AF+EC", "AF+BBS", "AF+BBP","BBS+EC","BBP+EC","AF+BBS+EC","AF+BBP+EC")
   }
   else
   {
      $deviceData.ToggleAiEffect   = @('AF', 'PL', 'BBS', 'BBP', 'EC', 'ECE', 'AF+PL', 'AF+BBS', 'AF+BBP', 'AF+EC', 'AF+ECE', `
                     'PL+BBS', 'PL+BBP', 'PL+EC', 'PL+ECE', 'BBS+EC', 'BBS+ECE', 'BBP+EC', 'BBP+ECE', 'AF+PL+BBS', `
                     'AF+PL+BBP','AF+PL+EC', 'AF+PL+ECE', 'AF+BBS+EC', 'AF+BBS+ECE', 'AF+BBP+EC', 'AF+BBP+ECE', `
                     'Pl+BBS+EC', 'Pl+BBP+EC', 'Pl+BBS+ECE', 'Pl+BBP+ECE', 'AF+Pl+BBS+EC', 'AF+Pl+BBS+ECE', `
                     'AF+Pl+BBP+EC', 'AF+Pl+BBP+ECE','CF-I', 'AF+CF-I', 'AF+CF-I+PL', 'AF+CF-I+EC', `
                     'AF+CF-I+ECE', 'AF+CF-I+BBS', 'AF+CF-I+BBP', 'AF+CF-I+PL+EC', 'AF+CF-I+PL+ECE', `
                     'AF+CF-I+PL+BBS', 'AF+CF-I+PL+BBP', 'AF+CF-I+EC+BBS', 'AF+CF-I+EC+BBP', 'AF+CF-I+ECE+BBS', `
                     'AF+CF-I+ECE+BBP', 'AF+CF-I+PL+EC+BBS', 'AF+CF-I+PL+EC+BBP', 'AF+CF-I+PL+ECE+BBS', `
                     'AF+CF-I+PL+ECE+BBP', 'PL+CF-I', 'PL+CF-I+EC', 'PL+CF-I+ECE', 'PL+CF-I+BBS', `
                     'PL+CF-I+BBP', 'PL+CF-I+EC+BBS', 'PL+CF-I+EC+BBP', 'PL+CF-I+ECE+BBS', 'PL+CF-I+ECE+BBP', `
                     'EC+CF-I', 'ECE+CF-I', 'EC+CF-I+BBS', 'EC+CF-I+BBP', 'ECE+CF-I+BBS', 'ECE+CF-I+BBP', `
                     'BBS+CF-I', 'BBP+CF-I','CF-A', 'AF+CF-A', 'AF+CF-A+PL', 'AF+CF-A+EC', 'AF+CF-A+ECE', `
                     'AF+CF-A+BBS', 'AF+CF-A+BBP', 'AF+CF-A+PL+EC', 'AF+CF-A+PL+ECE', 'AF+CF-A+PL+BBS', `
                     'AF+CF-A+PL+BBP', 'AF+CF-A+EC+BBS', 'AF+CF-A+EC+BBP', 'AF+CF-A+ECE+BBS', 'AF+CF-A+ECE+BBP', `
                     'AF+CF-A+PL+EC+BBS', 'AF+CF-A+PL+EC+BBP', 'AF+CF-A+PL+ECE+BBS', 'AF+CF-A+PL+ECE+BBP', 'PL+CF-A', `
                     'PL+CF-A+EC', 'PL+CF-A+ECE', 'PL+CF-A+BBS', 'PL+CF-A+BBP', 'PL+CF-A+EC+BBS', 'PL+CF-A+EC+BBP', `
                     'PL+CF-A+ECE+BBS', 'PL+CF-A+ECE+BBP', 'EC+CF-A', 'ECE+CF-A', 'EC+CF-A+BBS', 'EC+CF-A+BBP', `
                     'ECE+CF-A+BBS', 'ECE+CF-A+BBP', 'BBS+CF-A', 'BBP+CF-A','CF-W', 'AF+CF-W', 'AF+CF-W+PL', `
                     'AF+CF-W+EC', 'AF+CF-W+ECE', 'AF+CF-W+BBS', 'AF+CF-W+BBP', 'AF+CF-W+PL+EC', 'AF+CF-W+PL+ECE', `
                     'AF+CF-W+PL+BBS', 'AF+CF-W+PL+BBP', 'AF+CF-W+EC+BBS', 'AF+CF-W+EC+BBP', 'AF+CF-W+ECE+BBS', `
                     'AF+CF-W+ECE+BBP', 'AF+CF-W+PL+EC+BBS', 'AF+CF-W+PL+EC+BBP', 'AF+CF-W+PL+ECE+BBS', `
                     'AF+CF-W+PL+ECE+BBP', 'PL+CF-W', 'PL+CF-W+EC', 'PL+CF-W+ECE', 'PL+CF-W+BBS', 'PL+CF-W+BBP', `
                     'PL+CF-W+EC+BBS', 'PL+CF-W+EC+BBP', 'PL+CF-W+ECE+BBS', 'PL+CF-W+ECE+BBP', 'EC+CF-W', `
                     'ECE+CF-W', 'EC+CF-W+BBS', 'EC+CF-W+BBP', 'ECE+CF-W+BBS', 'ECE+CF-W+BBP', 'BBS+CF-W', 'BBP+CF-W')
   }       
           

   return $deviceData
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
        
        if ($filtered.Count -gt 0) {
            return $filtered.ToArray()
        } else {
            return @($availableResolutions[0])
        }
    }
    
    # Check for wildcard (all resolutions)
    if ($requestedResolutions -contains "All" -or $requestedResolutions -contains "*") {
        Write-Log -Message "Using ALL available $resolutionType resolutions as requested" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
        return $availableResolutions
    }
    
    # Process requested resolutions
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
    
    return $filtered.ToArray()
}