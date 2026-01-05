Add-Type -AssemblyName UIAutomationClient

<#
DESCRIPTION:
    This function tests the behavior of the Windows Settings App during multiple hibernation cycles.
    It toggles AI effects, navigates to the camera effects settings page, initiates hibernation cycles, 
    and validates if logs are correctly generated while monitoring system performance.
INPUT PARAMETERS:
    - devPowStat [string] :- The power state of the device (e.g., "PluggedIn", "OnBattery").
    - token [string] :- Authentication token required to control the smart plug.
    - SPId [string] :- Smart plug ID used to control device power states.
RETURN TYPE:
    - void 
#>
function SettingApp-Hibernation($devPowStat, $token, $SPId)
{
    $startTime = Get-Date 
    $ErrorActionPreference='Stop'
    $scenarioName = "$devPowStat\SettingAppHibernation"
    $logFile = "$devPowStat-SettingAppHibernation.txt"
    
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
                          
        # Toggling All effects on
        Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On" -IsOutput
        ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                     -ECVal "On" -ECSVal "True" -ECTVal "False" -VFVal "On" `
                                     -CF "On" -CFI "False" -CFA "False" -CFW "True"
                
        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server'
                      
        # Starting to collect Traces
        Write-Log -Message "Entering StartTrace function" -IsOutput
        StartTrace $scenarioName

        # Open settings app and obtain UI automation from it
        $ui = OpenApp 'ms-settings:' 'Settings'
        Start-Sleep -m 500
        
        # Open camera effects page and turn all effects off
        Write-Log -Message "Navigate to camera effects setting page" -IsOutput
        FindCameraEffectsPage $ui
        Start-Sleep -s 10

        # Entering while loop
        $i = 1
        While($i -lt 4)
        {  
           # Entering Hibernation function    
           Hibernation 
           Write-Log -Message "End of $i hibernation" -IsOutput
           $i++
        } 

        # Close settings app
        CloseApp 'systemsettings'
        
       # Verify logs and capture results.
       Complete-TestRun $scenarioName $startTime $token $SPId
               
       #Verify logs for number of hibernation cycles
       VerifyLogs-Hibernation $scenarioName
       
    }
    catch
    {   
       Error-Exception -snarioName $scenarioName -strttme $startTime -rslts $Results -logFile $logFile -token $token -SPID $SPID
    }
}
