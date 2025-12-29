Add-Type -AssemblyName System.Windows.Forms

<#
DESCRIPTION:
    This function opens the Camera app and toggles various AI effects (such as Automatic Framing,
    Eye Contact, Background Effects, and others) based on the provided parameters. It checks for 
    policy support before enabling certain features and closes the app after adjustments.
INPUT PARAMETERS:
    - AFVal [string] :- Value to toggle Automatic Framing ("On" or "Off").
    - PLVal [string] :- Value to toggle Portrait Light ("On" or "Off").
    - BBVal [string] :- Value to toggle Background Effects ("On" or "Off").
    - BSVal [string] :- Value to select Standard Blur (applicable when Background Effects are On).
    - BPVal [string] :- Value to select Portrait Blur (applicable when Background Effects are On).
    - ECVal [string] :- Value to toggle Eye Contact ("On" or "Off").
    - ECSVal [string] :- Value to select Standard Eye Contact mode (applicable when Eye Contact is On).
    - ECTVal [string] :- Value to select Teleprompter Eye Contact mode (applicable when Eye Contact is On).
    - CF [string] :- Value to toggle Creative Filters ("On" or "Off").
    - CFI [string] :- Value to select Illustrated Filter (applicable when Creative Filters are On).
    - CFA [string] :- Value to select Animated Filter (applicable when Creative Filters are On).
    - CFW [string] :- Value to select Watercolor Filter (applicable when Creative Filters are On).
RETURN TYPE:
    - void (Applies changes to camera settings without returning a value.)
#>
function ToggleAiEffectsInCameraApp($AFVal,$PLVal,$BBVal,$BSVal,$BPVal,$ECVal,$ECSVal,$ECTVal,$CF,$CFI,$CFA,$CFW)
{   

   #Open Camera App
   Write-Log -Message "Open camera App" -IsOutput
   $uiEle = OpenApp 'microsoft.windows.camera:' 'Camera'
   Start-Sleep -s 1

   #Switch to video mode
   SwitchModeInCameraApp $uiEle "Switch to video mode" "Take video" 
   Start-Sleep -s 2

   #Open Windows Studio effects and toggle AI effects
   Write-Log -Message "Navigate to Windows Studio Effects" -IsOutput

   FindAndClickList -uiEle $uiEle -clsNme ToggleButton -proptyNmeLst @('Windows Studio effects','Windows Studio Effects','Effects')

   Start-Sleep -s 1
   
   Write-Log -Message "Toggle camera effects in camera App UI" -IsOutput
   FindAndSetValue $uiEle ToggleSwitch "Automatic framing" $AFVal
   FindAndSetValue $uiEle ToggleSwitch "Eye contact" $ECVal
   FindAndSetValue $uiEle ToggleSwitch "Background effects" $BBVal
   Start-Sleep -s 1
   if($BBVal -eq "On")
   {
      FindAndSetValue $uiEle RadioButton "Standard blur" $BSVal  
      FindAndSetValue $uiEle RadioButton "Portrait blur" $BPVal
   }
   $wsev2PolicyState = CheckWSEV2Policy
   if($wsev2PolicyState -eq $true)
   {
      Start-Sleep -s 1
      FindAndSetValue $uiEle  ToggleSwitch "Portrait light" $PLVal
      FindAndSetValue $uiEle  ToggleSwitch "Creative filters" $CF
      if($CF -eq "On")
      {  
         Start-Sleep -s 1 
         FindAndSetValue $uiEle  RadioButton "Illustrated" $CFI
         FindAndSetValue $uiEle  RadioButton "Animated" $CFA
         FindAndSetValue $uiEle  RadioButton "Water color" $CFW

      }
      if($ECVal -eq "On")
      { 
         Start-Sleep -s 1 
         FindAndSetValue $uiEle  RadioButton "Standard" $ECSVal
         FindAndSetValue $uiEle  RadioButton "Teleprompter" $ECTVal
      }
   }
   #Close camera App
   CloseApp 'WindowsCamera'
}

<#
DESCRIPTION:
    This function navigates through the Camera app settings to set the default behavior 
    for the app at the start of each session. It allows toggling between "Use system settings" 
    and "Use custom in-app settings."
INPUT PARAMETERS:
    - uiEle [object] :- The UI automation element representing the Camera app.
    - selSetting [string] :- The setting to apply as the default, either "Use system settings" 
                             or "Use custom in-app settings."
RETURN TYPE:
    - void (Applies the selected setting without returning a value.)
#>
function SetDefaultSettingInCameraApp($uiEle, $selSetting)
{
          
     #Set Default setting to "Use System settings"
     Write-Log -Message "Set default setting to $selSetting" -IsOutput
     FindAndClick $uiEle Button "Open Settings Menu"
     FindAndClick $uiEle Microsoft.UI.Xaml.Controls.Expander "Camera settings"
     FindAndClick $uiEle ComboBox "Default settings - These settings apply to the Camera app at the start of each session"
     FindAndClick $uiEle ComboBoxItem $selSetting
     FindAndClick $uiEle Button "Back"
}

<#
DESCRIPTION:
    This function opens the Camera app and sets the default settings to "Use system settings".
    It ensures that any custom camera configurations are reset to the system default before closing the app.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - void (Applies the default settings without returning a value.)
#>
function Set-SystemSettingsInCamera {
    #Open Camera app and set default setting to Use system settings
    $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
    Start-Sleep -s 1

    SetDefaultSettingInCameraApp -uiEle $ui -selSetting "Use system settings"
    
    #Close camera App
    CloseApp 'WindowsCamera'
}

<#
DESCRIPTION:
    This function opens the Camera app and sets the default configuration to "Use custom in-app settings." 
    It customizes the camera settings as per the in-app configurations and closes the Camera app after applying the changes.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - void (Applies custom settings and closes the Camera app without returning a value.)
#>
function Set-CustomInSettingsInCamera {
    #Open Camera app and set default setting to Use system settings
    $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
    Start-Sleep -s 1

    SetDefaultSettingInCameraApp -uiEle $ui -selSetting "Use custom in-app settings"
    
    #Close camera App
    CloseApp 'WindowsCamera'
}

<#
DESCRIPTION:
    This function switches the Camera app mode between Photo and Video modes.
    It checks if the desired mode is already active before attempting to switch.
INPUT PARAMETERS:
    - uiEle [object] :- The UI automation element representing the Camera app.
    - swtchMde [string] :- The mode to switch to ("Switch to photo mode" or "Switch to video mode").
    - chkEle [string] :- The UI element to verify the current mode ("Take photo" or "Take video").
RETURN TYPE:
    - void (Switches the camera mode without returning a value.)
#>
function SwitchModeInCameraApp($uiEle, $swtchMde, $chkEle) 
{
    $return = CheckIfElementExists $uiEle ToggleButton $chkEle
    if ($return -eq $null){
        Write-Log -Message "$swtchMde" -IsOutput
        FindAndClick $uiEle Button $swtchMde
    }
    else
    {
       Write-Log -Message "Already in $chkEle mode" -IsOutput
    }
}

<#
DESCRIPTION:
    This function starts the Camera app, switches to video mode, and records a video for a specified
    duration. It captures the start time in UTC format and returns it for later verification.
INPUT PARAMETERS:
    - duration [int] :- The duration is the number of iterations of video recording.
    - snarioName [string] :- Scenario name used for resource logging 
    - logPath [string] :- Path to write resource utilization logs 
RETURN TYPE:
    - [DateTime] (Returns the start time of the video recording in UTC format.)
#>
function StartVideoRecording
{  
     param($duration, $snarioName, $logPath)

     #Open Task Manager and set speed to low
     setTMUpdateSpeedLow

     #Capture Resource Utilization before test starts
     Monitor-Resources -scenario $snarioName -executionState "Before" -logPath $logPath  -Once "Once"
     start-sleep -s 1

     #Open Camera App
     Write-Log -Message "Open camera App" -IsOutput
     $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
     Start-Sleep -s 1

     #Capture the start time for Camera App
     $cameraApp = Get-Process -Name WindowsCamera | select starttime
     $cameraAppStart = $cameraApp.StartTime

     #Set time zone to UTC as Asg trace logs are using UTC date format
     $cameraAppStartinUTC = $cameraAppStart.ToUniversalTime()
     
     #Convert the date to string format to add the milliseconds 
     $cameraAppStartTostring = $cameraAppStartinUTC.ToString('yyyy/MM/dd HH:mm:ss:fff')
     
     #Coverting the string back to date format for time calculation in code later in CheckInitTimeCameraApp function.
     $cameraAppStartTime = [System.DateTime]::ParseExact($cameraAppStartTostring,'yyyy/MM/dd HH:mm:ss:fff',$null)
                                  
     #Switch to video mode if not in video mode
     SwitchModeInCameraApp $ui "Switch to video mode" "Take video" 
     Start-Sleep -s 2
     
     #record video inbetween space presses
     Write-Log -Message "Start recording a video" -IsOutput
     [System.Windows.Forms.SendKeys]::SendWait(' ');
   
     #Capture Resource Utilization while test is running
     Monitor-Resources -Scenario $snarioName -duration $duration -executionState "During" -logPath $logPath 
          
     [System.Windows.Forms.SendKeys]::SendWait(' ');
     Start-Sleep -s 2
     Write-Log -Message "video recording stopped" -IsOutput
     
     #restores photo mode for the next run(This line will be uncommented once camera issue is fixed)
     #SwitchModeInCameraApp $ui "Switch to photo mode" "Take photo"
     Start-Sleep -s 2

     #Close camera App
     CloseApp 'WindowsCamera'
     Start-Sleep -s 1  

     #Return the value to pass as parameter to CheckInitTimeCameraApp function in camerae2eTest.ps1 and CameraAppTest.ps1
     return , $cameraAppStartTime 
}

<#
DESCRIPTION:
    This function starts the Camera app, switches to photo mode, and takes a photo.
RETURN TYPE:
    - void (Taking a photo in Camera app without returning a value.)
#>
function StartPhotoCapturing
{
    # Open Camera App
    $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
    Start-Sleep -Seconds 1

    # Switch to photo mode if not in photo mode
    SwitchModeInCameraApp $ui "Switch to photo mode" "Take photo"
    Start-Sleep -Seconds 2

    # Take a photo
    [System.Windows.Forms.SendKeys]::SendWait(' ')
    Start-Sleep -Seconds 2

    # Close Camera App
    CloseApp 'WindowsCamera'
    Start-Sleep -Seconds 1
}

<#
DESCRIPTION:
    This function opens the Camera app, switches to video mode, and starts previewing for a specified duration.
    It captures the app's start time in UTC format, which can be used later for log and performance analysis.
    After the previewing is complete, the Camera app is closed, and the start time is returned.
INPUT PARAMETERS:
    - duration [int] :- The duration is the number of iterations of video Previewing.
    - snarioName [string] :- Scenario name used for resource logging.
    - logPath [string] :- Path to write resource utilization logs.
RETURN TYPE:
    - [DateTime] (Returns the start time of the Camera app in UTC format for later time calculations.)
#>
function CameraPreviewing
{  
     param($duration, $snarioName, $logPath)
     #Open Task Manager and set speed to low
     setTMUpdateSpeedLow

     #Capture Resource Utilization before test starts
     Monitor-Resources -scenario $snarioName -executionState "Before" -logPath $logPath  -Once "Once"
     start-sleep -s 1
     
     #Open Camera App
     Write-Log -Message "Open camera App" -IsOutput
     $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
     Start-Sleep -s 1

     #Capture the start time for Camera App
     $cameraApp = Get-Process -Name WindowsCamera | select starttime
     $cameraAppStart = $cameraApp.StartTime

     #Set time zone to UTC as Asg trace logs are using UTC date format
     $cameraAppStartinUTC = $cameraAppStart.ToUniversalTime()
     
     #Convert the date to string format to add the milliseconds 
     $cameraAppStartTostring = $cameraAppStartinUTC.ToString('yyyy/MM/dd HH:mm:ss:fff')

     #Coverting the string back to date format for time calculation in code later CheckInitTimeCameraApp function.
     $cameraAppStartTime = [System.DateTime]::ParseExact($cameraAppStartTostring,'yyyy/MM/dd HH:mm:ss:fff',$null)
                          
     #Switch to video mode and start previewing as few photo resolution does not support MEP feature"
     SwitchModeInCameraApp $ui "Switch to video mode" "Take video" 
          
     #Capture Resource Utilization while test is running
     Monitor-Resources -Scenario $snarioName -duration $duration -executionState "During" -logPath $logPath 
     
     #Close camera App
     CloseApp 'WindowsCamera'
     Write-Log -Message "Previewing stopped " -IsOutput

     #Return the value to pass as parameter to CheckInitTimeCameraApp function in camerae2eTest.ps1 and CameraAppTest.ps1
     return , $cameraAppStartTime 
}

<#
DESCRIPTION:
    This function opens the Camera app and sets the video resolution to the highest available setting.
    It retrieves the resolution from the UI and applies it before closing the app.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - [string] (Returns the name of the highest video resolution applied.)
#>
function SetHighestVideoResolutionInCameraApp{
     #Open Camera App and set default setting to "Use system settings"
     $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
     Start-Sleep -s 1
     
     #Set Default setting to "Use System settings"
     FindAndClick $ui Button "Open Settings Menu"
     FindAndClickList -uiEle $ui -clsNme Microsoft.UI.Xaml.Controls.Expander -proptyNmeLst @('Videos settings','Video settings')
     FindAndClick $ui ComboBox "Video quality"
     $videoResName = FindFirstElementsNameWithClassName $ui ComboBoxItem
     FindAndClick $ui ComboBoxItem $videoResName
     Write-Log -Message "Set video resolution to $videoResName in camera app" -IsOutput
     FindAndClick $ui Button "Back"
     
     #Close Camera App
     CloseApp 'WindowsCamera'
     return , $videoResName
}

<#
DESCRIPTION:
    This function opens the Camera app and sets the photo resolution to the highest available setting.
    It retrieves the resolution from the UI and applies it before closing the app.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - [string] (Returns the name of the highest photo resolution applied.)
#>
function SetHighestPhotoResolutionInCameraApp{
     #Open Camera App and set default setting to "Use system settings"
     $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
     Start-Sleep -s 1
     
     #Set Default setting to "Use System settings"
     FindAndClick  $ui Button "Open Settings Menu"
     FindAndClickList -uiEle $ui -clsNme Microsoft.UI.Xaml.Controls.Expander -proptyNmeLst @('Photos settings','Photo settings')
     FindAndClick  $ui ComboBox "Photo quality"
     $photoResName = FindFirstElementsNameWithClassName $ui ComboBoxItem
     FindAndClick  $ui ComboBoxItem $photoResName
     Write-Log -Message "Set Photo resolution to $photoResName in camera app" -IsOutput
     FindAndClick  $ui Button "Back"
         
     #Close Camera App
     CloseApp 'WindowsCamera'
     return , $photoResName
   
}

<#
DESCRIPTION:
    This function opens the Camera app, switches to video mode if not already active, 
    and attempts to set the video resolution to the specified value. If the resolution 
    is unsupported, the test is skipped and logged.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the test scenario for logging purposes.
    - strtTime [datetime] :- The start time of the test, used to calculate execution time.
    - vdoRes [string] :- The desired video resolution (e.g., "1080p, 16 by 9 aspect ratio, 30 fps").
RETURN TYPE:
    - [bool] (Returns `$false` if the resolution is unsupported, otherwise closes the app without returning a value.)
#>
function SetvideoResolutionInCameraApp($snarioName, $strtTime, $vdoRes)
{      
     #Open Camera App
     Write-Log -Message "Open camera App" -IsOutput
     $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
     Start-Sleep -s 1

     #Switch to video mode if not in video mode(Note until we switch to video mode the changes made in video resolution does not persist)
     SwitchModeInCameraApp $ui "Switch to video mode" "Take video" 

     #set video quality 
     FindAndClick $ui Button "Open Settings Menu"
     Write-Log -Message "Set video quality to $vdoRes" -IsOutput

     #Find video settings and click
     FindAndClickList -uiEle $ui -clsNme Microsoft.UI.Xaml.Controls.Expander -proptyNmeLst @('Videos settings','Video settings')

     FindAndClick $ui ComboBox "Video quality"

     #Select the video resolution if supported
     $return = CheckIfElementExists $ui ComboBoxItem $vdoRes
     if ($return -eq $null){
         TestOutputMessage $snarioName "Skipped" $strtTime  "unsupported resolution" 
         CloseApp 'WindowsCamera'
         return ,$false
     }
     else
     {
         FindAndClick $ui ComboBoxItem $vdoRes
         CloseApp 'WindowsCamera'
     }
     
}

<#
DESCRIPTION:
    This function opens the Camera app and attempts to set the photo resolution to the specified value. 
    If the resolution is unsupported, the test is skipped and logged accordingly.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the test scenario for logging purposes.
    - strtTime [datetime] :- The start time of the test, used to calculate execution time.
    - photRes [string] :- The desired photo resolution (e.g., "12.2 megapixels, 4 by 3 aspect ratio, 4032 by 3024 resolution").
RETURN TYPE:
    - [bool] (Returns `$false` if the resolution is unsupported, otherwise closes the app without returning a value.)
#>
function SetphotoResolutionInCameraApp($snarioName, $strtTime, $photRes)
{    
     #Open Camera App
     Write-Log -Message "Open camera App" -IsOutput
     $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
     Start-Sleep -s 1

     #set photo quality
     FindAndClick $ui Button "Open Settings Menu"
     Write-Log -Message "Set photo quality to $photRes" -IsOutput


     #Find Photo settings and click
     FindAndClickList -uiEle $ui -clsNme Microsoft.UI.Xaml.Controls.Expander -proptyNmeLst @('Photos settings','Photo settings')
     
     FindAndClick $ui ComboBox "Photo quality"

     #Select the photo resolution if supported
     $return = CheckIfElementExists $ui ComboBoxItem $photRes
     if ($return -eq $null){
         TestOutputMessage $snarioName "Skipped" $strtTime  "unsupported resolution" 
         CloseApp 'WindowsCamera'
         return ,$false
     }
     else
     {
         FindAndClick $ui ComboBoxItem $photRes
         CloseApp 'WindowsCamera'
         
     } 
}

<#
DESCRIPTION:
    This function validates that Windows Studio Effects (WSE) are not supported in Photo mode 
    of the Camera app. It checks for related UI elements and logs, ensuring no perception 
    core scenarios are initialized in Photo mode.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for organizing logs.
RETURN TYPE:
    - void (Performs validation and logging without returning a value.)
#>
function ValidateWSEInPhotoMode($snarioName)
{  
   $scenarioName = "$snarioName\ValidateWSEInPhotoMode"
   CreateScenarioLogsFolder $scenarioName 

   #Open Camera App
   Write-Log -Message "Open camera App" -IsOutput
   $uiEle = OpenApp 'microsoft.windows.camera:' 'Camera'
   Start-Sleep -s 2

   #Switch to Photo mode
   SwitchModeInCameraApp $uiEle "Switch to photo mode" "Take photo" 
   Start-Sleep -s 1

   #Close camera App
   CloseApp 'WindowsCamera'
   Start-Sleep -s 1

   #Checks if frame server is stopped
   Write-Log -Message "Entering CheckServiceState function" -IsOutput
   CheckServiceState 'Windows Camera Frame Server'
                 
   #Strating to collect Traces
   Write-Log -Message "Entering StartTrace function" -IsOutput
   StartTrace $scenarioName
     
   #Open Camera App
   Write-Log -Message "Open camera App" -IsOutput
   $uiEle = OpenApp 'microsoft.windows.camera:' 'Camera'
   Start-Sleep -s 1

   #Verify Windows Studio Effects not supported in Photo Mode
   Write-Log -Message "Navigate to Windows Studio Effects" -IsOutput
   
   $exists = CheckIfElementExists $uiEle ToggleButton "Windows Studio effects"
   if ($exists)
   {
      Write-Log -Message "   Error- Windows Studio Effects supported in Photo Mode " -IsHost -ForegroundColor Yellow
   }
   else
   {
      Write-Log -Message "Validation successful -Windows Studio Effects not supported in Photo Mode" -IsOutput
   } 
     
   #Close camera App
   CloseApp 'WindowsCamera'
   
   #Checks if frame server is stopped
   Write-Log -Message "Entering CheckServiceState function" -IsOutput
   CheckServiceState 'Windows Camera Frame Server' 
   
   #Stop the Trace
   Write-Log -Message "Entering StopTrace function" -IsOutput
   StopTrace $scenarioName
 
   #Validate PerceptionSessionUsageStats is not captured in PhotoMode. If PerceptionSessionUsageStats is captured, verify PC Scenario is not initialized 
   $pathAsgTraceTxt = "$pathLogsFolder\$scenarioName\" + "AsgTrace.txt"  
   $pattern = "PerceptionSessionUsageStats"
   $pcUsageStats = (Select-string -path  $pathAsgTraceTxt -Pattern $pattern)
   if($pcUsageStats.Length -eq 0)
   { 
      Write-Log -Message "No PerceptionSessionUsageStats captured in Asgtrace while in PhotoMode" -IsOutput
   }
   else
   {
      Write-Log -Message "PerceptionSessionUsageStats captured in Asgtrace while in PhotoMode "  -IsOutput
      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
            
      #Reading log file to verify PC Scenario is not initialized 
      $scenarioID = $frameProcessingDetails[8].Trim()

      if($scenarioID -eq 0)
      {
         Write-Log -Message "No PerceptionCore Scenrio is initialized" -IsOutput
      }   
      else
      {
         Write-Log -Message "   PerceptionCore Scenario is initialized and captured in Asgtrace while in PhotoMode " -IsHost -ForegroundColor Yellow
      } 

   }
   #Open Camera App
   Write-Log -Message "Open camera App" -IsOutput
   $uiEle = OpenApp 'microsoft.windows.camera:' 'Camera'
   Start-Sleep -s 1

   #Switch to video mode
   SwitchModeInCameraApp $uiEle "Switch to video mode" "Take video" 
   Start-Sleep -s 2

   #Close camera App
   CloseApp 'WindowsCamera'
}