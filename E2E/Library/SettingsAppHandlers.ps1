<#
DESCRIPTION:
    This function navigates through the Settings app to find and open the Camera Effects page.
    It clicks through the navigation items to access the camera settings, and identifies the 
    appropriate camera for further adjustments.
INPUT PARAMETERS:
    - uiEle [Object] :- The UI Automation element representing the Settings app interface.
RETURN TYPE:
    - void (Performs UI navigation and clicking without returning a value.)
#>
function FindCameraEffectsPage($uiEle){
    FindAndClick $uiEle Microsoft.UI.Xaml.Controls.NavigationViewItem "Bluetooth & devices"
    FindAndClick $uiEle ListViewItem Cameras
    $exists = CheckIfElementExists $uiEle Button More
    if ($exists)
    {
        ClickFrontCamera $uiEle Button More
    }
    else
    {
        FindAndClick $uiEle Button "Connected enabled camera $Global:validatedCameraFriendlyName"
    }
    Start-Sleep -s 1
    [System.Windows.Forms.SendKeys]::SendWait('{END}') 
    Start-Sleep -s 1   
}

<#
DESCRIPTION:
    This function help finding the Front facing camera when UI element name is same.on setting page
INPUT PARAMETERS:
    - uiEle [Object] :- The UI Automation element representing the Settings app interface.
    - clsNme [string] :- The class name of the UI element to be clicked.
    - proptyNme [string] :- The name of the UI element to be clicked.
RETURN TYPE:
    - void (Performs UI element selection and clicking without returning a value.)
#>
function ClickFrontCamera($uiEle, $clsNme, $proptyNme){
    $classNameCondition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty, $clsNme)
    $nameCondition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty, $proptyNme)
    $jointCondition = New-Object Windows.Automation.AndCondition($classNameCondition, $nameCondition)
    $elemt =@()
    $i = 0
    while($i -lt 2)
    {
       $elemt = $uiEle.FindAll([Windows.Automation.TreeScope]::Descendants, $jointCondition)
       $clickableElement = $elemt[$i]
       
       if ( $clickableElement.GetCurrentPropertyValue([Windows.Automation.AutomationElement]::IsInvokePatternAvailableProperty) ){
           $clickableElement.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
       }
       $exists = CheckIfElementExists $uiEle ToggleSwitch "Automatic framing" 
       if (!$exists)
	   {
          FindAndClick $uiEle Button Back
          
       }
       else
       {
          return
       }
       $i++
    }    
}

<#
DESCRIPTION:
    This function navigates to the Voice Focus settings page in the Settings app. It checks 
    for the presence of audio devices and navigates through the menus to find the audio 
    enhancements section.
INPUT PARAMETERS:
    - uiEle [Object] :- The UI Automation element representing the Settings app interface.
RETURN TYPE:
    - void (Performs UI navigation and clicking without returning a value.)
#>
function FindVoiceFocusPage($uiEle){
    FindAndClick $uiEle Microsoft.UI.Xaml.Controls.NavigationViewItem System
    FindAndClick $uiEle ListViewItem Sound
    $exists = CheckIfElementExists $uiEle Button More
    if ($exists)
    {
        FindAndClick $uiEle Button More
    }
    else
    {
        $exists = CheckIfElementExists $uiEle Button  "All sound devices"
        if ($exists)
	    {
            FindAndClick $uiEle Button "All sound devices"
        }
        else
        {
           Write-Error " No Sound devices button found is Sound Setting page " -ErrorAction Stop     
        }
    }
    $i=0
    $allSoundDevices = @( "Internal Microphone" , "Microphone on SoundWire Device" , "Microphone Array" ,"Internal Microphone Array - Front","Surface Stereo Microphones")
    $exists = CheckIfElementExists $uiEle Button $allSoundDevices[$i]
    while($exists.length -eq 0 -and $i -lt 4)
    {
      $i++ 
      $exists = CheckIfElementExists $uiEle Button $allSoundDevices[$i]
    }
    if ($exists)
    {
        FindAndClick $uiEle Button $allSoundDevices[$i]
    }
    else
    {
       Write-Error " Microphone Array not found in Sound setting Page " -ErrorAction Stop     
    } 
    FindAndClick $uiEle ComboBox "Audio enhancements"
    Start-Sleep -m 500
    Foreach($audioEnhancementOptions in "Microsoft Windows Studio Voice Focus" , "Windows Studio Effects Voice Clarity")
    {
       $exists = CheckIfElementExists $uiEle ComboBoxItem  $audioEnhancementOptions
       if ($exists)
       {
           FindAndClick $uiEle ComboBoxItem $audioEnhancementOptions
       }
    
    }
}

<#
DESCRIPTION:
    This function toggles the Voice Focus setting in the Settings app. It first checks if 
    the device supports Voice Focus, and then toggles the setting based on the provided value.
INPUT PARAMETERS:
    - proptyVal [string] :- The desired state of the Voice Focus toggle ("On" or "Off").
RETURN TYPE:
    - void (Performs UI interactions to toggle Voice Focus without returning a value.)
#>
Function VoiceFocusToggleSwitch($proptyVal)
{    
     #Check if device supports audio blur functionality or not. Exit this function if audio blur is not supported. 
     $voiceFocusExists = CheckVoiceFocusPolicy
     if($voiceFocusExists -eq $false)
     {
        return 
     }
     
     #Write-Output "Entering VoiceFocusToggleSwitch function" 
     #open settings app and obtain ui automation from it   
     $ui = OpenApp 'ms-settings:' 'Settings'
     Start-Sleep -m 500

     #Navigate to audio effects page to toggle voice focus On/Off  
     Write-Log -Message "Navigate to audio effects page" -IsOutput
     FindVoiceFocusPage $ui
     Start-Sleep -m 500
     
     Write-Log -Message "Turn $proptyVal all audio effects" -IsOutput
     $exists = CheckIfElementExists $ui ToggleSwitch "Voice Focus" 
     if ($exists)
     {
        FindAndSetValue $ui ToggleSwitch "Voice Focus" $proptyVal
        Start-Sleep -s 1
     }
     else
     {
        FindAndClick $ui ComboBox "Voice Focus"
        FindAndClick $ui ComboBoxItem $proptyVal
     }

     #close settings app
     CloseApp 'systemsettings'
}

<#
DESCRIPTION:
    This function toggles various AI camera effects and audio enhancements in the Settings app. 
    It handles different combinations of settings based on whether WSEV2 is supported.
INPUT PARAMETERS:
    - AFVal [string] :- Toggle value for Automatic Framing.
    - AFSVal [string] :- Toggle value for Standard Framing.
    - AFCVal [string] :- Toggle value for Cinematic Framing.
    - PLVal [string] :- Toggle value for Portrait Light.
    - BBVal [string] :- Toggle value for Background Effects.
    - BSVal [string] :- Toggle value for Standard Blur.
    - BPVal [string] :- Toggle value for Portrait Blur.
    - ECVal [string] :- Toggle value for Eye Contact.
    - ECSVal [string] :- Toggle value for Standard Eye Contact style.
    - ECTVal [string] :- Toggle value for Teleprompter Eye Contact style.
    - VFVal [string] :- Toggle value for Voice Focus.
    - CF [string] :- Toggle value for Creative Filters.
    - CFI [string] :- Toggle value for Illustrated Creative Filter.
    - CFA [string] :- Toggle value for Animated Creative Filter.
    - CFW [string] :- Toggle value for Watercolor Creative Filter.
RETURN TYPE:
    - void (Performs UI interactions to toggle camera and audio effects without returning a value.)
#>
Function ToggleAIEffectsInSettingsApp($AFVal,$AFSVal,$AFCVal,$PLVal,$BBVal,$BSVal,$BPVal,$ECVal,$ECSVal,$ECTVal,$VFVal,$CF,$CFI,$CFA,$CFW)
{    
     Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function" -IsOutput
     
     #open settings app and obtain ui automation from it
     $ui = OpenApp 'ms-settings:' 'Settings'
     Start-Sleep -s 1
     
     #open camera effects page and turn all effects off
     Write-Log -Message "Navigate to camera effects setting page" -IsOutput
     FindCameraEffectsPage $ui
     Start-Sleep -s 1

     Write-Log -Message "Toggle camera effects in setting Page" -IsOutput
     FindAndSetValue $ui ToggleSwitch "Automatic framing" $AFVal
     FindAndSetValue $ui ToggleSwitch "Eye contact" $ECVal
     FindAndSetValue $ui ToggleSwitch "Background effects" $BBVal

     if($BBVal -eq "On")
     {
        FindAndSetValue $ui RadioButton "Standard blur" $BSVal  
        FindAndSetValue $ui RadioButton "Portrait blur" $BPVal
     }
     $wsev2PolicyState = CheckWSEV2Policy
     if($wsev2PolicyState -eq $true)
     {
        Write-Log -Message "Toggle camera effects in setting Page" -IsOutput
               
        FindAndSetValue $ui ToggleSwitch "Portrait light" $PLVal
        FindAndSetValue $ui ToggleSwitch "Creative filters" $CF
        if($CF -eq "On")
        {   
           FindAndSetValue $ui RadioButton "Illustrated" $CFI
           FindAndSetValue $ui RadioButton "Animated" $CFA
           FindAndSetValue $ui RadioButton "Watercolor" $CFW

        }
        if($ECVal -eq "On")
        { 
           FindAndSetValue $ui RadioButton "Standard" $ECSVal
           FindAndSetValue $ui RadioButton "Teleprompter" $ECTVal
        }
        $wse8480PolicyState = Check8480Policy
        if ($wse8480PolicyState -eq $true)
		{
           if($AFVal -eq "On")
           {   
              FindAndSetValue $ui RadioButton "Standard framing" $AFSVal
              FindAndSetValue $ui RadioButton "Cinematic framing" $AFCVal
		   
           }
		}
     }
     
     
     #open microphone effects page and turn all effects off
     VoiceFocusToggleSwitch $VFVal
          
     #close settings app
     CloseApp 'systemsettings'
}