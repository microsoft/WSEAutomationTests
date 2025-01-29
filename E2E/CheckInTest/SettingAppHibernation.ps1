Add-Type -AssemblyName UIAutomationClient

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
        Write-Output "Creating folder for capturing logs"
        CreateScenarioLogsFolder $scenarioName
                          
        #Toggling All effects on
        Write-Output "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On"
        ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                                 -ECVal "On" -ECSVal "False" -ECEVal "True" -VFVal "On" `
                                                 -CF "On" -CFI "False" -CFA "False" -CFW "True"
                
        #Checks if frame server is stopped
        Write-Output "Entering CheckServiceState function"
        CheckServiceState 'Windows Camera Frame Server'
                      
        #Strating to collect Traces
        Write-Output "Entering StartTrace function"
        StartTrace $scenarioName

        #open settings app and obtain ui automation from it
        $ui = OpenApp 'ms-settings:' 'Settings'
        Start-Sleep -m 500
        
        #open camera effects page and turn all effects off
        Write-Output "Navigate to camera effects setting page"
        FindCameraEffectsPage $ui
        Start-Sleep -s 10

        #Entering while loop
        $i = 1
        While($i -lt 4)
        {  
           #Entering Hibernation function    
           Hibernation 
           Write-host "End of $i hibernation"
           $i++
        } 

        #close settings app
        CloseApp 'systemsettings'

        #Checks if frame server is stopped
        Write-Output "Entering CheckServiceState function"
        CheckServiceState 'Windows Camera Frame Server'

        #Stop the Trace
        Write-Output "Entering StopTrace function"
        StopTrace $scenarioName
                                              
        $wsev2PolicyState = CheckWSEV2Policy
        if($wsev2PolicyState -eq $false)
        {  
           #ScenarioID 81968 is based on v1 effects.   
           Write-Output "Entering Verifylogs function"
           Verifylogs $scenarioName "81968" $startTime
        }
        else
        { 
           #ScenarioID 737312 is based on v1+v2 effects.   
           Write-Output "Entering Verifylogs function"
           Verifylogs $scenarioName "2834432" $startTime #(Need to change the scenario ID, not sure if this is correct)
        }


        #Verify logs for number of hiberantion cycle
        VerifyLogs-Hibernation $scenarioName

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
