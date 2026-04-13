Add-Type -AssemblyName UIAutomationClient
<#
DESCRIPTION:
    The `Test-WSE+Recall` function automates the process of toggling AI effects, configuring camera settings,
    recording video, enabling Recall, and verifying logs. It also captures system performance data and 
    validates camera functionality.
    
PARAMETERS:
    - $devPowStat [string]: The device's power state (e.g., "PluggedIn", "Unplugged").
    - $token [string]: Authentication token for security.
    - $SPId [string]: Smart plug ID.
    
RETURNS:
    void: This function does not return a value. It performs the operations and logs the results.
#>
function Test-WSE+Recall($devPowStat, $token, $SPId) 
{   
    $startTime = Get-Date    
    $ErrorActionPreference='Stop'
    $scenarioName = "$devPowStat\WSE+Recall"
    $logFile = "$devPowStat-WSE+Recall.txt"
        
    try
	{  
       # Create Scenario folder
       $scenarioLogFolder = $scenarioName
       CreateScenarioLogsFolder $scenarioLogFolder
        
       # Toggling All effects on
       Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On" -IsOutput
       ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                     -ECVal "On" -ECSVal "True" -ECTVal "False" -VFVal "On" `
                                     -CF "On" -CFI "False" -CFA "False" -CFW "True"
                 
        # Open Camera App and set default setting to "Use system settings" 
        Set-SystemSettingsInCamera
       
        # Set photo resolution
	    $photoResName = SetHighestPhotoResolutionInCameraApp 
        $phoResNme = RetrieveValue $photoResName[-1]
        
        # Set video resolution
        $videoResName = SetHighestVideoResolutionInCameraApp
        $vdoResNme = RetrieveValue $videoResName[-1]
        
        $scenarioLogFolder = "$scenarioName\$phoResNme\$vdoResNme" 

        CreateScenarioLogsFolder $scenarioLogFolder
        
        # Check device Power state   
        $devState = CheckDevicePowerState $devPowStat $token $SPId
        if($devState -eq $false)
        {   
           TestOutputMessage $scenarioLogFolder "Skipped" $startTime "Token is empty"  
           return
        }

        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server'
                      
        # Strating to collect Traces
        Write-Log -Message "Entering StartTrace function" -IsOutput
        StartTrace $scenarioLogFolder
        
        # Open Task Manager
        Write-Log -Message "Opening Task Manager" -IsOutput
        $uitaskmgr = OpenApp 'Taskmgr' 'Task Manager'
        Start-Sleep -s 1
                                
        # Start video recording and close the camera app once finished recording 
        Write-Log -Message "Open camera App" -IsOutput
        $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
        Start-Sleep -s 1
                                                                  
        # Switch to video mode if not in video mode
        SwitchModeInCameraApp $ui "Switch to video mode" "Take video" 
        Start-Sleep -s 2
        
        # Record video inbetween space presses
        Write-Log -Message "Start recording a video for $scnds seconds" -IsOutput
        [System.Windows.Forms.SendKeys]::SendWait(' ');

        # Enable Recall and start browsing
        $recallEnabled = EnableRecall
        if($recallEnabled -eq $true)
        {  
           Open-Browser -srchDetails "Seven wonders of the world", "Statue of Liberty", "Taj Mahal", "Dubai" -Noofscrolls "40"
           Start-Sleep -s 2
        }                
        # Close Camera App
        CloseApp 'WindowsCamera'
        
        # Capture CPU and NPU Usage
        Write-Log -Message "Entering CPUandNPU-Usage function to capture CPU and NPU usage Screenshot" -IsOutput  
        stopTaskManager -uitaskmgr $uitaskmgr -Scenario $scenarioLogFolder
        
        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server' 
        
        # Stop the Trace
        Write-Log -Message "Entering StopTrace function" -IsOutput
        StopTrace $scenarioLogFolder

        # Verify and validate if proper logs are generated or not.   
        $wsev2PolicyState = CheckWSEV2Policy
                                                 
        # Set the ScenarioID based on the policy state
        if ($wsev2PolicyState -eq $false) {
            $scenarioID = "81968"  # Based on v1 effects
        } else {
            $scenarioID = "2703376"  # Based on v1+v2 effects, verify if this is correct
        }
        
        # Log the entry to Verifylogs function
        Write-Log -Message "Entering Verifylogs function with ScenarioID $scenarioID" -IsOutput
        
        # Call Verifylogs function
        Verifylogs $scenarioLogFolder $scenarioID $startTime

        #Verify and validate if proper logs are generated for Recall or not
        Verify-RecallLogs -snarioName $scenarioLogFolder -strtTime $startTime 
        
        # Get the properties of latest video recording
        Write-Output "Entering GetVideoDetails function"
        GetVideoDetails $scenarioLogFolder $pathLogsFolder
        
        # Collect data for Reporting
        Reporting $Results "$pathLogsFolder\Report.txt"
    }
    catch
    {   
       Error-Exception -snarioName $scenarioLogFolder -strttme $startTime -rslts $Results -logFile $logFile -token $token -SPID $SPID
    }
}
<#
DESCRIPTION:
    The `Test-WSE+CoCreator` function automates the same process as `WSE+Recall` but adds an additional step to 
    generate an image using the Co-Creator feature during the video recording process. It toggles AI effects,
    sets up camera configurations, records video, enables Recall, and verifies logs.

PARAMETERS:
    - $devPowStat [string]: The device's power state (e.g., "PluggedIn", "OnBattery").
    - $token [string]: Authentication token for security.
    - $SPId [string]: Smart plug ID.
    
RETURNS:
    void: This function does not return a value. It performs the operations and logs the results.
#>
function Test-WSE+CoCreator($devPowStat, $token, $SPId) 
{   
    $startTime = Get-Date    
    $ErrorActionPreference='Stop'
    $scenarioName = "$devPowStat\WSE+CoCreator"
    $logFile = "$devPowStat-WSE+CoCreator.txt"
        
    try
	{  
       # Create Scenario folder
       $scenarioLogFolder = $scenarioName
       CreateScenarioLogsFolder $scenarioLogFolder

       # Toggling All effects on
       Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On" -IsOutput
       ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                     -ECVal "On" -ECSVal "True" -ECTVal "False" -VFVal "On" `
                                     -CF "On" -CFI "False" -CFA "False" -CFW "True"
                 
        # Open Camera App and set default setting to "Use system settings" 
        Set-SystemSettingsInCamera       
        # Set photo resolution
	    $photoResName = SetHighestPhotoResolutionInCameraApp 
        $phoResNme = RetrieveValue $photoResName[-1]
        
        # Set video resolution
        $videoResName = SetHighestVideoResolutionInCameraApp
        $vdoResNme = RetrieveValue $videoResName[-1]
        
        $scenarioLogFolder = "$scenarioName\$phoResNme\$vdoResNme" 

        CreateScenarioLogsFolder $scenarioLogFolder
           
        $devState = CheckDevicePowerState $devPowStat $token $SPId
        if($devState -eq $false)
        {   
           TestOutputMessage $scenarioLogFolder "Skipped" $startTime "Token is empty"  
           return
        }

        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server'
                      
        # Strating to collect Traces
        Write-Log -Message "Entering StartTrace function" -IsOutput
        StartTrace $scenarioLogFolder
        
        # Open Task Manager
        Write-Log -Message "Opening Task Manager" -IsOutput
        $uitaskmgr = OpenApp 'Taskmgr' 'Task Manager'
        Start-Sleep -s 1
    
                             
        # Start video recording and close the camera app once finished recording 
        Write-Log -Message "Open camera App" -IsOutput
        $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
        Start-Sleep -s 1
                                                                  
        # Switch to video mode if not in video mode
        SwitchModeInCameraApp $ui "Switch to video mode" "Take video" 
        Start-Sleep -s 2
        
        # Record video inbetween space presses
        Write-Log -Message "Start recording a video for $scnds seconds" -IsOutput
        [System.Windows.Forms.SendKeys]::SendWait(' ');

        # Open paint and start generating image with CoCreator
        Co-Creator -file "dolphins.png" -scenario $scenarioLogFolder
        Start-Sleep -s 2
                        
        # Close Camera App
        CloseApp 'WindowsCamera'
        
        # Capture CPU and NPU Usage
        Write-Log -Message "Entering CPUandNPU-Usage function to capture CPU and NPU usage Screenshot" -IsOutput
        stopTaskManager -uitaskmgr $uitaskmgr -Scenario $scenarioLogFolder
        
        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server' 
        
        # Stop the Trace
        Write-Log -Message "Entering StopTrace function" -IsOutput
        StopTrace $scenarioLogFolder
                                         
        # Verify and validate if proper logs are generated or not.   
        $wsev2PolicyState = CheckWSEV2Policy
        
        # Set the ScenarioID based on the policy state
        if ($wsev2PolicyState -eq $false) {
            $scenarioID = "81968"  # Based on v1 effects
        } else {
            $scenarioID = "2703376"  # Based on v1+v2 effects, verify if this is correct
        }
        
        # Log the entry to Verifylogs function
        Write-Log -Message "Entering Verifylogs function with ScenarioID $scenarioID" -IsOutput
        
        # Call Verifylogs function
        Verifylogs $scenarioLogFolder $scenarioID $startTime

        # Get the properties of latest video recording
        Write-Log -Message "Entering GetVideoDetails function" -IsOutput
        GetVideoDetails $scenarioLogFolder $pathLogsFolder
        
        # Collect data for Reporting
        Reporting $Results "$pathLogsFolder\Report.txt"
    }
    catch
    {   
       Error-Exception -snarioName $scenarioLogFolder -strttme $startTime -rslts $Results -logFile $logFile -token $token -SPID $SPID
    }
}


