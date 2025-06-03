param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null,
   [string] $logFile = "ScenarioTesting.txt",
   
   [ValidateSet("true" , "false")]
   [string] $initSetUpDone = "false",  # Default if not provided

   [ValidateSet("Recording" , "Previewing")]
   [string] $camsnario = "Recording",  # Default if not provided

   [ValidateSet("On", "Off", "NA")]
   [string] $VF = "On",   # Default if not provided

   [ValidateSet("1440p, 16 by 9 aspect ratio, 30 fps" , "1080p, 16 by 9 aspect ratio, 30 fps" ,"720p, 16 by 9 aspect ratio, 30 fps",`
                "480p, 4 by 3 aspect ratio, 30 fps" , "360p, 16 by 9 aspect ratio, 30 fps" , "1440p, 4 by 3 aspect ratio, 30 fps" ,`
                "1080p, 4 by 3 aspect ratio, 30 fps" , "960p, 4 by 3 aspect ratio, 30 fps" , "640p, 1 by 1 aspect ratio, 30 fps" ,`
                "540p, 16 by 9 aspect ratio, 30 fps")]
   [string] $vdoRes = "1080p, 16 by 9 aspect ratio, 30 fps",  # Default if not provided 

   [ValidateSet("8.3 megapixels, 16 by 9 aspect ratio,  3840 by 2160 resolution" , "12.2 megapixels, 4 by 3 aspect ratio,  4032 by 3024 resolution" ,`
                "5.0 megapixels, 4 by 3 aspect ratio,  2592 by 1944 resolution" , "4.5 megapixels, 3 by 2 aspect ratio,  2592 by 1728 resolution" ,`
                "3.8 megapixels, 16 by 9 aspect ratio,  2592 by 1458 resolution" , "2.1 megapixels, 16 by 9 aspect ratio,  1920 by 1080 resolution" ,`
                "1.6 megapixels, 4 by 3 aspect ratio,  1440 by 1080 resolution" , "0.9 megapixels, 16 by 9 aspect ratio,  1280 by 720 resolution" ,`
                "0.8 megapixels, 4 by 3 aspect ratio,  1024 by 768 resolution" , "0.3 megapixels, 4 by 3 aspect ratio,  640 by 480 resolution" ,`
                "0.2 megapixels, 16 by 9 aspect ratio,  640 by 360 resolution" , "1.2 megapixels, 4 by 3 aspect ratio,  1280 by 960 resolution" ,`
                "0.08 megapixels, 4 by 3 aspect ratio,  320 by 240 resolution" , "0.02 megapixels, 4 by 3 aspect ratio,  160 by 120 resolution" ,`
                "0.1 megapixels, 11 by 9 aspect ratio,  352 by 288 resolution" , "0.03 megapixels, 11 by 9 aspect ratio,  176 by 144 resolution")]
   [string] $ptoRes = "2.1 megapixels, 16 by 9 aspect ratio,  1920 by 1080 resolution",  # Default if not provided

   [ValidateSet("Pluggedin", "Unplugged")]
   [string] $devPowStat = "Pluggedin",   # Default if not provided

   [ValidateSet('AF', 'PL', 'BBS', 'BBP', 'ECS', 'ECT', 'AF+PL', 'AF+BBS', 'AF+BBP', 'AF+ECS', 'AF+ECT', `
                     'PL+BBS', 'PL+BBP', 'PL+ECS', 'PL+ECT', 'BBS+ECS', 'BBS+ECT', 'BBP+ECS', 'BBP+ECT', 'AF+PL+BBS', `
                     'AF+PL+BBP','AF+PL+ECS', 'AF+PL+ECT', 'AF+BBS+ECS', 'AF+BBS+ECT', 'AF+BBP+ECS', 'AF+BBP+ECT', `
                     'Pl+BBS+ECS', 'Pl+BBP+ECS', 'Pl+BBS+ECT', 'Pl+BBP+ECT', 'AF+Pl+BBS+ECS', 'AF+Pl+BBS+ECT', `
                     'AF+Pl+BBP+ECS', 'AF+Pl+BBP+ECT','CF-I', 'AF+CF-I', 'AF+CF-I+PL', 'AF+CF-I+ECS', `
                     'AF+CF-I+ECT', 'AF+CF-I+BBS', 'AF+CF-I+BBP', 'AF+CF-I+PL+ECS', 'AF+CF-I+PL+ECT', `
                     'AF+CF-I+PL+BBS', 'AF+CF-I+PL+BBP', 'AF+CF-I+ECS+BBS', 'AF+CF-I+ECS+BBP', 'AF+CF-I+ECT+BBS', `
                     'AF+CF-I+ECT+BBP', 'AF+CF-I+PL+ECS+BBS', 'AF+CF-I+PL+ECS+BBP', 'AF+CF-I+PL+ECT+BBS', `
                     'AF+CF-I+PL+ECT+BBP', 'PL+CF-I', 'PL+CF-I+ECS', 'PL+CF-I+ECT', 'PL+CF-I+BBS', `
                     'PL+CF-I+BBP', 'PL+CF-I+ECS+BBS', 'PL+CF-I+ECS+BBP', 'PL+CF-I+ECT+BBS', 'PL+CF-I+ECT+BBP', `
                     'ECS+CF-I', 'ECT+CF-I', 'ECS+CF-I+BBS', 'ECS+CF-I+BBP', 'ECT+CF-I+BBS', 'ECT+CF-I+BBP', `
                     'BBS+CF-I', 'BBP+CF-I','CF-A', 'AF+CF-A', 'AF+CF-A+PL', 'AF+CF-A+ECS', 'AF+CF-A+ECT', `
                     'AF+CF-A+BBS', 'AF+CF-A+BBP', 'AF+CF-A+PL+ECS', 'AF+CF-A+PL+ECT', 'AF+CF-A+PL+BBS', `
                     'AF+CF-A+PL+BBP', 'AF+CF-A+ECS+BBS', 'AF+CF-A+ECS+BBP', 'AF+CF-A+ECT+BBS', 'AF+CF-A+ECT+BBP', `
                     'AF+CF-A+PL+ECS+BBS', 'AF+CF-A+PL+ECS+BBP', 'AF+CF-A+PL+ECT+BBS', 'AF+CF-A+PL+ECT+BBP', 'PL+CF-A', `
                     'PL+CF-A+ECS', 'PL+CF-A+ECT', 'PL+CF-A+BBS', 'PL+CF-A+BBP', 'PL+CF-A+ECS+BBS', 'PL+CF-A+ECS+BBP', `
                     'PL+CF-A+ECT+BBS', 'PL+CF-A+ECT+BBP', 'ECS+CF-A', 'ECT+CF-A', 'ECS+CF-A+BBS', 'ECS+CF-A+BBP', `
                     'ECT+CF-A+BBS', 'ECT+CF-A+BBP', 'BBS+CF-A', 'BBP+CF-A','CF-W', 'AF+CF-W', 'AF+CF-W+PL', `
                     'AF+CF-W+ECS', 'AF+CF-W+ECT', 'AF+CF-W+BBS', 'AF+CF-W+BBP', 'AF+CF-W+PL+ECS', 'AF+CF-W+PL+ECT', `
                     'AF+CF-W+PL+BBS', 'AF+CF-W+PL+BBP', 'AF+CF-W+ECS+BBS', 'AF+CF-W+ECS+BBP', 'AF+CF-W+ECT+BBS', `
                     'AF+CF-W+ECT+BBP', 'AF+CF-W+PL+ECS+BBS', 'AF+CF-W+PL+ECS+BBP', 'AF+CF-W+PL+ECT+BBS', `
                     'AF+CF-W+PL+ECT+BBP', 'PL+CF-W', 'PL+CF-W+ECS', 'PL+CF-W+ECT', 'PL+CF-W+BBS', 'PL+CF-W+BBP',  `
                     'PL+CF-W+ECS+BBS', 'PL+CF-W+ECS+BBP', 'PL+CF-W+ECT+BBS', 'PL+CF-W+ECT+BBP', 'ECS+CF-W', `
                     'ECT+CF-W', 'ECS+CF-W+BBS', 'ECS+CF-W+BBP', 'ECT+CF-W+BBS', 'ECT+CF-W+BBP', 'BBS+CF-W', 'BBP+CF-W')]
   [string] $togAiEfft = "AF+BBS+ECS"  # Default if not provided 
)
.".\CheckInTest\Helper-library.ps1"
InitializeTest 'ScenarioTesting'
$voiceFocusExists = CheckVoiceFocusPolicy  
if($voiceFocusExists -eq $false)
{
   $VF = "NA"
}
CameraAppTest -token $token -SPId $SPId -logFile $logFile -initSetUpDone $initSetUpDone -camsnario $camsnario -VF $VF -vdoRes $vdoRes -ptoRes $ptoRes -devPowStat $devPowStat -toggleEachAiEffect $togAiEfft >> "$pathLogsFolder\ScenarioTesting.txt"

[console]::beep(500,300)
if($token.Length -ne 0 -and $SPId.Length -ne 0)
{
   SetSmartPlugState $token $SPId 1
}
[console]::beep(500,300)
 
ConvertTxtFileToExcel "$pathLogsFolder\Report.txt"