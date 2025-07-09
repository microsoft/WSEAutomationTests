﻿Add-Type -AssemblyName UIAutomationClient

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
    $resourceUtilizationConsolidated = "$pathLogsFolder\$devPowStat-consolidate_stats.txt"
    $resourceUtilizationFile = "$pathLogsFolder\$devPowStat-resource_utilization.txt"
    $devState = CheckDevicePowerState $devPowStat $token $SPId
    if($devState -eq $false)
    {   
       TestOutputMessage $scenarioName "Skipped" $startTime "Token is empty"  
       return
    }

    try
	{  
        # Create scenario specific folder for collecting logs
        Write-Log -Message "Creating folder for capturing logs" -IsOutput
        CreateScenarioLogsFolder $scenarioName
                
        # Set up camera effects/settings and start collecting trace
        Get-InitialSetUp $scenarioName 
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
        Write-Log -Message "Completed minimizing and maximizing camera App $i times" -IsOutput

        # Close camera App
        CloseApp 'WindowsCamera'

        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server'

        # Stop the Trace for generic error
        Write-Log -Message "Entering StopTrace function" -IsOutput
        StopTrace $scenarioName

        # Check for generic error
        GenericError $scenarioName

        # Check if AvgMemoryUsage is greater than 250MB
        CheckMemoryUsage $scenarioName

        # Create scenario specific folder for collecting logs
        Write-Log -Message "Creating folder for capturing logs" -IsOutput
        $scenarioName = "$devPowStat\Min-Max-CameraApp-ValidateScenarioID"
        CreateScenarioLogsFolder $scenarioName
                      
        # Starting to collect Traces to Validate ScenarioID 
        Write-Log -Message "Entering StartTrace function" -IsOutput
        StartTrace $scenarioName

        # Open Task Manager
        Write-Log -Message "Opening Task Manager" -IsOutput
        $uitaskmgr = OpenApp 'Taskmgr' 'Task Manager'
        Start-Sleep -s 1
        setTMUpdateSpeedLow -uiEle $uitaskmgr
        # Call python modules for task manager Before starting the test case
        Start-Process -FilePath "python" -ArgumentList @(
            $pythonLibFolder,
            "start_resource_monitoring",
            $resourceUtilizationFile,
            $scenarioName,
            5,
            "Before"
        ) -NoNewWindow -RedirectStandardOutput $resourceUtilizationConsolidated -Wait

        # Now process is finished, so call GetResourceUtilizationStats
        $utilizationStats = GetResourceUtilizationStats $resourceUtilizationConsolidated "Before"
        Write-Log -Message $utilizationStats -IsOutput >> $pathLogsFolder\ConsoleResults.txt
        if ($null -eq $utilizationStats) {
            Write-Error "Failed to get resource utilization stats."
            return
        }
        # Open camera App
        $InitTimeCameraApp = CameraPreviewing "20" $devPowStat $logFile $resourceUtilizationConsolidated "After"
        $cameraAppStartTime = $InitTimeCameraApp[-1]
        Write-Log -Message "Camera App start time in UTC: ${cameraAppStartTime}" -IsOutput
        
        # Close Task Manager and take Screenshot of CPU and NPU Usage
        Write-Log -Message "Entering stopTaskManager function to Close Task Manager and capture CPU and NPU usage Screenshot" -IsOutput
        stopTaskManager -uitaskmgr $uitaskmgr -Scenario $scenarioName
        
        $utilizationStats = GetResourceUtilizationStats $resourceUtilizationConsolidated "After"

        if ($null -eq $utilizationStats) {
            Write-Error "Failed to get resource utilization stats."
            return
        }

        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server'

        # Stop the Trace to Validate ScenarioID 
        Write-Log -Message "Entering StopTrace function" -IsOutput
        StopTrace $scenarioName
                                              
        # Verify and validate if proper logs are generated or not.   
        $wsev2PolicyState = CheckWSEV2Policy
        if($wsev2PolicyState -eq $false)
        {  
           # ScenarioID 81968 is based on v1 effects.   
           Write-Log -Message "Entering Verifylogs function" -IsOutput
           Verifylogs $scenarioName "81968" $startTime

           # Calculate Time from camera app started until PC trace first frame processed
           Write-Log -Message "Entering CheckInitTimeCameraApp function" -IsOutput
           CheckInitTimeCameraApp $scenarioName "81968" $cameraAppStartTime
        }
        else
        { 
           # ScenarioID 737312 is based on v1+v2 effects.   
           Write-Log -Message "Entering Verifylogs function" -IsOutput
           Verifylogs $scenarioName "2834432" $startTime #(Need to change the scenario ID, not sure if this is correct)

           # Calculate Time from camera app started until PC trace first frame processed
           Write-Log -Message "Entering CheckInitTimeCameraApp function" -IsOutput
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












