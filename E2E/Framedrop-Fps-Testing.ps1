param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null
)
.".\CheckInTest\Helper-library.ps1"
InitializeTest 'FrameDrop-Fps-Measurement' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer

foreach($devPowStat in "Pluggedin" , "Unplugged")
{
   $i=1
   while($i -le 3)
   {    
      Camera-App-Playlist "$i-$devPowStat" $token $SPId >> $pathLogsFolder\"$i-$devPowStat-Camerae2eTest.txt"
      $i++
   }
}
#For our Sanity, we make sure that we exit the test in netural state,which is pluggedin
SetSmartPlugState $token $SPId 1

[console]::beep(500,300)

