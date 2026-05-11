<#
DESCRIPTION:
    Enables the "Save snapshots" feature in Windows Settings under "Privacy & Security". If the feature is 
    off, it prompts for manual intervention (Windows Hello) to enable it.

INPUT PARAMETERS:
    - None

RETURN TYPE:
    - [boolean] : Returns $true after successful execution.
#>

if (-not (Get-Command Get-TraceFmtJsonFromLine -ErrorAction SilentlyContinue))
{
   $traceFmtLib = Join-Path $PSScriptRoot 'TraceFmtParsing.ps1'
   if (Test-Path -LiteralPath $traceFmtLib) { . $traceFmtLib }
}

function EnableRecall()
{
    #open settings app and obtain ui automation from it   
    $ui = OpenApp 'ms-settings:' 'Settings'
    Start-Sleep -m 500
    FindAndClick $ui Microsoft.UI.Xaml.Controls.NavigationViewItem Apps
    Start-Sleep -m 500
    FindAndClick $ui Microsoft.UI.Xaml.Controls.NavigationViewItem "Privacy & security"
    Start-Sleep -m 500
    FindAndClick $ui ListViewItem "Recall & snapshots"
    Start-Sleep -m 500
    $result = FindAndGetValue $ui ToggleSwitch "Save snapshots" 
    if($result -eq "On")
    { 
       Write-Log -Message "Snapshot is already enabled" -IsHost
    }
    else
    {
       Write-Log -Message "Manual invervention is required to enter Windows Hello to Enable Save Snapshot" -IsHost -ForegroundColor "Yellow"
       start-sleep -s 10
       FindAndSetValue $ui ToggleSwitch "Save snapshots" True
    }
    Start-Sleep -m 500
    CloseApp 'systemsettings'
    return $true
  
}
<#
DESCRIPTION:
   Verifies logs for snapshot captures and saves by checking the AsgTraceFmt.txt (tracefmt) file.
   It reports how many keyframe-detection events were emitted and, when present in the JSON payload,
   sums the captured/saved counters.

INPUT PARAMETERS:
   - snarioName [string] : Scenario name to locate the AsgTraceFmt.txt log.
    - strtTime [string] : Start time for log verification.

RETURN TYPE:
    - void : Outputs results to the console and log files.
#>
function Verify-RecallLogs
{  
   param($snarioName, $strtTime)
   $pathAsgTraceFmtTxt = "$pathLogsFolder\$snarioName\" + "AsgTraceFmt.txt"
   Write-Log -Message "Validating AsgTraceFmt.txt logs" -IsOutput

   if (Test-path -Path $pathAsgTraceFmtTxt) 
   {   
      $snapshotPattern = "CaptureProviderKeyframeDetection"
      $snapshotCapturedAll = @(Select-string -path $pathAsgTraceFmtTxt -Pattern $snapshotPattern)
      if($snapshotCapturedAll.Count -eq 0)
      {
         Write-Log -Message "No logs captured for: $snapshotPattern" -IsHost -ForegroundColor "Yellow"
         Write-Output "No logs captured for: $snapshotPattern" >> "$pathLogsFolder\ConsoleResults.txt"
         return
      }

      $totalNumofSnapshotCaptured = 0
      $totalNumofSnapshotSaved = 0
      $hasNumericCounters = $false

      foreach ($m in $snapshotCapturedAll)
      {
         $line = $m.Line
         $obj = Get-TraceFmtJsonFromLine -Line $line
         if ($null -eq $obj) { continue }

         # Best-effort: different builds may emit different field names.
         $capturedKeys = @('NumberOfSnapshotsCaptured','NumofSnapshotCaptured','NumOfSnapshotCaptured','SnapshotsCaptured','Captured')
         $savedKeys    = @('NumberOfSnapshotsSaved','NumofSnapshotSaved','NumOfSnapshotSaved','SnapshotsSaved','Saved')

         foreach ($k in $capturedKeys)
         {
            if ($obj.PSObject.Properties.Name -contains $k)
            {
               $v = $obj.$k
               if ($v -ne $null -and $v -is [ValueType]) { $totalNumofSnapshotCaptured += [int64]$v; $hasNumericCounters = $true }
               break
            }
         }

         foreach ($k in $savedKeys)
         {
            if ($obj.PSObject.Properties.Name -contains $k)
            {
               $v = $obj.$k
               if ($v -ne $null -and $v -is [ValueType]) { $totalNumofSnapshotSaved += [int64]$v; $hasNumericCounters = $true }
               break
            }
         }
      }

      Write-Log -Message "KeyframeDetection events: $($snapshotCapturedAll.Count)" -IsHost -IsOutput
      Write-Output "KeyframeDetection events: $($snapshotCapturedAll.Count)" >> "$pathLogsFolder\ConsoleResults.txt"

      if ($hasNumericCounters)
      {
         Write-Log -Message "totalNumofSnapshotCaptured: $totalNumofSnapshotCaptured" -IsHost -IsOutput
         Write-Log -Message "totalNumofSnapshotSaved: $totalNumofSnapshotSaved" -IsHost -IsOutput
         Write-Output "TotalNumofSnapshotCaptured : $totalNumofSnapshotCaptured" >> "$pathLogsFolder\ConsoleResults.txt"
         Write-Output "TotalNumofSnapshotSaved : $totalNumofSnapshotSaved" >> "$pathLogsFolder\ConsoleResults.txt"
      }
      else
      {
         Write-Log -Message "No numeric captured/saved counters found in JSON payloads; reporting event count only." -IsHost -ForegroundColor "Yellow"
         Write-Output "No numeric captured/saved counters found in JSON payloads; reporting event count only." >> "$pathLogsFolder\ConsoleResults.txt"
      }
    }
   else
   {
      Write-Log -Message "$pathAsgTraceFmtTxt not found" -IsHost -ForegroundColor "Red"
      Write-Output "$pathAsgTraceFmtTxt not found" >> "$pathLogsFolder\ConsoleResults.txt"
      return
   }
}