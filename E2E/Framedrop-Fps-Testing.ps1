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
   while($i -le 10)
   {    
      Camera-App-Playlist "$i-$devPowStat" $token $SPId >> $pathLogsFolder\"$i-$devPowStat-Camerae2eTest.txt"
      $i++
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

