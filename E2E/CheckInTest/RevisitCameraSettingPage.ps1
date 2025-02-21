Add-Type -AssemblyName UIAutomationClient

<#
DESCRIPTION:
    This function navigates back and forth between camera settings pages in the Windows Settings app 
    multiple times to validate UI behavior and responsiveness.

INPUT PARAMETERS:
    - times [int] :- Number of times the function will navigate back and forth in the camera settings.

RETURN TYPE:
    - void 
#>
function RevisitCameraSetting($times)
{  

   #close settings app
   CloseApp 'systemsettings'
   Start-Sleep -m 500

   #open settings app and obtain ui automation from it
   $ui = OpenApp 'ms-settings:' 'Settings'
   Start-Sleep -m 500
   
   #open camera effects page and turn all effects off
   Write-Output "Navigate to camera effects setting page"
   FindCameraEffectsPage $ui
   Start-Sleep -s 2

   $i = 0
   while($i -le $times)
   {
      FindAndClick $ui Button Back
      Start-Sleep -s 2
      $exists = CheckIfElementExists $ui Button More
      if ($exists)
      {
          ClickFrontCamera $ui Button More
      }
      else
      {
          FindAndClick $ui Button "Connected enabled camera $Global:validatedCameraFriendlyName"
      }  
       Start-Sleep -s 2
       $i++
   }

   Write-Output "Completed back and forth camera setting page $times times"
   #close settings app
   CloseApp 'systemsettings'
}


<#
DESCRIPTION:
    This function performs stress testing on the camera settings page by revisiting it multiple times, 
    toggling AI effects on/off, and collecting memory usage data.

INPUT PARAMETERS:
    - devPowStat [string] :- The power state of the device (e.g., "PluggedIn", "OnBattery").
    - token [string] :- Authentication token required to control the smart plug.
    - SPId [string] :- Smart plug ID used to control device power states.

RETURN TYPE:
    - void 
#>
function RevisitCameraSettingPage($devPowStat, $token, $SPId)
{
    $startTime = Get-Date 
    $ErrorActionPreference='Stop'
    $scenarioName = "$devPowStat\RevisitCameraSettingPage"
    $logFile = "$devPowStat-RevisitCameraSettingPage.txt"
    
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

        #Strating to collect Traces for generic error
        Write-Output "Entering StartTrace"
        StartTrace $scenarioName
                          
        #Toggling All effects on
        Write-Output "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On"
        ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                     -ECVal "On" -ECSVal "False" -ECEVal "True" -VFVal "On" `
                                     -CF "On" -CFI "False" -CFA "False" -CFW "True"

        Start-Sleep -s 2

        Write-Output "Enter RevisitCameraSetting function"
        RevisitCameraSetting "30"

        #Change AI toggle in setting page
        ToggleAIEffectsInSettingsApp -AFVal "Off" -PLVal "Off" -BBVal "Off" -BSVal "False" -BPVal "False" `
                                     -ECVal "Off" -ECSVal "False" -ECEVal "False" -VFVal "Off" `
                                     -CF "Off" -CFI "False" -CFA "False" -CFW "False"
        Start-Sleep -s 2
        
        Write-Output "Enter RevisitCameraSetting function"
        RevisitCameraSetting "30"

        #Change AI toggle in setting page
        ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                                 -ECVal "On" -ECSVal "False" -ECEVal "True" -VFVal "On" `
                                                 -CF "On" -CFI "False" -CFA "False" -CFW "True"
        Start-Sleep -s 2

        Write-Output "Enter RevisitCameraSetting function"
        RevisitCameraSetting "30"

        #close settings app
        CloseApp 'systemsettings'

        #Checks if frame server is stopped
        Write-Output "Entering CheckServiceState function"
        CheckServiceState 'Windows Camera Frame Server'

        #Stop the Trace for generic error
        Write-Output "Entering StopTrace function"
        StopTrace $scenarioName

        #check for generic error
        GenericError $scenarioName

        #Check if AvgMemoryUsage is greater than 250MB
        CheckMemoryUsage $scenarioName
        
        #Create scenario specific folder for collecting logs
        Write-Output "Creating folder for capturing logs"
        $scenarioName = "$devPowStat\RevisitCameraSettingPage-ValidateScenarioID"
        CreateScenarioLogsFolder $scenarioName
                      
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

        #close settings app
        CloseApp 'systemsettings'

        #Checks if frame server is stopped
        Write-Output "Entering CheckServiceState function"
        CheckServiceState 'Windows Camera Frame Server'

        #Stop the Trace
        Write-Output "Entering StopTrace function"
        StopTrace $scenarioName
                                              
        #Verify and validate if proper logs are generated or not.   
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


