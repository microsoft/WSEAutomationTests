param ( 
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null,
   [ValidateSet("Both", "PluggedInOnly", "UnpluggedOnly")][string] $runMode = $null,
   [string[]] $videoResolutions = @(),
   [string[]] $photoResolutions = @()
)
.".\CheckInTest\Helper-library.ps1"
ManagePythonSetup -Action install
InitializeTest 'ReleaseTest' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer
$deviceData = GetDeviceDetails 
Write-Log -Message "$deviceData" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append

# Handle resolution filtering based on command line parameters
$allVideoResolutions = $deviceData["VideoResolutions"]
$allPhotoResolutions = $deviceData["PhotoResolutions"]

if ($videoResolutions.Count -gt 0) {
    # Check if user wants all video resolutions
    if ($videoResolutions -contains "All" -or $videoResolutions -contains "*") {
        $filteredVideoResolutions = $allVideoResolutions
        Write-Log -Message "Using ALL available video resolutions as requested" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
    } else {
        # Use command line specified video resolutions
        $filteredVideoResolutions = @()
        $invalidVideoResolutions = @()
        
        foreach ($requestedRes in $videoResolutions) {
            # Convert short keys to full descriptive strings if needed
            $fullResString = RetrieveValue($requestedRes)
            if ($fullResString -ne $null) {
                $searchTarget = $fullResString
            } else {
                $searchTarget = $requestedRes
            }
            
            if ($allVideoResolutions -contains $searchTarget) {
                $filteredVideoResolutions += $searchTarget
                Write-Log -Message "Video resolution '$requestedRes' found and selected" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
            } else {
                # Try partial matching for flexibility
                $found = $false
                foreach ($availableRes in $allVideoResolutions) {
                    if ($availableRes -like "*$requestedRes*") {
                        $filteredVideoResolutions += $availableRes
                        Write-Log -Message "Video resolution '$requestedRes' matched to '$availableRes'" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
                        $found = $true
                        break
                    }
                }
                if (-not $found) {
                    $invalidVideoResolutions += $requestedRes
                }
            }
        }
        
        # Handle invalid resolutions gracefully
        if ($invalidVideoResolutions.Count -gt 0) {
            Write-Warning "The following video resolutions are not available on this device:"
            foreach ($invalidRes in $invalidVideoResolutions) {
                Write-Warning "  ✗ '$invalidRes'"
            }
            Write-Host "`Available video resolutions on this device:" -ForegroundColor Cyan
            foreach ($availableRes in $allVideoResolutions) {
                $shortKey = RetrieveValue($availableRes)
                if ($shortKey -ne $null) {
                    Write-Host "  • $shortKey -> $availableRes" -ForegroundColor Green
                } else {
                    Write-Host "  • $availableRes" -ForegroundColor Green
                }
            }
        }
        
        if ($filteredVideoResolutions.Count -eq 0) {
            Write-Error "CRITICAL: None of the requested video resolutions are available on this device."
            Write-Host "Please use one of the available video resolutions listed above, or use -videoResolutions @('All') to test all available resolutions." -ForegroundColor Red
            Write-Host "Example: .\ReleaseTest.ps1 -videoResolutions @('1080p', '720p') -photoResolutions @('12.2MP')" -ForegroundColor Yellow
            return
        }
    }
} else {
    # Default behavior: use strategic subset (highest + 720p + 360p)
    $filteredVideoResolutions = @()
    if ($allVideoResolutions.Count -gt 0) {
        $filteredVideoResolutions += $allVideoResolutions[0]  # Highest resolution
    }
    
    # Look for 720p and 360p in the available resolutions
    foreach ($res in $allVideoResolutions) {
        if ($res -like "*720p*" -and $filteredVideoResolutions -notcontains $res) {
            $filteredVideoResolutions += $res  # 720p
        }
        if ($res -like "*360p*" -and $filteredVideoResolutions -notcontains $res) {
            $filteredVideoResolutions += $res  # 360p
        }
    }
    
    if ($filteredVideoResolutions.Count -eq 0) {
        $filteredVideoResolutions = $allVideoResolutions  # Fallback to all if none found
    }
}

if ($photoResolutions.Count -gt 0) {
    # Check if user wants all photo resolutions
    if ($photoResolutions -contains "All" -or $photoResolutions -contains "*") {
        $filteredPhotoResolutions = $allPhotoResolutions
        Write-Log -Message "Using ALL available photo resolutions as requested" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
    } else {
        # Use command line specified photo resolutions
        $filteredPhotoResolutions = @()
        $invalidPhotoResolutions = @()
        
        foreach ($requestedRes in $photoResolutions) {
            # Convert short keys to full descriptive strings if needed
            $fullResString = RetrieveValue($requestedRes)
            if ($fullResString -ne $null) {
                $searchTarget = $fullResString
            } else {
                $searchTarget = $requestedRes
            }
            
            if ($allPhotoResolutions -contains $searchTarget) {
                $filteredPhotoResolutions += $searchTarget
                Write-Log -Message "Photo resolution '$requestedRes' found and selected" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
            } else {
                # Try partial matching for flexibility
                $found = $false
                foreach ($availableRes in $allPhotoResolutions) {
                    if ($availableRes -like "*$requestedRes*") {
                        $filteredPhotoResolutions += $availableRes
                        Write-Log -Message "Photo resolution '$requestedRes' matched to '$availableRes'" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
                        $found = $true
                        break
                    }
                }
                if (-not $found) {
                    $invalidPhotoResolutions += $requestedRes
                }
            }
        }
        
        # Handle invalid resolutions gracefully
        if ($invalidPhotoResolutions.Count -gt 0) {
            Write-Warning "The following photo resolutions are not available on this device:"
            foreach ($invalidRes in $invalidPhotoResolutions) {
                Write-Warning "  ✗ '$invalidRes'"
            }
            Write-Host "`nAvailable photo resolutions on this device:" -ForegroundColor Cyan
            foreach ($availableRes in $allPhotoResolutions) {
                $shortKey = RetrieveValue($availableRes)
                if ($shortKey -ne $null) {
                    Write-Host "  • $shortKey -> $availableRes" -ForegroundColor Green
                } else {
                    Write-Host "  • $availableRes" -ForegroundColor Green
                }
            }
        }
        
        if ($filteredPhotoResolutions.Count -eq 0) {
            Write-Error "CRITICAL: None of the requested photo resolutions are available on this device."
            Write-Host "Please use one of the available photo resolutions listed above, or use -photoResolutions @('All') to test all available resolutions." -ForegroundColor Red
            Write-Host "Example: .\ReleaseTest.ps1 -videoResolutions @('1080p') -photoResolutions @('12.2MP', '8.3MP')" -ForegroundColor Yellow
            return
        }
    }
} else {
    # Default behavior: use highest photo resolution only
    $filteredPhotoResolutions = @()
    if ($allPhotoResolutions.Count -gt 0) {
        $filteredPhotoResolutions += $allPhotoResolutions[0]  # Highest resolution
    }
    if ($filteredPhotoResolutions.Count -eq 0) {
        $filteredPhotoResolutions = $allPhotoResolutions  # Fallback to all if none found
    }
}

# Update device data with filtered resolutions
$deviceData["VideoResolutions"] = $filteredVideoResolutions
$deviceData["PhotoResolutions"] = $filteredPhotoResolutions

Write-Log -Message "Using Video Resolutions: $($filteredVideoResolutions -join ', ')" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
Write-Log -Message "Using Photo Resolutions: $($filteredPhotoResolutions -join ', ')" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append

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
      #Retrieve video resolution from hash table
	   $vdoResDetails= RetrieveValue($vdoRes)
      $scenarioName = "CameraAppTest\$camsnario\$vdoResDetails" 

      Write-Log -Message "Setting up video Res to $vdoRes" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
      
      #skip the test if video resolution is not available. 
      $result = SetvideoResolutionInCameraApp $scenarioName $startTime $vdoRes
      if($result[-1]  -eq $false)
      {
         write-Error "Expected video Res is not found: $vdoRes"
         continue;
      }  
      
      # Loop through photo resolutions  
      foreach ($ptoRes in  $deviceData["PhotoResolutions"])
      {   
         #Retrieve photo resolution from hash table 
         $ptoResDetails= RetrieveValue($ptoRes)       
         $scenarioName = "CameraAppTest\$camsnario\$vdoResDetails\$ptoResDetails" 

         Write-Log -Message "Setting up Photo Res to $ptoRes" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append

         #skip the test if photo resolution is not available. 
         $result = SetphotoResolutionInCameraApp $scenarioName $startTime $ptoRes
         if($result[-1]  -eq $false)
         {
            write-Error "Expected Photo Res is not found: $ptoRes"
            continue;
         } 

         foreach($VF in $deviceData["VoiceFocus"])
         {  
            if($VF -ne "NA")
            {
               Write-Log -Message "Setting up Voice Focus to $VF" | Out-File -FilePath "$pathLogsFolder\CameraAppTest.txt" -Append
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
                     Write-Host "Completed all AI effects for current combination: $camsnario | $vdoResDetails | $ptoResDetails | $VF" -ForegroundColor Green
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
                     Write-Host "Completed all Unplugged AI effects for current combination: $camsnario | $vdoResDetails | $ptoResDetails | $VF" -ForegroundColor Green
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
                     Write-Host "Completed all PluggedIn AI effects for current combination: $camsnario | $vdoResDetails | $ptoResDetails | $VF" -ForegroundColor Green
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

Start-Sleep -s 3

ManagePythonSetup -Action uninstall