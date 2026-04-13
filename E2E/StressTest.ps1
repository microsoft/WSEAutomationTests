param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null
)
.".\CheckInTest\Helper-library.ps1"
InitializeTest 'StressTest' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer

foreach($devPowStat in "Pluggedin" , "Unplugged")
{
   CameraApp-Hibernation $devPowStat $token $SPId >> $pathLogsFolder\"$devPowStat-CameraAppHibernation.txt"

   SettingApp-Hibernation $devPowStat $token $SPId >> $pathLogsFolder\"$devPowStat-SettingAppHibernation.txt"

   VoiceRecorderApp-Hibernation $devPowStat $token $SPId >> $pathLogsFolder\"$devPowStat-VoiceRecorderAppHibernation.txt"

   RevisitCameraSettingPage $devPowStat $token $SPId >> $pathLogsFolder\"$devPowStat-RevisitCameraSettingPage.txt"

   ToggleAIEffectsMultipleTimes $devPowStat $token $SPId >> $pathLogsFolder\"$devPowStat-ToggleAIEffectsMultipleTimes.txt"

   Min-Max-CameraApp $devPowStat $token $SPId >> $pathLogsFolder\"$devPowStat-MinMaxCameraApp.txt"
  
}
#Turn on the smart plug 
SetSmartPlugState $token $SPId 1
[console]::beep(500,300)

