Add-Type -AssemblyName UIAutomationClient

function VoiceFocus-Playlist($devPowStat, $token, $SPId) 
{   
    $startTime = Get-Date    
    $ErrorActionPreference='Stop'
    $scenarioName = "$devPowStat\VoiceFocus"
    $logFile = "$devPowStat-VoiceFocus.txt"
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
	{   #Create scenario specific folder for collecting logs
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
                
        #Start collecting Traces before opening setting page
        Write-Output "Entering StartTrace function"
        StartTrace $scenarioName

        #Open setting page
        Write-Output "Open Setting Page"
        $ui = OpenApp 'ms-settings:' 'Settings'
        Start-Sleep -m 500

        #Open Audio system setting page
        Write-Output "Entering FindVoiceFocusPage function"
        FindVoiceFocusPage $ui
        Start-Sleep -s 5
        
        #Close system setting page and stop collecting Trace
        CloseApp 'systemsettings'
                     
        #Stop collecting trace
        Write-Output "Entering StopTrace function"
        StopTrace $scenarioName
        
        #Verify and validate if proper logs are generated or not.
        Write-Output "Entering Verifylogs function"
        Verifylogs $scenarioName "512" $startTime

        #collect data for Reporting
        Reporting $Results "$pathLogsFolder\Report.txt"
        
        #For our Sanity, we make sure that we exit the test in netural state,which is pluggedin
        SetSmartPlugState $token $SPId 1 
    }
    catch
    {
       Error-Exception -snarioName $scenarioName -strttme $startTime -rslts $Results -logFile $logFile -token $token -SPID $SPID
    }

}
