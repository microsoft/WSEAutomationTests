param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null
)
.".\CheckInTest\Helper-library.ps1"
InitializeTest 'WSE+PS' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer

foreach($devPowStat in "Pluggedin", "Unplugged")
{
   Test-WSE+Recall "$devPowStat" $token $SPId >> $pathLogsFolder\"$devPowStat-WSE+Recall.txt"
   Test-WSE+CoCreator "$devPowStat" $token $SPId >> $pathLogsFolder\"$devPowStat-WSE+CoCreator.txt"
}
#Turn on the smart plug 
if($token.Length -ne 0 -and $SPId.Length -ne 0)
{
   SetSmartPlugState $token $SPId 1
}

[console]::beep(500,300)

ConvertTxtFileToExcel "$pathLogsFolder\Report.txt"