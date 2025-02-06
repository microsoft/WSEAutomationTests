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
   $deviceData.VideoResolutions = GetVideoResList -videoResolutions @('1440p', '1080p', '720p', '480p', '360p', '1440p1', '1080p1', '960p', '640p', '540p')
   $deviceData.PhotoResolutions = GetPhotoResList -photoResolutions @('12.2MP', '5.0MP', '2.1MP', '0.9MP', '0.3MP', '0.2MP')
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

INPUT PARAMETERS:
    - videoResolutions [array]: An array of video resolution names to check for support.

RETURN TYPE:
    - Array: List of supported video resolutions.
#>
Function GetVideoResList($videoResolutions)
{
     #Open Camera App
     $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
     Start-Sleep -s 1

     #Switch to video mode if not in video mode(Note until we switch to video mode the changes made in video resolution does not persist)
     $return = CheckIfElementExists $ui ToggleButton "Take video" 
     if ($return -eq $null){
        FindAndClick $ui Button "Switch to video mode" 
        Start-Sleep -s 2  
     }
     else
     {
       #It should already be in video mode
       Start-Sleep -s 1
     }
     #Get video quality 
     FindAndClick $ui Button "Open Settings Menu"
     Start-Sleep -s 1
    
     #Find video settings and click
     FindAndClickList -uiEle $ui -clsNme Microsoft.UI.Xaml.Controls.Expander -proptyNmeLst @('Videos settings','Video settings')
     Start-Sleep -s 1
     
     FindAndClick $ui ComboBox "Video quality"
     Start-Sleep -s 1
     $vdoResList = @()
     foreach($vdoRes in  $videoResolutions)
     {
        $vdoResDetails = RetrieveValue $vdoRes
        
        #Get the supported video resolution
        $return = CheckIfElementExists $ui ComboBoxItem $vdoResDetails
        if ($return -ne $null)
        {
           $vdoResList += $vdoRes
        }
        else
        {
            continue;
        }
     }
     Stop-Process -Name 'WindowsCamera'
     start-sleep -s 1
     return $vdoResList
}

<#
DESCRIPTION:
    This function retrieves the list of supported photo resolutions from the Camera app settings.
    It opens the Camera app and checks the available photo quality options.

INPUT PARAMETERS:
    - photoResolutions [array]: An array of photo resolution names to check for support.

RETURN TYPE:
    - Array: List of supported photo resolutions.
#>
Function GetPhotoResList($photoResolutions)
{
   #Open Camera App
   $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
   Start-Sleep -s 1

   #Get photo quality
   FindAndClick $ui Button "Open Settings Menu"
   Start-Sleep -s 1 
   
   #Find Photo settings and click
   FindAndClickList -uiEle $ui -clsNme Microsoft.UI.Xaml.Controls.Expander -proptyNmeLst @('Photos settings','Photo settings')
   Start-Sleep -s 1

   FindAndClick $ui ComboBox "Photo quality"
   Start-Sleep -s 1
   $ptoResList = @()
   foreach($ptoRes in  $photoResolutions)
   {
      $ptoResDetails = RetrieveValue $ptoRes
      
      #Get the supported video resolution
      $return = CheckIfElementExists $ui ComboBoxItem $ptoResDetails
      if ($return -ne $null)
      {
         $ptoResList += $ptoRes
      }
      else
      {
          continue;
      }
   }
   Stop-Process -Name 'WindowsCamera'
   start-sleep -s 1
   return $ptoResList
}