function FindCameraEffectsPage($uiEle){
    FindAndClick $uiEle Microsoft.UI.Xaml.Controls.NavigationViewItem Apps
    Start-Sleep -m 500
    FindAndClick $uiEle Microsoft.UI.Xaml.Controls.NavigationViewItem "Bluetooth & devices"
    Start-Sleep -m 500
    FindAndClick $uiEle ListViewItem Cameras
    Start-Sleep -m 500
    $exists = CheckIfElementExists $uiEle Button More
    if ($exists)
    {
        ClickFrontCamera $uiEle Button More
    }
    else
    {   
        $propertyNameList = @(
        'Connected enabled camera Surface Camera Front',
        'Connected enabled camera OV01AS',
        'Connected enabled camera ASUS FHD webcam'
        'Connected enabled camera HP 9MP Camera'
        'Connected enabled camera Integrated Camera'
        )
        FindAndClickList $uiEle Button $propertyNameList
    }  
    Start-Sleep -m 500
}

#This function help finding the Front facing camera when UI element name is same.on setting page
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
       sleep -s 1
       $exists = CheckIfElementExists $uiEle ToggleSwitch "Automatic framing" 
       if (!$exists)
	   {
          FindAndClick $uiEle Button Back
          sleep -s 1
          
       }
       else
       {
          return
       }
       $i++
    }    
}
function FindVoiceFocusPage($uiEle){
    FindAndClick $uiEle Microsoft.UI.Xaml.Controls.NavigationViewItem Apps
    Start-Sleep -m 500
    FindAndClick $uiEle Microsoft.UI.Xaml.Controls.NavigationViewItem System
    Start-Sleep -m 500
    FindAndClick $uiEle ListViewItem Sound
    Start-Sleep -m 500
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
    Start-Sleep -m 500
    $i=0
    $allSoundDevices = @( "Internal Microphone" , "Microphone on SoundWire Device" , "Microphone Array" ,"Internal Microphone Array - Front")
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
    Start-Sleep -m 500
    FindAndClick $uiEle ComboBox "Audio enhancements"
    Start-Sleep -m 500
    FindAndClick $uiEle ComboBoxItem "Microsoft Windows Studio Voice Focus"
  
}
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
     Write-Output "Navigate to audio effects page"
     FindVoiceFocusPage $ui
     Start-Sleep -m 500
     
     Write-Output "Turn $proptyVal all audio effects"
     FindAndSetValue $ui ToggleSwitch "Voice Focus" $proptyVal
     Start-Sleep -s 1

     #close settings app
     CloseApp 'systemsettings'
}
Function ToggleAIEffectsInSettingsApp($AFVal,$PLVal,$BBVal,$BSVal,$BPVal,$ECVal,$ECSVal,$ECEVal,$VFVal,$CF,$CFI,$CFA,$CFW)
{    
     Write-Output "Entering ToggleAIEffectsInSettingsApp function" 
     
     #open settings app and obtain ui automation from it
     $ui = OpenApp 'ms-settings:' 'Settings'
     Start-Sleep -s 1
     
     #open camera effects page and turn all effects off
     Write-Output "Navigate to camera effects setting page"
     FindCameraEffectsPage $ui
     Start-Sleep -s 1

     Write-Output "Toggle camera effects in setting Page"
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
        Write-Output "Toggle camera effects in setting Page"
               
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
           FindAndSetValue $ui RadioButton "Teleprompter" $ECEVal
        }
     }
     
     #open microphone effects page and turn all effects off
     VoiceFocusToggleSwitch $VFVal
          
     #close settings app
     CloseApp 'systemsettings'
}