Add-Type -AssemblyName UIAutomationClient

<#
DESCRIPTION:
    This function performs an end-to-end test on the Camera App. It sets up AI effects, configures
    the highest available photo and video resolutions, records a video, monitors system resource usage,
    and verifies logs to validate the correctness of the recording process.

INPUT PARAMETERS:
    - devPowStat [string] :- The power state of the device (e.g., "PluggedIn", "OnBattery").
    - token [string] :- Authentication token required to control the smart plug.
    - SPId [string] :- Smart plug ID used to control device power states.

RETURN TYPE:
    - void
#>
function Camera-App-Playlist($devPowStat, $token, $SPId) 
{   
    $startTime = Get-Date    
    $ErrorActionPreference='Stop'
    $scenarioName = "$devPowStat\Camerae2eTest"
    $logFile = "$devPowStat-Camerae2eTest.txt"
        
    try
	{  
        #Create Scenario folder
        $scenarioLogFolder = $scenarioName
        CreateScenarioLogsFolder $scenarioLogFolder
     
        #Toggling All effects on
        Write-Output "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On"
        ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                     -ECVal "On" -ECSVal "False" -ECEVal "True" -VFVal "On" `
                                     -CF "On" -CFI "False" -CFA "False" -CFW "True"
                 
        #Open Camera App and set default setting to "Use system settings" 
        Set-SystemSettingsInCamera
       
        #Set photo resolution
	     $photoResName = SetHighestPhotoResolutionInCameraApp 
        $phoResNme = RetrieveValue $photoResName[-1]
        
        #Set video resolution
        $videoResName = SetHighestVideoResolutionInCameraApp
        $vdoResNme = RetrieveValue $videoResName[-1]
        
        $scenarioLogFolder = "$scenarioName\$phoResNme\$vdoResNme" 

        CreateScenarioLogsFolder $scenarioLogFolder
        
        $powerMode = $devPowStat -replace '^\d+-', ''
        $devState = CheckDevicePowerState $powerMode $token $SPId
        if($devState -eq $false)
        {   
           TestOutputMessage $scenarioLogFolder "Skipped" $startTime "Token is empty"  
           return
        }
        #Checks if frame server is stopped
        Write-Output "Entering CheckServiceState function"
        CheckServiceState 'Windows Camera Frame Server'
                      
        #Strating to collect Traces
        Write-Output "Entering StartTrace function"
        StartTrace $scenarioLogFolder

        #Open Task Manager
        Write-output "Opening Task Manager"
        $uitaskmgr = OpenApp 'Taskmgr' 'Task Manager'
        Start-Sleep -s 1
        setTMUpdateSpeedLow -uiEle $uitaskmgr
                             
        #Start video recording and close the camera app once finished recording 
        Write-Output "Entering StartVideoRecording function"
        $InitTimeCameraApp = StartVideoRecording "60"
        $cameraAppStartTime = $InitTimeCameraApp[-1]
        Write-Output "Camera App start time in UTC: ${cameraAppStartTime}"

        #Capture CPU and NPU Usage
        Write-output "Entering CPUandNPU-Usage function to capture CPU and NPU usage Screenshot"  
        stopTaskManager -uitaskmgr $uitaskmgr -Scenario $scenarioLogFolder
        
        #Checks if frame server is stopped
        Write-Output "Entering CheckServiceState function"
        CheckServiceState 'Windows Camera Frame Server' 
        
        #Stop the Trace
        Write-Output "Entering StopTrace function"
        StopTrace $scenarioLogFolder
                                         
        #Verify and validate if proper logs are generated or not.   
        $wsev2PolicyState = CheckWSEV2Policy
        if($wsev2PolicyState -eq $false)
        {  
           #ScenarioID 81968 is based on v1 effects.
           Write-Output "Entering Verifylogs function"   
           Verifylogs $scenarioLogFolder "81968" $startTime 
           
           #calculate Time from camera app started until PC trace first frame processed
           Write-Output "Entering CheckInitTimeCameraApp function" 
           CheckInitTimeCameraApp $scenarioLogFolder "81968" $cameraAppStartTime
        }
        else
        {
           #ScenarioID  is based on v1+v2 effects.
           Write-Output "Entering Verifylogs function"  
           Verifylogs $scenarioLogFolder "2834432" $startTime #(Need to change the scenario ID, not sure if this is correct)
        
           #calculate Time from camera app started until PC trace first frame processed
           Write-Output "Entering CheckInitTimeCameraApp function" 
           CheckInitTimeCameraApp $scenarioLogFolder "2834432" $cameraAppStartTime #(Need to change the scenario ID, not sure if this is correct)
        }
        
        #Get the properties of latest video recording
        Write-Output "Entering GetVideoDetails function"
        GetVideoDetails $scenarioLogFolder $pathLogsFolder
        
        #collect data for Reporting
        Reporting $Results "$pathLogsFolder\Report.txt"
                     
   
        #Restore the default state for AI effects
        Write-Output "Entering ToggleAIEffectsInSettingsApp function to Restore the default state for AI effects"
        ToggleAIEffectsInSettingsApp -AFVal "Off" -PLVal "Off" -BBVal "Off" -BSVal "False" -BPVal "False" `
                                     -ECVal "Off" -ECSVal "False" -ECEVal "False" -VFVal "Off" `
                                     -CF "Off" -CFI "False" -CFA "False" -CFW "False"
             
    }
    catch
    {   
       Error-Exception -snarioName $scenarioLogFolder -strttme $startTime -rslts $Results -logFile $logFile -token $token -SPID $SPID
    }
}

