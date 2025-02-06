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
function SettingAppTest-Playlist($devPowStat, $testScenario, $token, $SPId) 
{   
   try
   { 
       $startTime = Get-Date    
       $ErrorActionPreference='Stop'
       $scenarioName = "$devPowStat\$testScenario"
       $logFile = "$devPowStat-SettingAppTest.txt"
       
       #Check device Power state
       $devState = CheckDevicePowerState $devPowStat $token $SPId
       if($devState -eq $false)
       {   
          TestOutputMessage $scenarioName "Skipped" $startTime "Token is empty"  
          return
       }

       #Create scenario specific folder for collecting logs
       Write-Output "Creating folder for capturing logs"
       CreateScenarioLogsFolder $scenarioName

       Write-Output "Start Tests for $scenarioName"   
       
       #Retrieve value for scenario from LookUp table for camera effects
       $testScenario = RetrieveValue $testScenario
       if($testScenario.length -eq 0)
       {
          TestOutputMessage $scenarioName "Skipped" $startTime "wsev2Policy Not Supported"
          return
       }
       
       #Toggling Ai effects as per scenarios
       #Open system setting page
       $ui = OpenApp 'ms-settings:' 'Settings'
       Start-Sleep -m 500
       
       #open camera effects page 
       Write-Output "Navigate to camera effects setting page"
       FindCameraEffectsPage $ui
       Start-Sleep -m 500 
       
      #Setting up AI effects for tests in camera setting page 
      $scenarioID = $testScenario[13]
                    
      Write-Output "Setting up the camera Ai effects"       

      FindAndSetValue $ui ToggleSwitch "Automatic framing" $testScenario[0]
      FindAndSetValue $ui ToggleSwitch "Eye contact" $testScenario[5]

      FindAndSetValue $ui ToggleSwitch "Background effects" $testScenario[2]
      if($testScenario[2] -eq "On")
      { 
         FindAndSetValue $ui RadioButton "Portrait blur" $testScenario[4]
         FindAndSetValue $ui RadioButton "Standard blur" $testScenario[3]
      }
      $wsev2PolicyState = CheckWSEV2Policy
      if($wsev2PolicyState -eq $true)	  
      {    
         FindAndSetValue $ui ToggleSwitch "Portrait light" $testScenario[1]
         if($testScenario[5] -eq "On")
         {
            FindAndSetValue $ui RadioButton "Standard" $testScenario[6]
            FindAndSetValue $ui RadioButton "Teleprompter" $testScenario[7]
         }
         FindAndSetValue $ui ToggleSwitch "Creative filters" $testScenario[8]
         if($testScenario[8] -eq "On")
         {
            FindAndSetValue $ui RadioButton "Illustrated" $testScenario[9]
            FindAndSetValue $ui RadioButton "Animated" $testScenario[10]
            FindAndSetValue $ui RadioButton "Watercolor" $testScenario[11]
         }
      }
       CloseApp 'systemsettings'
       
       #Checks if frame server is stopped
       Write-Output "Entering CheckServiceState function" 
       CheckServiceState 'Windows Camera Frame Server'
       
       #Start collecting Traces before opening setting page
       Write-Output "Entering StartTrace function"
       StartTrace $scenarioName
       
       #Open Task Manager
       Write-output "Opening Task Manager"
       $uitaskmgr = OpenApp 'Taskmgr' 'Task Manager'
       Start-Sleep -s 1
       
       Write-Output "Open Setting Page"
       $ui = OpenApp 'ms-settings:' 'Settings'
       Start-Sleep -m 500
       
       #Open camera system setting page and wait for 5 secs
       Write-Output "Entering FindCameraEffectsPage function"
       FindCameraEffectsPage $ui
       Start-Sleep -s 5
       
       #Close system setting page 
       CloseApp 'systemsettings'
       
       #Capture CPU and NPU Usage
       Write-output "Entering CPUandNPU-Usage function to capture CPU and NPU usage Screenshot"  
       stopTaskManager -uitaskmgr $uitaskmgr -Scenario $scenarioName
       
       #Checks if frame server is stopped
       Write-Output "Entering CheckServiceState function" 
       CheckServiceState 'Windows Camera Frame Server'
       
       #Stop collecting trace
       Write-Output "Entering StopTrace function"
       StopTrace $scenarioName 
       
       #Verify and validate if proper logs are generated or not.
       Write-Output "Entering Verifylogs function"
       Verifylogs $scenarioName $scenarioID $startTime
       
       #collect data for Reporting
       Reporting $Results "$pathLogsFolder\Report.txt"
         
     }
     catch
     {  
        Error-Exception -snarioName $scenarioName -strttme $startTime -rslts $Results -logFile $logFile -token $token -SPID $SPID
     }
}
