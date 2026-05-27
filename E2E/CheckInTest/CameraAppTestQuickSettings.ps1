Add-Type -AssemblyName UIAutomationClient

<#
DESCRIPTION:
    This function tests the Camera App by setting video and photo resolutions, toggling AI effects
    via the Quick Settings Studio Effects panel (instead of the Settings app), and validating logs
    for recording and previewing scenarios. This is the Quick Settings variant of CameraAppTest.

    The key difference from CameraAppTest is that AI effects are toggled through the
    Quick Settings > Studio Effects flyout using OCR-based interaction, since the flyout
    is not accessible via UI Automation.
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
    - powerProfile [string] :- The power profile to use for testing.
RETURN TYPE:
    - void 
#>
function CameraAppTestQuickSettings($logFile,$token,$SPId,$initSetUpDone,$powerProfile,$camsnario,$vdoRes,$ptoRes,$devPowStat,$VF,$toggleEachAiEffect)
{
   try
   {  
       $startTime = Get-Date
       $VFdetails= "VF-$VF"
       $vdoResDetails= RetrieveValue($vdoRes)
       $ptoResDetails= RetrieveValue($ptoRes)       
       $powerProfileFolder = $powerProfile -replace ' ', ''
       $scenarioLogFolder = "CameraAppTestQS\$powerProfileFolder\$camsnario\$vdoResDetails\$ptoResDetails\$devPowStat\$VFdetails\$toggleEachAiEffect"
       Write-Log -Message "`nStarting Quick Settings Test for $scenarioLogFolder`n" -IsOutput
       Write-Log -Message "Power Profile: $powerProfile" -IsOutput
       Write-Log -Message "Creating the log folder" -IsOutput       
       CreateScenarioLogsFolder $scenarioLogFolder

       # Retrieve value for scenario from Get-CombinationReturnValues function
       $toggleEachAiEffect = Get-CombinationReturnValues -effects $toggleEachAiEffect
       if($toggleEachAiEffect.length -eq 0)
       {
          TestOutputMessage $scenarioLogFolder "Skipped" $startTime "wsev2Policy Not Supported"
          return
       }

       # Set the device Power state
       Write-Output "Start Tests for $devPowStat scenario with $powerProfile profile (Quick Settings)" 
       $devState = CheckDevicePowerState $devPowStat $token $SPId
       if($devState -eq $false)
       {   
          TestOutputMessage  $scenarioLogFolder "Skipped" $startTime "Token is empty"  
          return
       }  
       
       if($initSetUpDone -ne "true")
       {
          # Open Camera App and set default setting to "Use system settings" 
          Set-SystemSettingsInCamera
          
          # Open system setting page and toggle voice focus (not available in Quick Settings)
          if($VF -ne "NA")
          {
             VoiceFocusToggleSwitch $VF
          }
          
          # Video resolution 
          Write-Log -Message "Setting up the video resolution to $vdoRes" -IsOutput
           
          # Skip the test if video resolution is not available
          $result = SetvideoResolutionInCameraApp $scenarioLogFolder $startTime $vdoRes
          if($result[-1]  -eq $false)
          {
             Write-Log -Message "$vdoRes is not supported" -IsOutput
             return
          }  
          
          # Photo resolution 
          Write-Log -Message "Setting up the Photo resolution to $ptoRes" -IsOutput
          
          # Retrieve photo resolution from hash table
          Write-Log -Message "Retrieve $ptoRes value from hash table" -IsOutput
          # Skip the test if photo resolution is not available
          $result = SetphotoResolutionInCameraApp $scenarioLogFolder $startTime $ptoRes
          if($result[-1]  -eq $false)
          {
             Write-Log -Message "$PtoRes is not supported" -IsOutput
             return
          }
       
       }  

       # Toggle AI effects via Quick Settings Studio Effects panel (OCR-based)
       $scenarioID = $toggleEachAiEffect[15]
       Write-Log -Message "Setting up camera AI effects via Quick Settings" -IsOutput

       $qsResult = ToggleAIEffectsInQuickSettings `
           -AFVal  $toggleEachAiEffect[0]  `
           -AFSVal $(if($toggleEachAiEffect[1] -eq "True"){"On"}else{"Off"})  `
           -AFCVal $(if($toggleEachAiEffect[2] -eq "True"){"On"}else{"Off"})  `
           -PLVal  $toggleEachAiEffect[3]  `
           -BBVal  $toggleEachAiEffect[4]  `
           -BSVal  $(if($toggleEachAiEffect[5] -eq "True"){"On"}else{"Off"})  `
           -BPVal  $(if($toggleEachAiEffect[6] -eq "True"){"On"}else{"Off"})  `
           -ECVal  $toggleEachAiEffect[7]  `
           -ECSVal $(if($toggleEachAiEffect[8] -eq "True"){"On"}else{"Off"})  `
           -ECTVal $(if($toggleEachAiEffect[9] -eq "True"){"On"}else{"Off"})  `
           -VFVal  "Off"  `
           -CF     $toggleEachAiEffect[10] `
           -CFI    $(if($toggleEachAiEffect[11] -eq "True"){"On"}else{"Off"}) `
           -CFA    $(if($toggleEachAiEffect[12] -eq "True"){"On"}else{"Off"}) `
           -CFW    $(if($toggleEachAiEffect[13] -eq "True"){"On"}else{"Off"})

       if (-not $qsResult) {
           Write-Warning "Some AI effects could not be set via Quick Settings. Test may be unreliable."
       }
       
       # Checks if frame server is stopped
       Write-Log -Message "Entering CheckServiceState function" -IsOutput
       CheckServiceState 'Windows Camera Frame Server'
                             
       # Starting to collect Traces
       StartTrace $scenarioLogFolder

       # Start Test Scenario
       Write-Log -Message "Start test for $camsnario with power profile: $powerProfile (Quick Settings)" -IsOutput
       if($camsnario -eq "Recording")
       {
           $InitTimeCameraApp = StartVideoRecording -duration 6 -snarioName $scenarioLogFolder -logPath "$scenarioLogFolder\ResourceUtilization.txt"
           $cameraAppStartTime = $InitTimeCameraApp[-1]
           Write-Log -Message "Camera App start time in UTC: ${cameraAppStartTime}" -IsOutput
       }
       else
       {   
           $InitTimeCameraApp = CameraPreviewing -duration 6 -snarioName $scenarioLogFolder -logPath "$scenarioLogFolder\ResourceUtilization.txt"
           $cameraAppStartTime = $InitTimeCameraApp[-1]
           Write-Log -Message "Camera App start time in UTC: ${cameraAppStartTime}" -IsOutput
       }
       # Checks if frame server is stopped
       Write-Log -Message "Entering CheckServiceState function" -IsOutput
       CheckServiceState 'Windows Camera Frame Server' 
       
       # Stop the Trace
       Write-Log -Message "Entering StopTrace function" -IsOutput
       StopTrace $scenarioLogFolder
   
       # Verify and validate if proper logs are generated or not
       Verifylogs $scenarioLogFolder $scenarioID $startTime
       
       # Calculate Time from camera app started until PC trace first frame processed
       Write-Log -Message "Entering CheckInitTimeCameraApp function" -IsOutput
       CheckInitTimeCameraApp $scenarioLogFolder $scenarioID $cameraAppStartTime
       
       if($camsnario -eq "Recording")
       {   
          if($VF -eq "On")
          { 
             # Verify and validate audio blur logs
             VerifyAudioBlurLogs $scenarioLogFolder 512 
          } 
           
           # Get the properties of latest video recording
           GetVideoDetails $scenarioLogFolder $pathLogsFolder
       }
       
       Write-Log -Message "Entering GetContentOfLogFileAndCopyToTestSpecificLogFile function" -IsOutput
       GetContentOfLogFileAndCopyToTestSpecificLogFile $scenarioLogFolder
       
       # Collect data for Reporting
       Reporting $Results "$pathLogsFolder\Report.txt"
   
    }
    catch
    {
        Take-Screenshot "Error-Exception" $scenarioLogFolder
        Write-Log -Message "Error occurred during Quick Settings test with power profile: $powerProfile" -IsOutput
        Close-QuickSettings   # Ensure Quick Settings is closed on error
        CloseApp 'systemsettings'
        CloseApp 'WindowsCamera'
        CloseApp 'Taskmgr'
        StopTrace $scenarioLogFolder
        CheckServiceState 'Windows Camera Frame Server'
        Write-Output $_
        TestOutputMessage $scenarioLogFolder "Exception" $startTime "Power profile '$powerProfile' (QS): $($_.Exception.Message)"
        Write-Output $_ >> $pathLogsFolder\ConsoleResults.txt
        Reporting $Results "$pathLogsFolder\Report.txt"
        GetContentOfLogFileAndCopyToTestSpecificLogFile $scenarioLogFolder
        $getLogs = Get-Content -Path "$pathLogsFolder\$scenarioLogFolder\log.txt" -raw
        Write-Log -Message $getLogs -IsHost
        $logs = resolve-path "$pathLogsFolder\$scenarioLogFolder\log.txt"
        Write-Log -Message "(Logs saved here:$logs)" -IsHost
        SetSmartPlugState $token $SPId 1
              
        continue;
    }                                
}
