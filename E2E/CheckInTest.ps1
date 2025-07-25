param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null
)
.".\CheckInTest\Helper-library.ps1"
ManagePythonSetup -Action install
InitializeTest 'Checkin-Test' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer

foreach($devPowStat in "Pluggedin", "Unplugged")
{  
   foreach($testScenario in 'AF', 'BBS', 'BBP', 'EC', 'ECE', 'PL', 'CF-I', 'CF-A', 'CF-W')
   {
      SettingAppTest-Playlist -devPowStat $devPowStat -testScenario $testScenario -token $token -SPId $SPId >> $pathLogsFolder\"$devPowStat-SettingAppTest.txt"
   }
   VoiceFocus-Playlist -devPowStat $devPowStat -token $token -SPId $SPId >> $pathLogsFolder\"$devPowStat-VoiceFocus.txt"
   
   Camera-App-Playlist -devPowStat $devPowStat -token $token -SPId $SPId >> $pathLogsFolder\"$devPowStat-Camerae2eTest.txt"
   
   Voice-Recorder-Playlist -devPowStat $devPowStat -token $token -SPId $SPId >> $pathLogsFolder\"$devPowStat-VoiceRecordere2eTest.txt"

}
#Turn on the smart plug 
if($token.Length -ne 0 -and $SPId.Length -ne 0)
{
   SetSmartPlugState $token $SPId 1
}

ConvertTxtFileToExcel "$pathLogsFolder\Report.txt"
[console]::beep(500,300)

Start-Sleep -s 3

ManagePythonSetup -Action uninstall