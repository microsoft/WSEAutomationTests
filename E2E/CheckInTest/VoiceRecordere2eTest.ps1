Add-Type -AssemblyName UIAutomationClient

<#
DESCRIPTION:
    This function tests the Voice Recorder App with the Voice Focus effect enabled.
    It starts an audio recording, verifies if logs are generated correctly, checks
    system traces, and measures the initialization time of the Voice Recorder App.
INPUT PARAMETERS:
    - devPowStat [string] :- The power state of the device (e.g., "PluggedIn", "OnBattery").
    - token [string] :- Authentication token required to control the smart plug.
    - SPId [string] :- Smart plug ID used to control device power states.
RETURN TYPE:
    - void 
#>
function Voice-Recorder-Playlist($devPowStat, $token, $SPId) 
{   
    $startTime = Get-Date    
    $ErrorActionPreference='Stop'
    $scenarioName = "$devPowStat\VoiceRecordere2eTest"
    $logFile = "$devPowStat-VoiceRecordere2eTest.txt"
    $voiceFocusExists = CheckVoiceFocusPolicy 
    if($voiceFocusExists -eq $false)
    {
        TestOutputMessage $scenarioName "Skipped" $startTime  "Voice Focus Not Supported" 
        return
    }
    $devState = CheckDevicePowerState $devPowStat $token $SPId
    if($devState -eq $false)
    {   
       TestOutputMessage $scenarioName "Skipped" $startTime "Token is empty"  
       return
    }

    $voiceFocusExists = CheckVoiceFocusPolicy 
    if($voiceFocusExists -eq $false)
    {
        TestOutputMessage $scenarioName "Skipped" $startTime  "Voice Focus Not Supported" 
        return
    }
    try
	{  
        #Create scenario specific folder for collecting logs
        Write-Log -Message "Creating folder for capturing logs" -IsOutput
        CreateScenarioLogsFolder $scenarioName
        
        # Toggling Voice Focus effect on
        Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to toggle Voice Focus effect on" -IsOutput
        ToggleAIEffectsInSettingsApp -AFVal "Off" -AFSVal "False" -AFCVal "False"-PLVal "Off" -BBVal "Off" -BSVal "False" -BPVal "False" `
                                     -ECVal "Off" -ECSVal "False" -ECTVal "False" -VFVal "On" `
                                     -CF "Off" -CFI "False" -CFA "False" -CFW "False"
         
        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server'
                                         
        # Starting to collect Traces
        Write-Log -Message "Entering StartTrace function" -IsOutput
        StartTrace $scenarioName
        
        # Start audio recording and capture resource utilization. Each duration runs for around 10 secs. Close the sound recorder app once finished recording 
        Write-Log -Message "Entering AudioRecording function" -IsOutput
        $InitTimeVoiceRecorderApp = AudioRecording -duration 1 -snarioName $scenarioName -logPath "$scenarioName\ResourceUtilization.txt"
        $voiceRecorderAppStartTime = [System.DateTime]$($InitTimeVoiceRecorderApp[-2])
        $audioRecordingStartTime = $InitTimeVoiceRecorderApp[-1]
        Write-Log -Message "Voice Recorder App start time in UTC: ${voiceRecorderAppStartTime}" -IsOutput
        Write-Log -Message "Audio recording start time in UTC: ${audioRecordingStartTime}" -IsOutput
        
        # Stop the Trace
        Write-Log -Message "Entering StopTrace function" -IsOutput
        StopTrace $scenarioName
              
        # Verify and validate if proper logs are generated or not.  
        Write-Log -Message "Entering Verifylogs function" -IsOutput
        Verifylogs $scenarioName "512" $startTime
        
        # Calculate Time from audio recording started until PC trace first frame processed
        Write-Log -Message "Entering CheckInitTimeVoiceRecorderApp function" -IsOutput
        CheckInitTimeVoiceRecorderApp $scenarioName "512" $voiceRecorderAppStartTime $audioRecordingStartTime

        #collect data for Reporting
        Reporting $Results "$pathLogsFolder\Report.txt"
        
        #For our Sanity, we make sure that we exit the test in netural state,which is pluggedin
        SetSmartPlugState $token $SPId 1         
    }
    catch
    {
       Error-Exception -snarioName $scenarioName -strttme $startTime -rslts $Results -logFile $logFile -token $token -SPID $SPID
       CloseApp 'VoiceRecorder'
    }
}
