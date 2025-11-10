param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null,
   [string] $CameraType = $null
)

.".\CheckInTest\Helper-library.ps1"
ManagePythonSetup -Action install
InitializeTest 'Checkin-Test' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer -CameraType "External Camera"
foreach($devPowStat in "Pluggedin", "Unplugged")
{  
	foreach($testScenario in 'AF', 'BBS', 'BBP', 'PL', 'CF-I', 'CF-A', 'CF-W')
	{
		SettingAppTest-Playlist -devPowStat $devPowStat -testScenario $testScenario -token $token -SPId $SPId -CameraType "External Camera" >> $pathLogsFolder\"$devPowStat-SettingAppTest.txt"
	}
		VoiceFocus-Playlist -devPowStat $devPowStat -token $token -SPId $SPId >> $pathLogsFolder\"$devPowStat-VoiceFocus.txt"
		   
		Camera-App-Playlist -devPowStat $devPowStat -token $token -SPId $SPId >> $pathLogsFolder\"$devPowStat-Camerae2eTest.txt"
		   
		Voice-Recorder-Playlist -devPowStat $devPowStat -token $token -SPId $SPId >> $pathLogsFolder\"$devPowStat-VoiceRecordere2eTest.txt"
}


#Turn on the smart plug
if (-not [string]::IsNullOrEmpty($token) -and -not [string]::IsNullOrEmpty($SPId))
{
	SetSmartPlugState $token $SPId 1
}

ConvertTxtFileToExcel "$pathLogsFolder\Report.txt"
[console]::beep(500,300)

Start-Sleep -s 3

ManagePythonSetup -Action uninstall