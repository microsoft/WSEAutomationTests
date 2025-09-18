param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null,
   [string] $logFile = "ScenarioTesting.txt",
   
   #AF:Auto-framing, PL:Portrait light, ECS:Eye contact(Standard), ECT:Eye Contact(Teleprompter), BBS:BackgroundBlur(Standard), BBP:BackgroundBlur(Portrait) 
   #CF-I:Creative filter-Illustrated, CF-A:Creative filter-Animated, CF-W:Creative filter-Watercolor
   #You can combine multiple effects using the "+" symbol. Here are some examples: 'AF+CF-I+PL+BBS', 'AF+CF-I+PL+BBP', 'AF+CF-I+ECS+BBS', 'AF+CF-I+ECS+BBP', 'AF+CF-I+ECT+BBS'

   [string] $togAiEfft = "AF+BBS+ECS" ,  # Default if not provided
   
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
   [string] $devPowStat = "Pluggedin"  # Default if not provided

)
.".\CheckInTest\Helper-library.ps1"
ManagePythonSetup -Action install
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

Start-Sleep -s 3

ManagePythonSetup -Action uninstall