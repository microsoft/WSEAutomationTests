Add-Type -AssemblyName UIAutomationClient

<#
DESCRIPTION:
    This function automates testing of the Windows Settings App, specifically focusing on camera AI effects.
    It applies various AI effect configurations, collects performance traces, captures CPU and NPU usage, 
    and verifies if logs are generated correctly.
INPUT PARAMETERS:
    - devPowStat [string] :- The power state of the device (e.g., "PluggedIn", "OnBattery").
    - testScenario [string] :- The test scenario defining specific AI effect settings to apply.
    - token [string] :- Authentication token required to control the smart plug.
    - SPId [string] :- Smart plug ID used to control device power states.
RETURN TYPE:
    - void
#>
function SettingAppTest-Playlist($devPowStat, $testScenario, $token, $SPId, [string]$CameraType = "Internal Camera")
{
   try
   {
      $startTime = Get-Date
      $ErrorActionPreference = 'Stop'
      $scenarioName = "$devPowStat\$testScenario"
      $logFile = "$devPowStat-SettingAppTest.txt"
      #Check device Power state
      $devState = CheckDevicePowerState $devPowStat $token $SPId
      if ($devState -eq $false)
      {
         TestOutputMessage $scenarioName "Skipped" $startTime "Token is empty"
         return
      }

      #Create scenario specific folder for collecting logs
      Write-Log -Message "Creating folder for capturing logs" -IsOutput
      CreateScenarioLogsFolder $scenarioName

      Write-Log -Message "Starting Test for $scenarioName" -IsOutput

      #Retrieve value for scenario from Get-CombinationReturnValues function
      $testScenario = Get-CombinationReturnValues -effects $testScenario
      if ($testScenario.length -eq 0)
      {
         TestOutputMessage $scenarioName "Skipped" $startTime "wsev2Policy Not Supported"
         return
      }

      # Toggling AI effects as per scenarios
      # Open system setting page
      $ui = OpenApp 'ms-settings:' 'Settings'
      Start-Sleep -m 500

      # Open camera effects page
      Write-Log -Message "Navigate to camera effects setting page" -IsOutput
      FindCameraEffectsPage $ui
      Start-Sleep -s 5

      # Setting up AI effects for tests in camera setting page
      $scenarioID = $testScenario[13]

      Write-Log -Message "Setting up the camera Ai effects" -IsOutput

      FindAndSetValue $ui ToggleSwitch "Automatic framing" $testScenario[0]

      if ($CameraType -ne "External Camera")
      {
         FindAndSetValue $ui ToggleSwitch "Eye contact" $testScenario[5]
      }

      FindAndSetValue $ui ToggleSwitch "Background effects" $testScenario[2]
      if ($testScenario[2] -eq "On")
      {
         FindAndSetValue $ui RadioButton "Portrait blur" $testScenario[4]
         FindAndSetValue $ui RadioButton "Standard blur" $testScenario[3]
      }
      $wsev2PolicyState = CheckWSEV2Policy
      if ($wsev2PolicyState -eq $true)
      {
         FindAndSetValue $ui ToggleSwitch "Portrait light" $testScenario[1]
         if ($testScenario[5] -eq "On")
         {
            FindAndSetValue $ui RadioButton "Standard" $testScenario[6]
            FindAndSetValue $ui RadioButton "Teleprompter" $testScenario[7]
         }
         FindAndSetValue $ui ToggleSwitch "Creative filters" $testScenario[8]
         if ($testScenario[8] -eq "On")
         {
            FindAndSetValue $ui RadioButton "Illustrated" $testScenario[9]
            FindAndSetValue $ui RadioButton "Animated" $testScenario[10]
            FindAndSetValue $ui RadioButton "Watercolor" $testScenario[11]
         }
      }
      CloseApp 'systemsettings'

      # Checks if frame server is stopped
      Write-Log -Message "Entering CheckServiceState function" -IsOutput
      CheckServiceState 'Windows Camera Frame Server'

      # Capture Resource Utilization before test starts
      Monitor-Resources -scenario $scenarioName -executionState "Before" -logPath "$scenarioName\ResourceUtilization.txt" -Once "Once"

      # Start collecting Traces before opening setting page
      Write-Log -Message "Entering StartTrace function" -IsOutput
      StartTrace $scenarioName

      Write-Log -Message "Open Setting Page" -IsOutput
      $ui = OpenApp 'ms-settings:' 'Settings'
      Start-Sleep -m 500

      # Open camera system setting page and wait for 5 secs
      Write-Log -Message "Entering FindCameraEffectsPage function" -IsOutput
      FindCameraEffectsPage $ui
      Start-Sleep -s 5

      # Close system setting page
      CloseApp 'systemsettings'

      # Capture Resource Utilization while test is running. Each duration runs for around 10-12 sec
      Monitor-Resources -scenario $scenarioName -duration 2 -executionState "During" -logPath "$scenarioName\ResourceUtilization.txt"

      # Checks if frame server is stopped
      Write-Log -Message "Entering CheckServiceState function" -IsOutput
      CheckServiceState 'Windows Camera Frame Server'

      # Stop collecting trace
      Write-Log -Message "Entering StopTrace function" -IsOutput
      StopTrace $scenarioName

      # Verify and validate if proper logs are generated or not.
      Write-Log -Message "Entering Verifylogs function" -IsOutput
      Verifylogs $scenarioName $scenarioID $startTime

      # Copy logs to test scenario specific folder
      Write-Log -Message "Entering GetContentOfLogFileAndCopyToTestSpecificLogFile function" -IsOutput
      GetContentOfLogFileAndCopyToTestSpecificLogFile $scenarioName

      #collect data for Reporting
      Reporting $Results "$pathLogsFolder\Report.txt"

   }
   catch
   {
      Take-Screenshot "Error-Exception" $scenarioName
      Write-Log -Message "Error occurred and entered catch statement" -IsOutput
      CloseApp 'systemsettings'
      CloseApp 'WindowsCamera'
      CloseApp 'Taskmgr'
      StopTrace $scenarioName
      CheckServiceState 'Windows Camera Frame Server'
      Write-Output $_
      TestOutputMessage $scenarioName "Exception" $startTime $_.Exception.Message
      Write-Output $_ >> $pathLogsFolder\ConsoleResults.txt
      Reporting $Results "$pathLogsFolder\Report.txt"
      GetContentOfLogFileAndCopyToTestSpecificLogFile $scenarioName
      $getLogs = Get-Content -Path "$pathLogsFolder\$scenarioName\log.txt" -Raw
      Write-Log -Message $getLogs -IsHost
      $logs = resolve-path "$pathLogsFolder\$scenarioName\log.txt"
      Write-Log -Message "(Logs saved here:$logs)" -IsHost
      SetSmartPlugState $token $SPID 1
   }
}
