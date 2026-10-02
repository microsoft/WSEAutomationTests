param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null,
   [string] $CameraType = $null,
   [ValidateSet("PluggedIn","Unplugged")]
   [string[]] $devicePowerState = @("PluggedIn","Unplugged"),
   [ValidateSet("All","Balanced","Best Power Efficiency","Best Performance")]
   [string] $powerMode = "Balanced"
)

.".\CheckInTest\Helper-library.ps1"
InitializeTest 'Checkin-Test-External-Camera' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer -CameraType "External Camera"

# Loop through device power states
foreach($devPowStat in $devicePowerState) {
   # Determine which power modes to test for this device state
   $powerModesToTest = @()
   if ($powerMode -eq "All") {
      $powerModesToTest = Get-AvailablePowerModes -devicePowerState $devPowStat
   } else {
      $powerModesToTest = @($powerMode)
   }

   # Loop through power modes
   foreach($powerModeToSet in $powerModesToTest) {
      Set-PowerProfile -powerMode $powerModeToSet -devicePowerState $devPowStat
      foreach($testScenario in 'AFS', 'AFC' , 'BBS', 'BBP', 'PL', 'CF-I', 'CF-A', 'CF-W') {
         SettingAppTest-Playlist -devPowStat $devPowStat -testScenario $testScenario -token $token -SPId $SPId -CameraType "External Camera" >> $pathLogsFolder\"$devPowStat-SettingAppTest.txt"
      }

      Camera-App-Playlist -devPowStat $devPowStat -token $token -SPId $SPId -CameraType "External Camera" >> $pathLogsFolder\"$devPowStat-Camerae2eTest.txt"
   }
}

#Turn on the smart plug
if (-not [string]::IsNullOrEmpty($token) -and -not [string]::IsNullOrEmpty($SPId))
{
	SetSmartPlugState $token $SPId 1
}

ConvertTxtFileToExcel "$pathLogsFolder\Report.txt"
[console]::beep(500,300)
