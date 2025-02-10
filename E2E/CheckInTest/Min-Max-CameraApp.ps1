Add-Type -AssemblyName UIAutomationClient

<#
DESCRIPTION:
    This function tests the Camera App by repeatedly minimizing and maximizing it 50 times 
    while toggling AI effects and collecting traces. It verifies if memory usage exceeds 
    a certain threshold and checks for any generic errors in the logs.

INPUT PARAMETERS:
    - devPowStat [string] :- The power state of the device (e.g., "PluggedIn", "OnBattery").
    - token [string] :- Authentication token required to control the smart plug.
    - SPId [string] :- Smart plug ID used to control device power states.

RETURN TYPE:
    - void (Logs outputs and results to files without returning a value.)
#>
function Min-Max-CameraApp($devPowStat, $token, $SPId)
{
    $startTime = Get-Date 
    $ErrorActionPreference='Stop'
    $scenarioName = "$devPowStat\MinMaxCameraApp"
    $logFile = "$devPowStat-MinMaxCameraApp.txt"
    
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

        #Open Camera App and set default setting to "Use system settings" 
        Set-SystemSettingsInCamera

        #Toggling All effects on
        Write-Output "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On"
        ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                     -ECVal "On" -ECSVal "False" -ECEVal "True" -VFVal "On" `
                                     -CF "On" -CFI "False" -CFA "False" -CFW "True"
       
        Start-Sleep -s 2

        #Open Camera App
        Write-Output "Open camera App"
        $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
        Start-Sleep -s 1
        
        #Switch to video mode
        SwitchModeInCameraApp $ui "Switch to video mode" "Take video" 
        Start-Sleep -s 2

        $shell = New-Object -ComObject "Shell.Application"
        $i= 1
        while($i -le 50)
        {
           $shell.MinimizeAll()
           Start-Sleep -s 5
           $shell.UndoMinimizeALL()
           Start-Sleep -s 5
           $i++
        }
        Write-Output "Completed minimizing and maximizing camera App $i times" 

        #Close camera App
        CloseApp 'WindowsCamera'

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
        $scenarioName = "$devPowStat\Min-Max-CameraApp-ValidateScenarioID"
        CreateScenarioLogsFolder $scenarioName
                      
        #Strating to collect Traces to Validate ScenarioID 
        Write-Output "Entering StartTrace function"
        StartTrace $scenarioName

        #Open camera App
        $InitTimeCameraApp = CameraPreviewing "20"
        $cameraAppStartTime = $InitTimeCameraApp[-1]
        Write-Output "Camera App start time in UTC: ${cameraAppStartTime}"
        
        #Checks if frame server is stopped
        Write-Output "Entering CheckServiceState function"
        CheckServiceState 'Windows Camera Frame Server'

        #Stop the Trace to Validate ScenarioID 
        Write-Output "Entering StopTrace function"
        StopTrace $scenarioName
                                              
        #Verify and validate if proper logs are generated or not.   
        $wsev2PolicyState = CheckWSEV2Policy
        if($wsev2PolicyState -eq $false)
        {  
           #ScenarioID 81968 is based on v1 effects.   
           Write-Output "Entering Verifylogs function"
           Verifylogs $scenarioName "81968" $startTime

           #calculate Time from camera app started until PC trace first frame processed
           Write-Output "Entering CheckInitTimeCameraApp function" 
           CheckInitTimeCameraApp $scenarioName "81968" $cameraAppStartTime
        }
        else
        { 
           #ScenarioID 737312 is based on v1+v2 effects.   
           Write-Output "Entering Verifylogs function"
           Verifylogs $scenarioName "2834432" $startTime #(Need to change the scenario ID, not sure if this is correct)

           #calculate Time from camera app started until PC trace first frame processed
           Write-Output "Entering CheckInitTimeCameraApp function" 
           CheckInitTimeCameraApp $scenarioName "2834432" $cameraAppStartTime #(Need to change the scenario ID, not sure if this is correct)
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












