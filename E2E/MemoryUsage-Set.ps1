param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null
)
.".\CheckInTest\Helper-library.ps1"
InitializeTest 'MemoryUsage-Set' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer
foreach($devPowStat in "Pluggedin" , "Unplugged")
{
   MemoryUsage-Playlist "$devPowStat" $token $SPId >> $pathLogsFolder\"$devPowStat-MemoryUsage.txt"

}
#For our Sanity, we make sure that we exit the test in netural state,which is pluggedin
SetSmartPlugState $token $SPId 1

[console]::beep(500,300)