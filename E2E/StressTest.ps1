param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null,
   [ValidateSet("PluggedIn","Unplugged")]
   [string[]] $devicePowerState = @("PluggedIn","Unplugged"),
   [ValidateSet("All","Balanced","Best Power Efficiency","Best Performance")]
   [string] $powerMode = "Balanced"
)
.".\CheckInTest\Helper-library.ps1"
InitializeTest 'StressTest' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer

# Loop through device power states
foreach($devPowStat in $devicePowerState) {
    # Determine which power modes to test for this device state
    $powerModesToTest = @()
    if ($powerMode -eq "All") {
        $powerModesToTest = Get-AvailablePowerModes -devicePowerState $devPowStat
    } else {
        $powerModesToTest = @($powerMode)
    }

    foreach($powerModeToSet in $powerModesToTest) {
        Set-PowerProfile -powerMode $powerModeToSet -devicePowerState $devPowStat
        CameraApp-Hibernation $devPowStat $token $SPId $powerModeToSet >> $pathLogsFolder\"$devPowStat-$powerModeToSet-CameraAppHibernation.txt"

        SettingApp-Hibernation $devPowStat $token $SPId $powerModeToSet >> $pathLogsFolder\"$devPowStat-$powerModeToSet-SettingAppHibernation.txt"

        VoiceRecorderApp-Hibernation $devPowStat $token $SPId $powerModeToSet >> $pathLogsFolder\"$devPowStat-$powerModeToSet-VoiceRecorderAppHibernation.txt"

        RevisitCameraSettingPage $devPowStat $token $SPId $powerModeToSet >> $pathLogsFolder\"$devPowStat-$powerModeToSet-RevisitCameraSettingPage.txt"

        ToggleAIEffectsMultipleTimes $devPowStat $token $SPId $powerModeToSet >> $pathLogsFolder\"$devPowStat-$powerModeToSet-ToggleAIEffectsMultipleTimes.txt"

        Min-Max-CameraApp $devPowStat $token $SPId $powerModeToSet >> $pathLogsFolder\"$devPowStat-$powerModeToSet-MinMaxCameraApp.txt"
    }
}

#Turn on the smart plug 
SetSmartPlugState $token $SPId 1
[console]::beep(500,300)
