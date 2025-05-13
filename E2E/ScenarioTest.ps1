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

   [ValidateSet('AF', 'PL', 'BBS', 'BBP', 'EC', 'ECE', 'AF+PL', 'AF+BBS', 'AF+BBP', 'AF+EC', 'AF+ECE', `
                     'PL+BBS', 'PL+BBP', 'PL+EC', 'PL+ECE', 'BBS+EC', 'BBS+ECE', 'BBP+EC', 'BBP+ECE', 'AF+PL+BBS', `
                     'AF+PL+BBP','AF+PL+EC', 'AF+PL+ECE', 'AF+BBS+EC', 'AF+BBS+ECE', 'AF+BBP+EC', 'AF+BBP+ECE', `
                     'Pl+BBS+EC', 'Pl+BBP+EC', 'Pl+BBS+ECE', 'Pl+BBP+ECE', 'AF+Pl+BBS+EC', 'AF+Pl+BBS+ECE', `
                     'AF+Pl+BBP+EC', 'AF+Pl+BBP+ECE','CF-I', 'AF+CF-I', 'AF+CF-I+PL', 'AF+CF-I+EC', `
                     'AF+CF-I+ECE', 'AF+CF-I+BBS', 'AF+CF-I+BBP', 'AF+CF-I+PL+EC', 'AF+CF-I+PL+ECE', `
                     'AF+CF-I+PL+BBS', 'AF+CF-I+PL+BBP', 'AF+CF-I+EC+BBS', 'AF+CF-I+EC+BBP', 'AF+CF-I+ECE+BBS', `
                     'AF+CF-I+ECE+BBP', 'AF+CF-I+PL+EC+BBS', 'AF+CF-I+PL+EC+BBP', 'AF+CF-I+PL+ECE+BBS', `
                     'AF+CF-I+PL+ECE+BBP', 'PL+CF-I', 'PL+CF-I+EC', 'PL+CF-I+ECE', 'PL+CF-I+BBS', `
                     'PL+CF-I+BBP', 'PL+CF-I+EC+BBS', 'PL+CF-I+EC+BBP', 'PL+CF-I+ECE+BBS', 'PL+CF-I+ECE+BBP', `
                     'EC+CF-I', 'ECE+CF-I', 'EC+CF-I+BBS', 'EC+CF-I+BBP', 'ECE+CF-I+BBS', 'ECE+CF-I+BBP', `
                     'BBS+CF-I', 'BBP+CF-I','CF-A', 'AF+CF-A', 'AF+CF-A+PL', 'AF+CF-A+EC', 'AF+CF-A+ECE', `
                     'AF+CF-A+BBS', 'AF+CF-A+BBP', 'AF+CF-A+PL+EC', 'AF+CF-A+PL+ECE', 'AF+CF-A+PL+BBS', `
                     'AF+CF-A+PL+BBP', 'AF+CF-A+EC+BBS', 'AF+CF-A+EC+BBP', 'AF+CF-A+ECE+BBS', 'AF+CF-A+ECE+BBP', `
                     'AF+CF-A+PL+EC+BBS', 'AF+CF-A+PL+EC+BBP', 'AF+CF-A+PL+ECE+BBS', 'AF+CF-A+PL+ECE+BBP', 'PL+CF-A', `
                     'PL+CF-A+EC', 'PL+CF-A+ECE', 'PL+CF-A+BBS', 'PL+CF-A+BBP', 'PL+CF-A+EC+BBS', 'PL+CF-A+EC+BBP', `
                     'PL+CF-A+ECE+BBS', 'PL+CF-A+ECE+BBP', 'EC+CF-A', 'ECE+CF-A', 'EC+CF-A+BBS', 'EC+CF-A+BBP', `
                     'ECE+CF-A+BBS', 'ECE+CF-A+BBP', 'BBS+CF-A', 'BBP+CF-A','CF-W', 'AF+CF-W', 'AF+CF-W+PL', `
                     'AF+CF-W+EC', 'AF+CF-W+ECE', 'AF+CF-W+BBS', 'AF+CF-W+BBP', 'AF+CF-W+PL+EC', 'AF+CF-W+PL+ECE', `
                     'AF+CF-W+PL+BBS', 'AF+CF-W+PL+BBP', 'AF+CF-W+EC+BBS', 'AF+CF-W+EC+BBP', 'AF+CF-W+ECE+BBS', `
                     'AF+CF-W+ECE+BBP', 'AF+CF-W+PL+EC+BBS', 'AF+CF-W+PL+EC+BBP', 'AF+CF-W+PL+ECE+BBS', `
                     'AF+CF-W+PL+ECE+BBP', 'PL+CF-W', 'PL+CF-W+EC', 'PL+CF-W+ECE', 'PL+CF-W+BBS', 'PL+CF-W+BBP', `
                     'PL+CF-W+EC+BBS', 'PL+CF-W+EC+BBP', 'PL+CF-W+ECE+BBS', 'PL+CF-W+ECE+BBP', 'EC+CF-W', `
                     'ECE+CF-W', 'EC+CF-W+BBS', 'EC+CF-W+BBP', 'ECE+CF-W+BBS', 'ECE+CF-W+BBP', 'BBS+CF-W', 'BBP+CF-W')]
   [string] $togAiEfft = "AF+BBS+EC"  # Default if not provided 
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