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
        Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On" -IsOutput
        ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                     -ECVal "On" -ECSVal "False" -ECTVal "True" -VFVal "On" `
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
        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server'
                      
        # Starting to collect Traces
        Write-Log -Message "Entering StartTrace function" -IsOutput
        StartTrace $scenarioLogFolder
        
        # Start Recording, start capturing resource utilization and close the camera app once finished recording. Each duration is for around 10 secs
        Write-Log -Message "Entering StartVideoRecording function" -IsOutput
        $InitTimeCameraApp = StartVideoRecording -duration 6 -snarioName $scenarioLogFolder -logPath "$scenarioLogFolder\Camerae2eTestResourceUtilization.txt"
        $cameraAppStartTime = $InitTimeCameraApp[-1]
        Write-Log -Message "Camera App start time in UTC: ${cameraAppStartTime}" -IsOutput

        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server' 
        
        # Stop the Trace
        Write-Log -Message "Entering StopTrace function" -IsOutput
        StopTrace $scenarioLogFolder
                                         
        # Verify and validate if proper logs are generated or not.   
        $wsev2PolicyState = CheckWSEV2Policy
        if($wsev2PolicyState -eq $false)
        {  
           # ScenarioID 81968 is based on v1 effects.
           Write-Log -Message "Entering Verifylogs function" -IsOutput
           Verifylogs $scenarioLogFolder "81968" $startTime 
           
           # Calculate Time from camera app started until PC trace first frame processed
           Write-Log -Message "Entering CheckInitTimeCameraApp function" -IsOutput
           CheckInitTimeCameraApp $scenarioLogFolder "81968" $cameraAppStartTime
        }
        else
        {
           # ScenarioID is based on v1+v2 effects.
           Write-Log -Message "Entering Verifylogs function" -IsOutput
           Verifylogs $scenarioLogFolder "2834432" $startTime #(Need to change the scenario ID, not sure if this is correct)
        
           # Calculate Time from camera app started until PC trace first frame processed
           Write-Log -Message "Entering CheckInitTimeCameraApp function" -IsOutput
           CheckInitTimeCameraApp $scenarioLogFolder "2834432" $cameraAppStartTime #(Need to change the scenario ID, not sure if this is correct)
        }
        
        # Get the properties of latest video recording
        Write-Log -Message "Entering GetVideoDetails function" -IsOutput
        GetVideoDetails $scenarioLogFolder $pathLogsFolder
        
        # Collect data for Reporting
        Reporting $Results "$pathLogsFolder\Report.txt"
                     
   
        # Restore the default state for AI effects
        Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to Restore the default state for AI effects" -IsOutput
        ToggleAIEffectsInSettingsApp -AFVal "Off" -PLVal "Off" -BBVal "Off" -BSVal "False" -BPVal "False" `
                                     -ECVal "Off" -ECSVal "False" -ECTVal "False" -VFVal "Off" `
                                     -CF "Off" -CFI "False" -CFA "False" -CFW "False"
             
    }
    catch
    {   
       Error-Exception -snarioName $scenarioLogFolder -strttme $startTime -rslts $Results -logFile $logFile -token $token -SPID $SPID
    }
}