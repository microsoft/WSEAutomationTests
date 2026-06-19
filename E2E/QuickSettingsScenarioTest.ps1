<#
.SYNOPSIS
    Executes Camera App scenario testing with AI effects toggled via Quick Settings Studio Effects panel.

.DESCRIPTION
    This script is the Quick Settings variant of ScenarioTest.ps1. It tests Camera App functionality
    by configuring video and photo resolutions, toggling AI camera effects through the Quick Settings
    Studio Effects flyout (using OCR-based interaction), validating voice focus behavior, and handling
    device power states.

    The Studio Effects flyout in Windows Quick Settings is not accessible via UI Automation,
    so this script uses Windows.Media.Ocr to detect and interact with the panel controls.

    Use this script instead of ScenarioTest.ps1 when you need to validate that effects toggled
    from Quick Settings (rather than the Settings app) produce the same camera behavior.

.PARAMETER token
    Authentication token required to control the smart plug for power state changes.

.PARAMETER SPId
    Smart plug ID used to control device power states during testing.

.PARAMETER targetMepCameraVer
    Target MEP Camera component version to validate against the installed version.

.PARAMETER targetMepAudioVer
    Target MEP Audio component version to validate against the installed version.

.PARAMETER targetPerceptionCoreVer
    Target Perception Core component version to validate against the installed version.

.PARAMETER logFile
    Path to the log file where scenario test results will be recorded.

.PARAMETER toggleAIEffects
    Array of AI camera effect combinations to be applied during testing.
    Each element represents a single test iteration and may contain multiple effects
    combined using the "+" symbol.

    Supported AI Effects:
        AF   - Auto Framing (AFS/AFC for Standard/Cinematic)
        PL   - Portrait Light
        ECS  - Eye Contact (Standard)
        ECT  - Eye Contact (Teleprompter)
        BBS  - Background Blur (Standard)
        BBP  - Background Blur (Portrait)
        CF-I - Creative Filter (Illustrated)
        CF-A - Creative Filter (Animated)
        CF-W - Creative Filter (Watercolor)

    Example values:
        "AF+BBS+ECS"
        "AF+BBP+ECS"
        "AF+CF-I+PL+BBS"

    If set to "All", the script dynamically retrieves all supported AI effect combinations
    from the device and executes tests for each.

.PARAMETER initSetUpDone
    Indicates whether the initial setup has already been completed.
    Accepted values: "true", "false".

.PARAMETER camsnario
    Specifies the Camera App test scenario.
    Accepted values: "Recording", "Previewing".

.PARAMETER VF
    Voice Focus configuration. Note: Voice Focus is toggled via the Settings app
    even in this Quick Settings variant, as it is not available in the Studio Effects flyout.
    Accepted values: On, Off, NA

.PARAMETER vdoRes
    Video resolution setting to be applied in the Camera App.

.PARAMETER ptoRes
    Photo resolution setting to be applied in the Camera App.

.PARAMETER devPowStat
    Device power state during testing.
    Accepted values: Pluggedin, Unplugged

.PARAMETER powerProfile
    Windows power mode setting used during the test.

.EXAMPLE
    Run the script using all default values:
        .\QuickSettingsScenarioTest.ps1

.EXAMPLE
    Run with specific AI effects:
        .\QuickSettingsScenarioTest.ps1 -toggleAIEffects "AF+BBS+ECS" , "AF+BBP+ECS"

.OUTPUTS
    None. This script does not return a value.
#>


param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null,
   [string] $logFile = "QuickSettingsScenarioTesting.txt",
   
   #AF:Auto-framing, PL:Portrait light, ECS:Eye contact(Standard), ECT:Eye Contact(Teleprompter), BBS:BackgroundBlur(Standard), BBP:BackgroundBlur(Portrait) 
   #CF-I:Creative filter-Illustrated, CF-A:Creative filter-Animated, CF-W:Creative filter-Watercolor
   #You can combine multiple effects using the "+" symbol. Here are some examples: 'AF+CF-I+PL+BBS', 'AF+CF-I+PL+BBP', 'AF+CF-I+ECS+BBS', 'AF+CF-I+ECS+BBP', 'AF+CF-I+ECT+BBS'

   [string[]] $toggleAIEffects = @("AF+BBS+ECS","AF+BBP+ECS"),  # Default if not provided
   
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
   [string] $devPowStat = "Pluggedin",  # Default if not provided

   [ValidateSet("Best Power Efficiency", "Balanced", "Best Performance")]
   [string] $powerProfile = "Balanced"  # Default if not provided

)
.".\CheckInTest\Helper-library.ps1"
InitializeTest 'QuickSettingsScenarioTesting'
Import-QuickSettingsModules
$voiceFocusExists = CheckVoiceFocusPolicy  
if($voiceFocusExists -eq $false)
{
   $VF = "NA"
}

# Set up Power Profile
Write-Log -Message "Setting up Power Profile to $powerProfile" | Out-File -FilePath "$pathLogsFolder\QuickSettingsScenarioTesting.txt" -Append
SetPowerProfileInSettingsPage -powerProfile $powerProfile
CloseApp 'systemsettings'

if($toggleAIEffects -eq "All")
{
   $deviceData = GetDeviceDetails
   $toggleAIEffects = $deviceData["ToggleAiEffect"]
}    
foreach ($togAiEfft in $toggleAIEffects)
{
   CameraAppTestQuickSettings -token $token -SPId $SPId -logFile $logFile -initSetUpDone $initSetUpDone -powerProfile $powerProfile -camsnario $camsnario -VF $VF -vdoRes $vdoRes -ptoRes $ptoRes -devPowStat $devPowStat -toggleEachAiEffect $togAiEfft >> "$pathLogsFolder\QuickSettingsScenarioTesting.txt"
}

[console]::beep(500,300)
if($token.Length -ne 0 -and $SPId.Length -ne 0)
{
   SetSmartPlugState $token $SPId 1
}
[console]::beep(500,300)
 
ConvertTxtFileToExcel "$pathLogsFolder\Report.txt"
