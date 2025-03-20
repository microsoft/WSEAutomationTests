Add-Type -AssemblyName UIAutomationClient

<#
DESCRIPTION:
    This function tests the Camera App by setting video and photo resolutions, adjusting AI effects,
    toggling power states, and validating logs for recording and previewing scenarios.
    It ensures proper logging, checks service states, and collects trace data.

INPUT PARAMETERS:
    - logFile [string] :- Path to the log file where test results will be recorded.
    - token [string] :- Authentication token required to control the smart plug.
    - SPId [string] :- Smart plug ID used to control device power states.
    - initSetUpDone [string] :- Indicates whether the initial setup has already been completed ("true"/"false").
    - camsnario [string] :- Specifies whether the test scenario is "Recording" or "Previewing".
    - vdoRes [string] :- Video resolution setting to be applied in the Camera App.
    - ptoRes [string] :- Photo resolution setting to be applied in the Camera App.
    - devPowStat [string] :- The device power state (e.g., "PluggedIn", "OnBattery").
    - VF [string] :- Voice Focus setting ("On"/"Off"/"NA").
    - toggleEachAiEffect [array] :- Array containing AI effect toggles for various camera settings.

RETURN TYPE:
    - void 
#>
function CameraAppTest($logFile,$token,$SPId,$initSetUpDone,$camsnario,$vdoRes,$ptoRes,$devPowStat,$VF,$toggleEachAiEffect)
{
   try
   {  
       $startTime = Get-Date
       $VFdetails= "VF-$VF"
       $scenarioLogFolder = "CameraAppTest\$camsnario\$vdoRes\$ptoRes\$devPowStat\$VFdetails\$toggleEachAiEffect"
       Write-Output "`nStarting Test for $scenarioLogFolder`n"
       Write-Output "Creating the log folder" 
       CreateScenarioLogsFolder $scenarioLogFolder

       #Retrieve value for scenario from Hash table
       $toggleEachAiEffect = RetrieveValue $toggleEachAiEffect
       if($toggleEachAiEffect.length -eq 0)
       {
          TestOutputMessage $scenarioLogFolder "Skipped" $startTime "wsev2Policy Not Supported"
          return
       }
       
       if($initSetUpDone -ne "true")
       {
          # Open Camera App and set default setting to "Use system settings" 
          Set-SystemSettingsInCamera
         
          #Set the device Power state
          #if token and SPid is available than run scenarios for both pluggedin and unplugged 
          Write-Output "Start Tests for $devPowStat scenario" 
          $devState = CheckDevicePowerState $devPowStat $token $SPId
          if($devState -eq $false)
          {   
             TestOutputMessage  $scenarioLogFolder "Skipped" $startTime "Token is empty"  
             return
          }  
          
          #Open system setting page and toggle voice focus 
          if($VF -ne "NA")
          {
             VoiceFocusToggleSwitch $VF
          }
          
          #video resolution 
          Write-Output "Setting up the video resolution to $vdoRes"
          
          #Retrieve video resolution from hash table
          Write-Output "Retrieve $vdoRes value from hash table"
          $vdoRes = RetrieveValue $vdoRes
          
          #skip the test if video resolution is not available. 
          $result = SetvideoResolutionInCameraApp $scenarioLogFolder $startTime $vdoRes
          if($result[-1]  -eq $false)
          {
             Write-Output "$vdoRes is not supported"
             return
          }  
          
          #photo resolution 
          Write-Output "Setting up the Photo resolution to $ptoRes"
          
          #Retrieve photo resolution from hash table
          Write-Output "Retrieve $ptoRes value from hash table"
          $ptoRes = RetrieveValue $ptoRes
          #skip the test if photo resolution is not available. 
          $result = SetphotoResolutionInCameraApp $scenarioLogFolder $startTime $ptoRes
          if($result[-1]  -eq $false)
          {
             Write-Output "$PtoRes is not supported"
             return
          }
       
       }  
       #Open system setting page
       $ui = OpenApp 'ms-settings:' 'Settings'
       Start-Sleep -m 500
       
       #open camera effects page and turn all effects off
       Write-Output "Navigate to camera effects setting page"
       FindCameraEffectsPage $ui
       Start-Sleep -m 500 
       
       #Setting AI effects for Tests in camera setting page 
       $scenarioID = $toggleEachAiEffect[13]
                    
       #Setting AI effects for Tests in camera setting page 
       Write-Output "Setting up the camera Ai effects"       
       
       FindAndSetValue $ui ToggleSwitch "Automatic framing" $toggleEachAiEffect[0]
       FindAndSetValue $ui ToggleSwitch "Eye contact" $toggleEachAiEffect[5]
       
       FindAndSetValue $ui ToggleSwitch "Background effects" $toggleEachAiEffect[2]
       if($toggleEachAiEffect[2] -eq "On")
       {
           FindAndSetValue $ui RadioButton "Standard blur" $toggleEachAiEffect[3]
           FindAndSetValue $ui RadioButton "Portrait blur" $toggleEachAiEffect[4]
       }
       #check for v2 policy
       $wsev2PolicyState = CheckWSEV2Policy
       if($wsev2PolicyState -eq $true)	  
       {
          FindAndSetValue $ui ToggleSwitch "Portrait light" $toggleEachAiEffect[1]
          if($toggleEachAiEffect[5] -eq "On")
          {
              FindAndSetValue $ui RadioButton "Standard" $toggleEachAiEffect[6]
              FindAndSetValue $ui RadioButton "Teleprompter" $toggleEachAiEffect[7]
          }
          FindAndSetValue $ui ToggleSwitch "Creative filters" $toggleEachAiEffect[8]
          if($toggleEachAiEffect[8] -eq "On")
          {
             FindAndSetValue $ui RadioButton "Illustrated" $toggleEachAiEffect[9]
             FindAndSetValue $ui RadioButton "Animated" $toggleEachAiEffect[10]
             FindAndSetValue $ui RadioButton "Watercolor" $toggleEachAiEffect[11]
          }
       }
       CloseApp 'systemsettings'
       
       #Checks if frame server is stopped
       Write-Output "Entering CheckServiceState function"
       CheckServiceState 'Windows Camera Frame Server'
                             
       #Strating to collect Traces
       StartTrace $scenarioLogFolder

       Write-Output "Start test for $camsnario"
       if($camsnario -eq "Recording")
       {
           #Start video recording and close the camera app once finished recording 
           $InitTimeCameraApp = StartVideoRecording "20" $devPowStat #video recording duration can be adjusted depending on the number os scenarios
           $cameraAppStartTime = $InitTimeCameraApp[-1]
           Write-Output "Camera App start time in UTC: ${cameraAppStartTime}"
       }
       else
       {   
           #Start Previewing and close the camera app once finished. 
           $InitTimeCameraApp = CameraPreviewing "20" #video Previewing duration can be adjusted depending on the number os scenarios
           $cameraAppStartTime = $InitTimeCameraApp[-1]
           Write-Output "Camera App start time in UTC: ${cameraAppStartTime}"
       }
       #Checks if frame server is stopped
       Write-Output "Entering CheckServiceState function"
       CheckServiceState 'Windows Camera Frame Server' 
       
       #Stop the Trace
       Write-Output "Entering StopTrace function"
       StopTrace $scenarioLogFolder
   
       #Verify and validate if proper logs are generated or not.        
       Verifylogs $scenarioLogFolder $scenarioID $startTime
       
       #calculate Time from camera app started until PC trace first frame processed
       Write-Output "Entering CheckInitTimeCameraApp function" 
       CheckInitTimeCameraApp $scenarioLogFolder $scenarioID $cameraAppStartTime
       
       if($camsnario -eq "Recording")
       {   
          if($VF -eq "On")
          { 
             #Verify and validate if proper logs are generated or not for Audio Blur.
             VerifyAudioBlurLogs $scenarioLogFolder 512 
          } 
           
           #Get the properties of latest video recording
           GetVideoDetails $scenarioLogFolder $pathLogsFolder
       }
       
       Write-Output "Entering GetContentOfLogFileAndCopyToTestSpecificLogFile function"
       GetContentOfLogFileAndCopyToTestSpecificLogFile $scenarioLogFolder
       
       #collect data for Reporting
       Reporting $Results "$pathLogsFolder\Report.txt"
   
    }
    catch
    {
        Take-Screenshot "Error-Exception" $scenarioLogFolder
        Write-Output "Error occured and enter catch statement"
        CloseApp 'systemsettings'
        CloseApp 'WindowsCamera'
        CloseApp 'Taskmgr'
        StopTrace $scenarioLogFolder
        CheckServiceState 'Windows Camera Frame Server'
        Write-Output $_
        TestOutputMessage $scenarioLogFolder "Exception" $startTime $_.Exception.Message
        Write-Output $_ >> $pathLogsFolder\ConsoleResults.txt
        Reporting $Results "$pathLogsFolder\Report.txt"
        GetContentOfLogFileAndCopyToTestSpecificLogFile $scenarioLogFolder
        $getLogs = Get-Content -Path "$pathLogsFolder\$scenarioLogFolder\log.txt" -raw
        write-host $getLogs
        $logs = resolve-path "$pathLogsFolder\$scenarioLogFolder\log.txt"
        Write-Host "(Logs saved here:$logs)"
        SetSmartPlugState $token $SPId 1
              
        continue;
    }                                
}

<#
DESCRIPTION:
    Copies log file content to a test-specific folder. It extracts relevant logs from the main log file
    starting from the most recent test instance and saves them in a dedicated test-specific log file.

INPUT PARAMETERS:
    - scenarioLogFldr [string] :- The name of the scenario-specific folder where logs should be copied.

RETURN TYPE:
    - void
#>
function GetContentOfLogFileAndCopyToTestSpecificLogFile($scenarioLogFldr)
{   
    #copy logs to test specific folder
    $logCopyFrom = "$pathLogsFolder\$logFile"
    $logCopyTo =  "$pathLogsFolder\$scenarioLogFldr\log.txt" 
    $search="Starting Test for "
    $linenumber = Get-Content $logCopyFrom | select-string $search | Select-Object -Last 1
    $lne = $linenumber.LineNumber - 1
    Get-Content -Path $logCopyFrom | Select -Skip $lne > $logCopyTo 
}
   
