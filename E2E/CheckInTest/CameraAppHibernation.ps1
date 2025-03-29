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
        
        # Set up camera effects/settings and start collecting trace
        Get-InitialSetUp $scenarioName 
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
