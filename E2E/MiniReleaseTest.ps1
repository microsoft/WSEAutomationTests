param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null,
   [ValidateSet("Both", "PluggedInOnly", "UnpluggedOnly")][string] $runMode = $null,
   [ValidateRange(1, 100)][int] $maxTests = 20
)

.".\CheckInTest\Helper-library.ps1"

function Select-StrategicSubset {
   param(
      [object[]] $values,
      [int] $maxItems = 3
   )

   $allValues = @($values)
   if ($allValues.Count -eq 0) {
      return @()
   }

   $targetCount = [Math]::Min($maxItems, $allValues.Count)
   $selected = [System.Collections.Generic.List[object]]::new()
   $candidateIndexes = [System.Collections.Generic.List[int]]::new()

   $candidateIndexes.Add(0)

   if ($allValues.Count -gt 2) {
      $candidateIndexes.Add([Math]::Floor($allValues.Count / 2))
   }

   if ($allValues.Count -gt 1) {
      $candidateIndexes.Add($allValues.Count - 1)
   }

   foreach ($index in $candidateIndexes) {
      $candidate = $allValues[$index]
      if ($selected -notcontains $candidate) {
         $selected.Add($candidate)
      }

      if ($selected.Count -ge $targetCount) {
         return $selected.ToArray()
      }
   }

   foreach ($candidate in $allValues) {
      if ($selected -notcontains $candidate) {
         $selected.Add($candidate)
      }

      if ($selected.Count -ge $targetCount) {
         break
      }
   }

   return $selected.ToArray()
}

function Invoke-CappedCameraAppTest {
   param(
      [hashtable] $cameraAppTestParameters
   )

   if ($script:testsExecuted -ge $script:maxTests) {
      return $false
   }

   CameraAppTest @cameraAppTestParameters >> "$pathLogsFolder\CameraAppTest.txt"
   $script:testsExecuted++

   Write-Log -Message "Completed mini release test $($script:testsExecuted)/$($script:maxTests)" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
   return $true
}

InitializeTest 'MiniReleaseTest' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer

$script:maxTests = $maxTests
$script:testsExecuted = 0

$deviceData = GetDeviceDetails
Write-Log -Message "$deviceData" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append

$filteredVideoResolutions = Filter-Resolutions -requestedResolutions @() -availableResolutions $deviceData["VideoResolutions"] -resolutionType "video"
$filteredPhotoResolutions = Filter-Resolutions -requestedResolutions @() -availableResolutions $deviceData["PhotoResolutions"] -resolutionType "photo"

$selectedCameraScenarios = @(Select-StrategicSubset -values @($deviceData["CameraScenario"]) -maxItems 2)
$selectedVoiceFocusModes = @(Select-StrategicSubset -values @($deviceData["VoiceFocus"]) -maxItems 2)
$selectedAiEffects = @(Select-StrategicSubset -values @($deviceData["ToggleAiEffect"]) -maxItems 4)

if ($selectedVoiceFocusModes.Count -eq 0) {
   $selectedVoiceFocusModes = @("NA")
}

Write-Log -Message "Mini release selection: Scenarios=[$($selectedCameraScenarios -join ', ')], Video=[$($filteredVideoResolutions -join ', ')], Photo=[$($filteredPhotoResolutions -join ', ')], VoiceFocus=[$($selectedVoiceFocusModes -join ', ')], AiEffects=[$($selectedAiEffects -join ', ')]" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append

Set-SystemSettingsInCamera >> "$pathLogsFolder\CameraAppTest.txt"

:cameraScenarioLoop foreach ($camsnario in $selectedCameraScenarios)
{
   :videoResolutionLoop foreach ($vdoRes in $filteredVideoResolutions)
   {
      $initialSetupDone = "true"
      $startTime = Get-Date
      $vdoResDetails = RetrieveValue($vdoRes)
      $scenarioName = "CameraAppTest\$camsnario\$vdoResDetails"

      Write-Log -Message "Setting up video Res to $vdoRes" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append

      $result = SetvideoResolutionInCameraApp $scenarioName $startTime $vdoRes
      if ($result[-1] -eq $false)
      {
         Write-Error "Expected video Res is not found: $vdoRes"
         continue
      }

      foreach ($ptoRes in $filteredPhotoResolutions)
      {
         $ptoResDetails = RetrieveValue($ptoRes)
         $scenarioName = "CameraAppTest\$camsnario\$vdoResDetails\$ptoResDetails"

         Write-Log -Message "Setting up Photo Res to $ptoRes" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append

         $result = SetphotoResolutionInCameraApp $scenarioName $startTime $ptoRes
         if ($result[-1] -eq $false)
         {
            Write-Error "Expected Photo Res is not found: $ptoRes"
            continue
         }

         foreach ($VF in $selectedVoiceFocusModes)
         {
            if ($script:testsExecuted -ge $script:maxTests) {
               break cameraScenarioLoop
            }

            if ($VF -ne "NA")
            {
               Write-Log -Message "Setting up Voice Focus to $VF" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
               VoiceFocusToggleSwitch $VF >> "$pathLogsFolder\CameraAppTest.txt"
            }

            $unpluggedLast = -1
            $pluggedInLast = -1

            while ($true) {
               if ($script:testsExecuted -ge $script:maxTests) {
                  break cameraScenarioLoop
               }

               $batteryPercentage = Get-BatteryPercentage
               $chargingState = Get-ChargingState

               if ($token -and $SPId -and ($runMode -eq "Both" -or [string]::IsNullOrEmpty($runMode))) {
                  if ($batteryPercentage -lt 20) {
                     while ($batteryPercentage -lt 80 -and $pluggedInLast -lt $selectedAiEffects.Count - 1) {
                        if ($script:testsExecuted -ge $script:maxTests) {
                           break cameraScenarioLoop
                        }

                        $pluggedInLast++
                        $togAiEfft = $selectedAiEffects[$pluggedInLast]
                        $devPowStat = "PluggedIn"

                        $cameraAppTestParameters = @{
                           logFile = "CameraAppTest.txt"
                           token = $token
                           SPId = $SPId
                           initSetUpDone = $initialSetupDone
                           camsnario = $camsnario
                           VF = $VF
                           vdoRes = $vdoRes
                           ptoRes = $ptoRes
                           devPowStat = $devPowStat
                           toggleEachAiEffect = $togAiEfft
                        }

                        if (-not (Invoke-CappedCameraAppTest -cameraAppTestParameters $cameraAppTestParameters)) {
                           break cameraScenarioLoop
                        }

                        $batteryPercentage = Get-BatteryPercentage
                     }
                  }
                  else {
                     if ($unpluggedLast -lt $selectedAiEffects.Count - 1) {
                        $unpluggedLast++
                        $togAiEfft = $selectedAiEffects[$unpluggedLast]
                        $devPowStat = "Unplugged"
                     }
                     elseif ($pluggedInLast -lt $selectedAiEffects.Count - 1) {
                        $pluggedInLast++
                        $togAiEfft = $selectedAiEffects[$pluggedInLast]
                        $devPowStat = "PluggedIn"
                     }
                     else {
                        break
                     }

                     $cameraAppTestParameters = @{
                        logFile = "CameraAppTest.txt"
                        token = $token
                        SPId = $SPId
                        initSetUpDone = $initialSetupDone
                        camsnario = $camsnario
                        VF = $VF
                        vdoRes = $vdoRes
                        ptoRes = $ptoRes
                        devPowStat = $devPowStat
                        toggleEachAiEffect = $togAiEfft
                     }

                     if (-not (Invoke-CappedCameraAppTest -cameraAppTestParameters $cameraAppTestParameters)) {
                        break cameraScenarioLoop
                     }
                  }

                  if ($unpluggedLast -eq ($selectedAiEffects.Count - 1) -and $pluggedInLast -eq ($selectedAiEffects.Count - 1)) {
                     Write-Log -Message "Completed all mini release AI effects for current combination: $camsnario | $vdoResDetails | $ptoResDetails | $VF" -ForegroundColor Green
                     break
                  }
               }
               elseif ($runMode -eq "UnpluggedOnly") {
                  if (-not ($token -and $SPId)) {
                     Write-Error "Smart plug ID is required to run unplugged tests. Exiting."
                     return
                  }

                  if ($batteryPercentage -lt 20) {
                     Write-Log -Message "Battery below 20%. Plugging in to charge to 50%..." -IsHost -ForegroundColor Cyan
                     SetSmartPlugState $token $SPId 1
                     while ($batteryPercentage -lt 50) {
                        Start-Sleep -Seconds 60
                        $batteryPercentage = Get-BatteryPercentage
                        Write-Log -Message "Charging... Current battery: $batteryPercentage%" -IsHost -ForegroundColor Blue
                     }

                     Write-Log -Message "Battery reached 50%. Unplugging and resuming tests." -IsHost -ForegroundColor Green
                     SetSmartPlugState $token $SPId 0
                     Start-Sleep -Seconds 10
                  }

                  if ($unpluggedLast -lt $selectedAiEffects.Count - 1) {
                     $unpluggedLast++
                     $togAiEfft = $selectedAiEffects[$unpluggedLast]
                     $devPowStat = "Unplugged"

                     $cameraAppTestParameters = @{
                        logFile = "CameraAppTest.txt"
                        token = $token
                        SPId = $SPId
                        initSetUpDone = $initialSetupDone
                        camsnario = $camsnario
                        VF = $VF
                        vdoRes = $vdoRes
                        ptoRes = $ptoRes
                        devPowStat = $devPowStat
                        toggleEachAiEffect = $togAiEfft
                     }

                     if (-not (Invoke-CappedCameraAppTest -cameraAppTestParameters $cameraAppTestParameters)) {
                        break cameraScenarioLoop
                     }
                  }
                  else {
                     Write-Log -Message "All mini release unplugged scenarios completed for current combination." -IsHost -ForegroundColor Yellow
                     break
                  }
               }
               elseif ($runMode -eq "PluggedInOnly" -or ([string]::IsNullOrEmpty($runMode) -and $chargingState -eq "Charging")) {
                  if ($pluggedInLast -lt $selectedAiEffects.Count - 1) {
                     $pluggedInLast++
                     $togAiEfft = $selectedAiEffects[$pluggedInLast]
                     $devPowStat = "PluggedIn"

                     $cameraAppTestParameters = @{
                        logFile = "CameraAppTest.txt"
                        initSetUpDone = $initialSetupDone
                        camsnario = $camsnario
                        VF = $VF
                        vdoRes = $vdoRes
                        ptoRes = $ptoRes
                        devPowStat = $devPowStat
                        toggleEachAiEffect = $togAiEfft
                     }

                     if (-not (Invoke-CappedCameraAppTest -cameraAppTestParameters $cameraAppTestParameters)) {
                        break cameraScenarioLoop
                     }
                  }
                  else {
                     Write-Log -Message "All mini release plugged-in scenarios completed for current combination." -IsHost -ForegroundColor Yellow
                     break
                  }
               }
               else {
                  Write-Log -Message "Invalid run mode specified or necessary parameters missing." -IsHost
                  return
               }
            }
         }
      }
   }
}

Write-Log -Message "Mini release finished after executing $script:testsExecuted test(s)." -IsHost -ForegroundColor Green

[console]::beep(500,300)
if (!(Test-Path "$pathLogsFolder\ReRunFailedTests.ps1"))
{
   Write-Log -Message "All Tests Succeeded" -IsHost -BackgroundColor Green
}
else
{
   @('.".\CheckInTest\Helper-library.ps1"') + ("InitializeTest 'ReRunfailedTest'") + (Get-Content -Path "$pathLogsFolder\ReRunFailedTests.ps1") | Set-Content -Path "$pathLogsFolder\ReRunFailedTests.ps1"
   (Get-Content -Path "$pathLogsFolder\ReRunFailedTests.ps1") -replace "111222", $token | Set-Content -Path "$pathLogsFolder\ReRunFailedTests.ps1"
   (Get-Content -Path "$pathLogsFolder\ReRunFailedTests.ps1") -replace "333444", $SPId | Set-Content -Path "$pathLogsFolder\ReRunFailedTests.ps1"
   Copy-Item $pathLogsFolder\ReRunFailedTests.ps1 -Destination ReRunFailedTests.ps1
}

if (-not [string]::IsNullOrEmpty($token) -and -not [string]::IsNullOrEmpty($SPId))
{
   SetSmartPlugState $token $SPId 1
}

[console]::beep(500,300)

ConvertTxtFileToExcel "$pathLogsFolder\Report.txt"