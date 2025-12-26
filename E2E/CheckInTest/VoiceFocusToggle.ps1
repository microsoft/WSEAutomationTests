Add-Type -AssemblyName UIAutomationClient

<#
DESCRIPTION:
    This function tests the Voice Focus feature in the Windows Settings app. 
    It toggles the Voice Focus AI effect, collects system traces, and verifies 
    if proper logs are generated to ensure the feature is functioning as expected.
INPUT PARAMETERS:
    - devPowStat [string] :- The power state of the device (e.g., "PluggedIn", "OnBattery").
    - token [string] :- Authentication token required to control the smart plug.
    - SPId [string] :- Smart plug ID used to control device power states.
RETURN TYPE:
    - void
#>
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
        Write-Log -Message "Creating folder for capturing logs" -IsOutput
        CreateScenarioLogsFolder $scenarioName
        
        # Toggling Voice Focus effect on
        Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to toggle Voice Focus effect on" -IsOutput
        ToggleAIEffectsInSettingsApp -AFVal "Off" -PLVal "Off" -BBVal "Off" -BSVal "False" -BPVal "False" `
                                     -ECVal "Off" -ECSVal "False" -ECTVal "False" -VFVal "On" `
                                     -CF "Off" -CFI "False" -CFA "False" -CFW "False"
                       
        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server'    
                
        # Start collecting Traces before opening setting page
        Write-Log -Message "Entering StartTrace function" -IsOutput
        StartTrace $scenarioName

        # Open setting page
        Write-Log -Message "Open Setting Page" -IsOutput
        $ui = OpenApp 'ms-settings:' 'Settings'
        Start-Sleep -m 500

        # Open Audio system setting page
        Write-Log -Message "Entering FindVoiceFocusPage function" -IsOutput
        FindVoiceFocusPage $ui
        Start-Sleep -s 5
        
        # Close system setting page and stop collecting Trace
        CloseApp 'systemsettings'
                     
        # Stop collecting trace
        Write-Log -Message "Entering StopTrace function" -IsOutput
        StopTrace $scenarioName
        
        # Verify and validate if proper logs are generated or not.
        Write-Log -Message "Entering Verifylogs function" -IsOutput
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
