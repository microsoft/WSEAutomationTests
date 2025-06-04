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
    Generates all valid combinations of camera features based on WSEV2 policy state.
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