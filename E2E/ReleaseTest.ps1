param ( 
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null
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

            # Running through all the tests in a single go for all possible combinations:
            #     1. Camera Scenario :- Recording/Previewing, 
            #     2. Video Resolution :- 1440p/1080p/720p etc, 
            #     3. Photo Resolution :- 2.1MP/0.9MP/0.3MP, 
            #     4. Voice Focus :- on/off/na
            #     5. Toggle AI Effect :- PL+CF-I/AF+PL/AF+CF-A+PL+ECE+BBP etc.
            #     6. Power State :- PluggedIn/Unplugged
            # Approach:
            #     1. Battery Check: At the start, the battery status is checked.
            #     2. Unplugged Scenarios: If the battery is above 20%, the Unplugged scenarios will run. If the battery drops below 20% during the 
            #        Unplugged scenarios, the device is immediately plugged in for charging.
            #     3. Plugged-in Scenarios: We start executing pluggedIn tests during this state. This is done until either we complete all unplugged 
            #        state tests, or we reach 80% charge.
            #     4. Unplugged Scenarios Continuation: Once either of the above-mentioned state is attained, the remaining Unplugged scenarios are executed.
            #     5. This loop continues until both the unplugged and pluggedIn tests are completed.

            while ($true) {
               $batteryPercentage = Get-BatteryPercentage

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
                     CameraAppTest -logFile "CameraAppTest.txt" -token $token -SPId $SPId -initSetUpDone $initialSetupDone -camsnario $camsnario -VF $VF -vdoRes $vdoRes -ptoRes $ptoRes -devPowStat $devPowStat -toggleEachAiEffect $togAiEfft >> "$pathLogsFolder\CameraAppTest.txt"
                  } else {
                     $pluggedInLast++
                     $togAiEfft = $deviceData["ToggleAiEffect"][$pluggedInLast]
                     $devPowStat = "PluggedIn"
                     CameraAppTest -logFile "CameraAppTest.txt" -token $token -SPId $SPId -initSetUpDone $initialSetupDone -camsnario $camsnario -VF $VF -vdoRes $vdoRes -ptoRes $ptoRes -devPowStat $devPowStat -toggleEachAiEffect $togAiEfft >> "$pathLogsFolder\CameraAppTest.txt"
                  }
               }

               # Exit loop when all tests are completed
               if ($unpluggedLast -eq ($deviceData["ToggleAiEffect"].Count - 1) -and $pluggedInLast -eq ($deviceData["ToggleAiEffect"].Count - 1)) {
                  Write-Host "breaking from the while loop"
                  break
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
