param ( 
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null,
   [ValidateSet("Both", "PluggedInOnly", "UnpluggedOnly")][string] $runMode = $null
)
.".\CheckInTest\Helper-library.ps1"
InitializeTest 'ReleaseTest' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer
$deviceData = GetDeviceDetails 
write-output $deviceData >> "$pathLogsFolder\CameraAppTest.txt"

# OneTime Setting- Open Camera App and set default setting to "Use system settings" 
Set-SystemSettingsInCamera  >> "$pathLogsFolder\CameraAppTest.txt"

# Loop through Camera mode
foreach($camsnario in $deviceData["CameraScenario"])
{  
   # Loop through video resolutions
   foreach ($vdoRes in $deviceData["VideoResolutions"])
   {  
      $initialSetupDone = "true" 
      $startTime = Get-Date 
      $scenarioName = "CameraAppTest\$camsnario\$vdoRes" 
      #Retrieve video resolution from hash table
      $vdoResDetails = RetrieveValue $vdoRes

      Write-Output "Setting up video Res to $vdoResDetails" >> "$pathLogsFolder\CameraAppTest.txt"
      
      #skip the test if video resolution is not available. 
      $result = SetvideoResolutionInCameraApp $scenarioName $startTime $vdoResDetails
      if($result[-1]  -eq $false)
      {
         write-Error "Expected video Res is not found: $vdoRes"
         continue;
      }  
      
      # Loop through photo resolutions  
      foreach ($ptoRes in  $deviceData["PhotoResolutions"])
      {   
         $scenarioName = "CameraAppTest\$camsnario\$vdoRes\$ptoRes" 
         #Retrieve photo resolution from hash table
         $ptoResDetails = RetrieveValue $ptoRes

         Write-Output "Setting up Photo Res to $ptoResDetails" >> "$pathLogsFolder\CameraAppTest.txt"

         #skip the test if photo resolution is not available. 
         $result = SetphotoResolutionInCameraApp $scenarioName $startTime $ptoResDetails
         if($result[-1]  -eq $false)
         {
            write-Error "Expected Photo Res is not found: $ptoRes"
            continue;
         } 

         foreach($VF in $deviceData["VoiceFocus"])
         {  
            if($VF -ne "NA")
            {
               Write-Output "Setting up Voice Focus to $VF" >> "$pathLogsFolder\CameraAppTest.txt"
               VoiceFocusToggleSwitch $VF >> "$pathLogsFolder\CameraAppTest.txt"
            }

            $unpluggedLast = -1
            $pluggedInLast = -1

            while ($true) {
               $batteryPercentage = Get-BatteryPercentage
               $chargingState = Get-ChargingState  # Fetch current charging state

               <#
               Approach we follow to run all the tests (pluggedin + unplugged) when smart plug details are provided along with run mode = Both or null (null meaning not provided):
                  1. Battery Check: At the start, the battery status is checked.
                  2. Unplugged Scenarios: If the battery is above 20%, the Unplugged scenarios will run. If the battery drops below 20% during the 
                     Unplugged scenarios, the device is immediately plugged in for charging.
                  3. Plugged-in Scenarios: We start executing pluggedIn tests during this state. This is done until either we complete all unplugged 
                     state tests, or we reach 80% charge.
                  4. Unplugged Scenarios Continuation: Once either of the above-mentioned state is attained, the remaining Unplugged scenarios are executed.
                  5. This loop continues until both the unplugged and pluggedIn tests are completed.
               #>
               if ($token -and $SPId -and ($runMode -eq "Both" -or [string]::IsNullOrEmpty($runMode))) {
                  if ($batteryPercentage -lt 20) {
                     while ($batteryPercentage -lt 80 -and $pluggedInLast -lt $deviceData["ToggleAiEffect"].Count - 1) {
                        $pluggedInLast++
                        $togAiEfft = $deviceData["ToggleAiEffect"][$pluggedInLast]
                        $devPowStat = "PluggedIn"
                        CameraAppTest -logFile "CameraAppTest.txt" -token $token -SPId $SPId -initSetUpDone $initialSetupDone -camsnario $camsnario -VF $VF -vdoRes $vdoRes -ptoRes $ptoRes -devPowStat $devPowStat -toggleEachAiEffect $togAiEfft >> "$pathLogsFolder\CameraAppTest.txt"
                        $batteryPercentage = Get-BatteryPercentage
                     }
                  } else {
                     if ($unpluggedLast -lt $deviceData["ToggleAiEffect"].Count - 1) {
                        $unpluggedLast++
                        $togAiEfft = $deviceData["ToggleAiEffect"][$unpluggedLast]
                        $devPowStat = "Unplugged"
                     } else {
                        $pluggedInLast++
                        $togAiEfft = $deviceData["ToggleAiEffect"][$pluggedInLast]
                        $devPowStat = "PluggedIn"
                     }
                     CameraAppTest -logFile "CameraAppTest.txt" -token $token -SPId $SPId -initSetUpDone $initialSetupDone -camsnario $camsnario -VF $VF -vdoRes $vdoRes -ptoRes $ptoRes -devPowStat $devPowStat -toggleEachAiEffect $togAiEfft >> "$pathLogsFolder\CameraAppTest.txt"
                  }

                  if ($unpluggedLast -eq ($deviceData["ToggleAiEffect"].Count - 1) -and $pluggedInLast -eq ($deviceData["ToggleAiEffect"].Count - 1)) {
                     Write-Host "breaking from the while loop"
                     break
                  }
               }

               <#
               Approach we follow to run only unplugged tests:
                  1. Run unplugged tests only when the run mode is set to "UnpluggedOnly" and smart plug details are provided.
                  2. When tried to run unplugged tests without smart plug details, the script prints error message that smart plug details are mandatory to run unplugged tests.
                  3. The script exits if all the unplugged scenarios are completed.
                  4. The script plugs in the device (until it reaches 50%) when the battery drops below 20% during the unplugged tests.
               #>
               elseif ($runMode -eq "UnpluggedOnly") {

                  if ($batteryPercentage -lt 20) {
                     Write-Host "Battery below 20%. Plugging in to charge to 50%..." -ForegroundColor Cyan
                     SetSmartPlugState $token $SPId 1  # Plug in
                     while ($batteryPercentage -lt 50) {
                         Start-Sleep -Seconds 60
                         $batteryPercentage = Get-BatteryPercentage
                         Write-Host "Charging... Current battery: $batteryPercentage%" -ForegroundColor Blue
                     }
                     Write-Host "Battery reached 50%. Unplugging and resuming tests." -ForegroundColor Green
                     SetSmartPlugState $token $SPId 0  # Unplug
                     Start-Sleep -Seconds 10  # Wait for state to stabilize
                 }

                  if (-not ($token -and $SPId)) {
                     Write-Error "Smart plug ID is required to run unplugged tests. Exiting."
                     return
                  }
                  if ($unpluggedLast -lt $deviceData["ToggleAiEffect"].Count - 1) {
                     $unpluggedLast++
                     $togAiEfft = $deviceData["ToggleAiEffect"][$unpluggedLast]
                     $devPowStat = "Unplugged"
                     CameraAppTest -logFile "CameraAppTest.txt" -token $token -SPId $SPId -initSetUpDone $initialSetupDone -camsnario $camsnario -VF $VF -vdoRes $vdoRes -ptoRes $ptoRes -devPowStat $devPowStat -toggleEachAiEffect $togAiEfft >> "$pathLogsFolder\CameraAppTest.txt"
                  } else {
                     Write-Host "All Unplugged scenarios completed. Exiting." -ForegroundColor Yellow
                     break
                  }
               }

               <#
               Approach we follow to run only pluggedin tests with or without smart plug details are provided:
                  1. Run pluggedIn tests for following cases:
                     a. When the run mode is set to "PluggedInOnly".
                     b. When the device is charging and run mode is not provided.
                  2. Above tests run until all the pluggedIn scenarios are completed. 
                  3. Once all are ompleted, the script exits.
               #>
               elseif ($runMode -eq "PluggedInOnly" -or ([string]::IsNullOrEmpty($runMode) -and $chargingState -eq "Charging")) {
                  if ($pluggedInLast -lt $deviceData["ToggleAiEffect"].Count - 1) {
                     $pluggedInLast++
                     $togAiEfft = $deviceData["ToggleAiEffect"][$pluggedInLast]
                     $devPowStat = "PluggedIn"
                     CameraAppTest -logFile "CameraAppTest.txt" -initSetUpDone $initialSetupDone -camsnario $camsnario -VF $VF -vdoRes $vdoRes -ptoRes $ptoRes -devPowStat $devPowStat -toggleEachAiEffect $togAiEfft >> "$pathLogsFolder\CameraAppTest.txt"
                  } else {
                     Write-Host "All PluggedIn scenarios completed. Exiting." -ForegroundColor Yellow
                     break
                  } 
               }

               <#
               Cases where release tests doesn't run are:
                  1. .\ReleaseTest.ps1 without connecting to any charger.
                  2. .\ReleaseTest.ps1 -runMode "UnpluggedOnly" when device is not connect to any smart plug.
                  3. .\ReleaseTest.ps1 -token "123456" -SPId "7891011" when device is not connect to any charger.
               #>
               else {
                  Write-Error "Invalid run mode specified or necessary parameters missing."
                  return
               }
            }
         } 
      }
   }
}

[console]::beep(500,300)
if (!(test-path "$pathLogsFolder\ReRunFailedTests.ps1")) 
{
   Write-host "All Tests Succeeded" -BackgroundColor Green
}
else
{  
  
   @('.".\CheckInTest\Helper-library.ps1"') + ("InitializeTest 'ReRunfailedTest'") + (Get-Content -Path "$pathLogsFolder\ReRunFailedTests.ps1") | Set-Content -Path "$pathLogsFolder\ReRunFailedTests.ps1" 
   (Get-Content -Path "$pathLogsFolder\ReRunFailedTests.ps1") -replace "111222", $token | Set-Content -Path "$pathLogsFolder\ReRunFailedTests.ps1" 
   (Get-Content -Path "$pathLogsFolder\ReRunFailedTests.ps1") -replace "333444", $SPId | Set-Content -Path "$pathLogsFolder\ReRunFailedTests.ps1"
   copy-Item $pathLogsFolder\ReRunFailedTests.ps1 -Destination ReRunFailedTests.ps1
   
}
if($token.Length -ne 0 -and $SPId.Length -ne 0)
{
   SetSmartPlugState $token $SPId 1
}
[console]::beep(500,300)
 
ConvertTxtFileToExcel "$pathLogsFolder\Report.txt"
