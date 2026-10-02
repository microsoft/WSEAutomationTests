param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null,
  [ValidateSet("PluggedIn","Unplugged")]
  [string[]] $devicePowerState = @("PluggedIn","Unplugged"),
  [ValidateSet("All","Balanced","Best Power Efficiency","Best Performance")]
  [string] $powerMode = "Balanced"
)
.".\CheckInTest\Helper-library.ps1"
InitializeTest 'Checkin-Test' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer

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
     foreach($testScenario in 'AFS', 'AFC','BBS', 'BBP', 'ECS', 'ECT', 'PL', 'CF-I', 'CF-A', 'CF-W') {
        SettingAppTest-Playlist -devPowStat $devPowStat -testScenario $testScenario -token $token -SPId $SPId >> $pathLogsFolder\"$devPowStat-SettingAppTest.txt"
     }
     VoiceFocus-Playlist -devPowStat $devPowStat -token $token -SPId $SPId >> $pathLogsFolder\"$devPowStat-VoiceFocus.txt"

     Camera-App-Playlist -devPowStat $devPowStat -token $token -SPId $SPId >> $pathLogsFolder\"$devPowStat-Camerae2eTest.txt"

     Voice-Recorder-Playlist -devPowStat $devPowStat -token $token -SPId $SPId >> $pathLogsFolder\"$devPowStat-VoiceRecordere2eTest.txt"
  }
}
#Turn on the smart plug 
if($token.Length -ne 0 -and $SPId.Length -ne 0)
{
   SetSmartPlugState $token $SPId 1
}

ConvertTxtFileToExcel "$pathLogsFolder\Report.txt"
[console]::beep(500,300)
