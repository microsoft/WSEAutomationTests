Add-Type -AssemblyName UIAutomationClient

<#
DESCRIPTION:
    This function simulates a test scenario where the Camera App is opened, switched to video mode, 
    and the system undergoes multiple hibernation cycles. It verifies whether logs are generated correctly, 
    checks service states, starts and stops traces, and ensures AI effect settings return to default.
INPUT PARAMETERS:
    - devPowStat [string] :- Specifies the device power state (e.g., "PluggedIn", "OnBattery").
    - token [string] :- Authentication token required to control the smart plug.
    - SPId [string] :- Smart plug ID used to control device power states.
RETURN TYPE:
    - void 
#>
function CameraApp-Hibernation($devPowStat, $token, $SPId)
{
    $startTime = Get-Date 
    $ErrorActionPreference='Stop'
    $scenarioName = "$devPowStat\CameraAppHibernation"
    $logFile = "$devPowStat-CameraAppHibernation.txt"
    
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
        
        # Open Camera App and set default setting to "Use system settings" 
        Set-SystemSettingsInCamera
        
        #Toggling All effects on
        Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On" -IsOutput
        ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                     -ECVal "On" -ECSVal "False" -ECEVal "True" -VFVal "On" `
                                     -CF "On" -CFI "False" -CFA "False" -CFW "True"
                
        #Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server'
                      
        #Starting to collect Traces
        Write-Log -Message "Entering StartTrace function" -IsOutput
        StartTrace $scenarioName

        #Open Camera App
        $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
        
        #Switch to video mode as photo mode doesn't support MEP
        SwitchModeInCameraApp $ui "Switch to video mode" "Take video"  
        start-sleep -s 20
        
        #Entering while loop
        $i = 1
        While($i -lt 4)
        {  
           #Entering Hibernation function
           Hibernation 
           Write-Log -Message "End of $i hibernation" -IsHost
           $i++
        } 

        CloseApp 'WindowsCamera'

        #Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server'

        #Stop the Trace
        Write-Log -Message "Entering StopTrace function" -IsOutput
        StopTrace $scenarioName

        #Restore the default state for AI effects
        Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to Restore the default state for AI effects" -IsOutput
        ToggleAIEffectsInSettingsApp -AFVal "Off" -PLVal "Off" -BBVal "Off" -BSVal "False" -BPVal "False" `
                                     -ECVal "Off" -ECSVal "False" -ECEVal "False" -VFVal "Off" `
                                     -CF "Off" -CFI "False" -CFA "False" -CFW "False"
                                                 
        #Verify and validate if proper logs are generated or not.   
        $wsev2PolicyState = CheckWSEV2Policy
        if($wsev2PolicyState -eq $false)
        {  
           #ScenarioID 81968 is based on v1 effects.   
           Write-Log -Message "Entering Verifylogs function" -IsOutput
           Verifylogs $scenarioName "81968" $startTime
        }
        else
        { 
           #ScenarioID 737312 is based on v1+v2 effects.  
           Write-Log -Message "Entering Verifylogs function" -IsOutput
           Verifylogs $scenarioName "2834432" $startTime #(Need to change the scenario ID, not sure if this is correct)
        }

        #Verify logs for number of hibernation cycles
        VerifyLogs-Hibernation $scenarioName
        
        #Collect data for Reporting
        Reporting $Results "$pathLogsFolder\Report.txt"

        #For our Sanity, we make sure that we exit the test in neutral state, which is plugged in
        SetSmartPlugState $token $SPId 1
       
    }
    catch
    {   
       Error-Exception -snarioName $scenarioName -strttme $startTime -rslts $Results -logFile $logFile -token $token -SPID $SPID
    }
}
