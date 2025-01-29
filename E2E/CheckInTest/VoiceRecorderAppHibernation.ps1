Add-Type -AssemblyName UIAutomationClient

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
        Write-Output "Creating folder for capturing logs"
        CreateScenarioLogsFolder $scenarioName
        
        #Toggling Voice Focus effect on
        Write-Output "Entering ToggleAIEffectsInSettingsApp function to toggle Voice Focus effect on"
        ToggleAIEffectsInSettingsApp -AFVal "Off" -PLVal "Off" -BBVal "Off" -BSVal "False" -BPVal "False" `
                                     -ECVal "Off" -ECSVal "False" -ECEVal "False" -VFVal "On" `
                                     -CF "Off" -CFI "False" -CFA "False" -CFW "False"
                
        #Checks if frame server is stopped
        Write-Output "Entering CheckServiceState function" 
        CheckServiceState 'Windows Camera Frame Server'
                                         
        #Strating to collect Traces
        Write-Output "Entering StartTrace function"
        StartTrace $scenarioName
                    
        $i = 1
        While($i -lt 4)
        {  

           #Start audio recording and close the sound recorder app once finished recording 
           Write-Output "Entering AudioRecording function"
           $InitTimeVoiceRecorderApp = AudioRecording "10" 
           $voiceRecorderAppStartTime = [System.DateTime]$($InitTimeVoiceRecorderApp[-2])
           $audioRecordingStartTime = $InitTimeVoiceRecorderApp[-1]
           Write-Output "Voice Recorder App start time in UTC: ${voiceRecorderAppStartTime}"  
           Write-Output "Audio recording start time in UTC: ${audioRecordingStartTime}" 
           
           #Entering Hibernation function    
           Hibernation 
           Write-host "End of $i hibernation"
           $i++
        
        } 
        #Stop the Trace
        Write-Output "Entering StopTrace function"
        StopTrace $scenarioName
              
        #Verify and validate if proper logs are generated or not.  
        Write-Output "Entering Verifylogs function"      
        Verifylogs $scenarioName "512" $startTime

        #Verify logs for number of hiberantion cycle
        VerifyLogs-Hibernation $scenarioName
        
        #calculate Time from audio recording started until PC trace first frame processed
        Write-Output "Entering CheckInitTimeVoiceRecorderApp function" 
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

