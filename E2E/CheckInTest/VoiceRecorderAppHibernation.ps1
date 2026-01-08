Add-Type -AssemblyName UIAutomationClient

<#
DESCRIPTION:
    This function tests the behavior of the Voice Recorder App during multiple hibernation cycles.
    It toggles the Voice Focus effect, records audio, puts the device into hibernation, and 
    verifies that proper logs are generated while monitoring system performance.
INPUT PARAMETERS:
    - devPowStat [string] :- The power state of the device (e.g., "PluggedIn", "OnBattery").
    - token [string] :- Authentication token required to control the smart plug.
    - SPId [string] :- Smart plug ID used to control device power states.
RETURN TYPE:
    - void
#>
function VoiceRecorderApp-Hibernation($devPowStat, $token, $SPId)
{
    $startTime = Get-Date 
    $ErrorActionPreference='Stop'
    $scenarioName = "$devPowStat\VoiceRecorderAppHibernation"
    $logFile = "$devPowStat-VoiceRecorderAppHibernation.txt"

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

    try
	{  
        #Create scenario specific folder for collecting logs
        Write-Log -Message "Creating folder for capturing logs" -IsOutput
        CreateScenarioLogsFolder $scenarioName
        
        # Toggling Voice Focus effect on
        Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to toggle Voice Focus effect on" -IsOutput
        ToggleAIEffectsInSettingsApp -AFVal "Off" -AFSVal "False" -AFCVal "False" -PLVal "Off" -BBVal "Off" -BSVal "False" -BPVal "False" `
                                     -ECVal "Off" -ECSVal "False" -ECTVAL "False" -VFVal "On" `
                                     -CF "Off" -CFI "False" -CFA "False" -CFW "False"
                
        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server'
                                         
        # Starting to collect Traces
        Write-Log -Message "Entering StartTrace function" -IsOutput
        StartTrace $scenarioName
                    
        $i = 1
        While($i -lt 4)
        {  

           # Start audio recording and close the sound recorder app once finished recording 
           Write-Log -Message "Entering AudioRecording function" -IsOutput
           $InitTimeVoiceRecorderApp = AudioRecording -duration 1 -snarioName $scenarioName -logPath "$scenarioName\ResourceUtilization.txt"
           $voiceRecorderAppStartTime = [System.DateTime]$($InitTimeVoiceRecorderApp[-2])
           $audioRecordingStartTime = $InitTimeVoiceRecorderApp[-1]
           Write-Log -Message "Voice Recorder App start time in UTC: ${voiceRecorderAppStartTime}" -IsOutput
           Write-Log -Message "Audio recording start time in UTC: ${audioRecordingStartTime}" -IsOutput
           
           # Entering Hibernation function    
           Hibernation 
           Write-Log -Message "End of $i hibernation" -IsHost
           $i++
        
        } 
        # Stop the Trace
        Write-Log -Message "Entering StopTrace function" -IsOutput
        StopTrace $scenarioName
              
        # Verify and validate if proper logs are generated or not.  
        Write-Log -Message "Entering Verifylogs function" -IsOutput
        Verifylogs $scenarioName "512" $startTime

        # Verify logs for number of hibernation cycles
        VerifyLogs-Hibernation $scenarioName
        
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
