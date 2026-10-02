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
InitializeTest 'FrameDrop-Fps-Measurement' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer

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
        $i = 1
        while($i -le 10) {
            Camera-App-Playlist "$i-$devPowStat" $token $SPId >> $pathLogsFolder\"$i-$devPowStat-Camerae2eTest.txt"
            $i++
        }
    }
}

ConvertTxtFileToExcel "$pathLogsFolder\Report.txt"
if (Test-path -Path "$pathLogsFolder\Report.xlsx") 
{
   $excelFilePathToGraph = Resolve-Path "$pathLogsFolder\Report.xlsx"
   CreateScenarioLogsFolder "Graphs"
   $destinationGraphFolder = Resolve-path $pathLogsFolder\Graphs
   & ".\Library\VisualReport.ps1" -file $excelFilePathToGraph -folder $destinationGraphFolder
}
else
{
   write-host "Report excel file is not generated" -ForegroundColor Red
}
#For our Sanity, we make sure that we exit the test in netural state,which is pluggedin
SetSmartPlugState $token $SPId 1

[console]::beep(500,300)

