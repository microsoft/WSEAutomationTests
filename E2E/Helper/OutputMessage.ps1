# Install Import-Excel module (if not already installed)
Install-Module -Name ImportExcel -Force -Scope CurrentUser

<#
DESCRIPTION:
    This function logs the test result message with its execution time. 
    Depending on the test outcome (Pass, Fail, Exception, or Skipped), 
    it updates the result status, logs to the console and writes to a result file.
INPUT PARAMETERS:
    - snario [string] :- The name of the test scenario.
    - tstReslt [string] :- The result of the test (Pass, Fail, Exception, Skipped).
    - strtTime [datetime] :- The start time of the test, used to calculate execution time.
    - reasonForNotPass [string] :- The reason for failure or skipping (optional for Pass).
RETURN TYPE:
    - void (Logs the test result message and updates the result status.)
#>
function TestOutputMessage($snario, $tstReslt, $strtTime, $reasonForNotPass)
{
    $Global:sequenceNumber++
    $currNum = $Global:sequenceNumber.ToString() + "."
    $endTime = Get-Date
    $totalExecutionTimeInSeconds = [math]::round((New-TimeSpan -Start $strtTime -End $endTime).TotalSeconds,2)
    switch ($tstReslt)
    {
        "Pass" {
                  Write-Host -NoNewline "$currNum ${snario}: "; Write-host -NoNewline "Passed " -ForegroundColor Green; Write-Log -Message "(${totalExecutionTimeInSeconds}s)" -IsHost
                  Write-Log -Message "$currNum ${snario}:Passed (${totalExecutionTimeInSeconds}s)" -IsOutput >> $pathLogsFolder\ConsoleResults.txt
                  $Results.Status = "Pass"
                  $Results.ReasonForNotPass = $null
               }
        "Fail" {
                 Write-Host -NoNewline "$currNum ${snario}: "; Write-host -NoNewline "Failed " -ForegroundColor Red; Write-Log -Message "(${totalExecutionTimeInSeconds}s)" -IsHost
                 AddToFailedTestsList "$currNum ${snario}"
                 Write-Log -Message "$currNum ${snario}:Failed (${totalExecutionTimeInSeconds}s)" -IsOutput >> $pathLogsFolder\ConsoleResults.txt
                 
                 # Reseting all field values to empty for failed case scenario exception for Status and ReasonForNotPass
                 ResetFields

                 $Results.ScenarioName = $snario
                 $Results.Status = "Fail"
                 $Results.ReasonForNotPass = $reasonForNotPass
               }

               
        "Exception" {
                       Write-Host -NoNewline "$currNum ${snario}: "; Write-host -NoNewline "Failed " -ForegroundColor Red; Write-Log -Message "(${totalExecutionTimeInSeconds}s)" -IsHost
                       AddToFailedTestsList "$currNum ${snario}"
                       Write-Log -Message "$currNum ${snario}:Failed(Exception) (${totalExecutionTimeInSeconds}s)" -IsOutput >> $pathLogsFolder\ConsoleResults.txt

                       # Reseting all field values to empty for Exception case scenario exception for Status and ReasonForNotPass
                       ResetFields
                       
                       $Results.ScenarioName = $snario
                       $Results.Status = "Fail"
                       $Results.ReasonForNotPass = "Exception: " + $reasonForNotPass
                    }
                 
                    
        "Skipped"{
                    Write-Host -NoNewline "$currNum ${snario}: "; Write-host -NoNewline "Skipped " -ForegroundColor Yellow; Write-Log -Message "(${reasonForNotPass}) (${totalExecutionTimeInSeconds}s)" -IsHost
                    Write-Log -Message "$currNum ${snario}:Skipped (${reasonForNotPass})(${totalExecutionTimeInSeconds}s)" -IsOutput >> $pathLogsFolder\ConsoleResults.txt

                    # Reseting all field values to empty for skipped case scenario exception for Status and ReasonForNotPass
                    ResetFields

                    $Results.ScenarioName = $snario
                    $Results.Status = "Skipped"
                    $Results.ReasonForNotPass = $reasonForNotPass
					Reporting $Results "$pathLogsFolder\Report.txt"
                 }
                 
    }
}

<#
DESCRIPTION:
    This function resets all result fields to null except for the scenario name and reason for not passing. 
    It is used to clear data between test cases.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - void (Resets global variables without returning a value.)
#>
function ResetFields {
   $Results.ScenarioName = $null
   $Results.FramesAbove33ms = $null
   $Results.TotalNumberOfFrames = $null 								   
   $Results.'AvgProcessingTimePerFrame(In ms)' =$null
   $Results.'MaxProcessingTimePerFrame(In ms)' =$null
   $Results.'MinProcessingTimePerFrame(In ms)' =$null
   $Results.'timetofirstframe(In secs)' = $null
   $Results.'CameraAppInItTime(In secs)' = $null
   $Results.'VoiceRecorderInItTime(In secs)' = $null
   $Results.fps = $null
   $Results.'timetofirstframeForAudio(In secs)' = $null
   $Results.FramesAbove33msForAudioBlur = $null
   $Results.'PeakWorkingSetSize(In MB)'= $null
   $Results.'AvgWorkingSetSize(In MB)' = $null
   $Results.Status = $null
   $Results.ReasonForNotPass = $null
   $Results.BeforeMedianCPUUsage = $null
   $Results.BeforeMedianNPUUsage = $null
   $Results.BeforeMedianMemoryUsage = $null
   $Results.BeforeMedianMemoryUsageGB = $null
   $Results.BeforePeakCPUUsage = $null
   $Results.BeforePeakNPUUsage = $null
   $Results.BeforePeakMemoryUsage = $null
   $Results.BeforePeakMemoryUsageGB = $null
   $Results.BeforeAverageCPUUsage = $null
   $Results.BeforeAverageNPUUsage = $null
   $Results.BeforeAverageMemoryUsage = $null
   $Results.BeforeAverageMemoryUsageGB = $null
   $Results.AfterMedianCPUUsage = $null
   $Results.AfterMedianNPUUsage = $null
   $Results.AfterMedianMemoryUsage = $null
   $Results.AfterMedianMemoryUsageGB = $null
   $Results.AfterPeakCPUUsage = $null
   $Results.AfterPeakNPUUsage = $null
   $Results.AfterPeakMemoryUsage = $null
   $Results.AfterPeakMemoryUsageGB = $null
   $Results.AfterAverageCPUUsage = $null
   $Results.AfterAverageNPUUsage = $null
   $Results.AfterAverageMemoryUsage = $null
   $Results.AfterAverageMemoryUsageGB = $null
   $Results.DiffMedianCPUUsage = $null
   $Results.DiffMedianNPUUsage = $null
   $Results.DiffMedianMemoryUsage = $null
   $Results.DiffMedianMemoryUsageGB = $null
   $Results.DiffPeakCPUUsage = $null
   $Results.DiffPeakNPUUsage = $null
   $Results.DiffPeakMemoryUsage = $null
   $Results.DiffPeakMemoryUsageGB = $null
   $Results.DiffAverageCPUUsage = $null
   $Results.DiffAverageNPUUsage = $null
   $Results.DiffAverageMemoryUsage = $null
   $Results.DiffAverageMemoryUsageGB = $null
}

<#
DESCRIPTION:
    This function appends the test results to an output file and resets fields for the next test case.
INPUT PARAMETERS:
    - rslt [PSObject] :- The result object containing the test information.
    - outputfile [string] :- The path to the output file where results are logged.
RETURN TYPE:
    - void (Writes results to a file and resets fields without returning a value.)
#>
function Reporting($rslt, $outputfile)
{
   Write-Output $rslt >> $outputfile
   ResetFields
}

<#
DESCRIPTION:
    This function converts the text file containing test results into an Excel file. 
    It reads key-value pairs from the text file and writes them into an Excel sheet using the ImportExcel module.
INPUT PARAMETERS:
    - textFilePath [string] :- The path to the text file containing test results.
RETURN TYPE:
    - void (Converts and writes results to an Excel file without returning a value.)
#>
function ConvertTxtFileToExcel($textFilePath)
{
   $excelFilePath = "$pathLogsFolder\Report.xlsx"
     
   # Read the text file content
   $textFileContent = Get-Content -Path $textFilePath -Raw
   
   # Check if the content is not null or empty
   if (-not [string]::IsNullOrWhiteSpace($textFileContent))
   {
       # Initialize an array to store rows
       $rows = @()
   
       # Process each set of data in the text file
       foreach ($textData in ($textFileContent -split "`r`n`r`n" | Where-Object { $_.Trim() -ne '' }))
       {
          # Convert text data to key-value pairs
          $propertyValuePairs = $textData -split "`r`n" | ForEach-Object{
            if ($_ -match '^(.*?):\s*(.*)$') {
                  $property = $matches[1].Trim()
                  $value = $matches[2].Trim()
                  [PSCustomObject]@{
                      Property = $property
                      Value = $value
                  }
              } else {
                  Write-Log -Message "Warning: Line does not match expected format: $_" -IsHost -ForegroundColor Yellow
              }
          }
   
          # Create a single-row custom object for each set of data
          $excelRow = [PSCustomObject]@{}
          $propertyValuePairs | ForEach-Object{
              $excelRow | Add-Member -MemberType NoteProperty -Name $_.Property -Value $_.Value
          }
   
          # Add the row to the array
          $rows += $excelRow
       }
   
       # Export all rows to Excel
       $rows | Export-Excel -Path $excelFilePath
       Write-Log -Message "   Report generated here:$excelFilePath" -IsHost
   } 
   else
   {
       Write-Log -Message "Error: The content of the Report text file is null or empty." -IsHost -ForegroundColor Red
   }
}

<#
DESCRIPTION:
    This function adds failed tests to a list for re-execution. 
    It parses the failed test details and generates commands for rerunning them, 
    saving the commands and failed test names to respective files.
INPUT PARAMETERS:
    - failedTests [string] :- The string containing the failed test information.
RETURN TYPE:
    - void (Adds failed tests to files without returning a value.)
#>
function AddToFailedTestsList($failedTests)
{
   $splitEachTests = $failedTests -split "\\"
   $camsnario = $splitEachTests[1]
   $logFolder = $splitEachTests[0] -split ". "
   $functionToCall = $logFolder[1]
   $logFile = $logFolder[1] + ".txt"
   $vdoRes = $splitEachTests[2]
   $ptoRes = $splitEachTests[3]
   $devPowStat = $splitEachTests[4]
   $VFdetails  = $splitEachTests[5] -split "-"
   $VF = $VFdetails[1]
   $togAiEfft = $splitEachTests[6]
   $token = "111222"
   $SPID ="333444"
if($functionToCall -eq  "CameraAppTest")
   {
      Write-Output "$functionToCall -logFile $logFile $token $SPId -camsnario $camsnario -vdoRes $vdoRes -ptoRes $ptoRes -devPowStat $devPowStat -VF $VF -toggleEachAiEffect $togAiEfft >> `$pathLogsFolder\CameraAppTest.txt" >> $pathLogsFolder\ReRunFailedTests.ps1
      Write-Output $failedTests >> $pathLogsFolder\failedTests.txt
   }
   else
   {
      Write-Output $failedTests >> $pathLogsFolder\failedTests.txt
   }
}

function GetResourceUtilizationStats($rawTextFile, $executionState)
{
    if (-Not (Test-Path $rawTextFile)) {
        Write-Error "File not found: $rawTextFile"
        return $null
    }

	$contentRaw = Get-Content -Path $rawTextFile -Raw
    $contentLines = $contentRaw -split "`r?`n"

    # Write raw content to console results file
    Write-Log -Message "$contentLines" -IsOutput >> $pathLogsFolder\ConsoleResults.txt
    $utilizationStats = @{}
    if ($executionState -eq "Before") {
        $startIndex = ($contentLines | Select-String "--- Before Resource Utilization Statistics ---").LineNumber

		Write-Log -Message "startIndex :  $startIndex" -IsOutput >> $pathLogsFolder\ConsoleResults.txt
        if (-not $startIndex) {
            Write-Error "'$sectionHeader' section not found."
            return $null
        }
        for ($i = $startIndex; $i -lt $contentLines.Count; $i++) {
            $line = $contentLines[$i].Trim()
            if ($line -match "^---") { continue }
			Parse-UtilizationLine -line $line -prefix 'before' -utilizationStats $utilizationStats

        }

        $Results.BeforeMedianCPUUsage = "$($utilizationStats['before_median_cpu'])%"
        $Results.BeforePeakCPUUsage = "$($utilizationStats['before_peak_cpu'])%"
        $Results.BeforeAverageCPUUsage = "$($utilizationStats['before_avg_cpu'])%"

        $Results.BeforeMedianNPUUsage = "$($utilizationStats['before_median_npu'])%"
        $Results.BeforePeakNPUUsage = "$($utilizationStats['before_peak_npu'])%"
        $Results.BeforeAverageNPUUsage = "$($utilizationStats['before_avg_npu'])%"

        $Results.BeforeMedianMemoryUsage = "$($utilizationStats['before_median_memory'])%"
        $Results.BeforePeakMemoryUsage = "$($utilizationStats['before_peak_memory'])%"
        $Results.BeforeAverageMemoryUsage = "$($utilizationStats['before_avg_memory'])%"
		
		$Results.BeforeMedianMemoryUsageGB = "$($utilizationStats['before_median_memory_usage_gb'])"
        $Results.BeforePeakMemoryUsageGB = "$($utilizationStats['before_peak_memory_usage_gb'])"
        $Results.BeforeAverageMemoryUsageGB = "$($utilizationStats['before_avg_memory_usage_gb'])"

    } elseif ($executionState -eq "After") {
		$afterIndex = ($contentLines | Select-String "--- After Resource Utilization Statistics ---").LineNumber
		Write-Log -Message "afterIndex :  $afterIndex" -IsOutput >> $pathLogsFolder\ConsoleResults.txt

        if (-not $afterIndex) {
            Write-Error "'$sectionHeader' section not found."
            return $null
        }
		Write-Log -Message "contenttLines Count : $($contentLines.Count)" -IsOutput >> $pathLogsFolder\ConsoleResults.txt
        for ($i = $afterIndex; $i -lt $contentLines.Count; $i++) {
            $line = $contentLines[$i].Trim()
			Write-Log -Message "Inside line : $line" -IsOutput >> $pathLogsFolder\ConsoleResults.txt
            if ($line -match "^---") { break }
			Parse-UtilizationLine -line $line -prefix 'after' -utilizationStats $utilizationStats

        }
        $Results.AfterMedianCPUUsage = "$($utilizationStats['after_median_cpu'])%"
        $Results.AfterPeakCPUUsage = "$($utilizationStats['after_peak_cpu'])%"
        $Results.AfterAverageCPUUsage = "$($utilizationStats['after_avg_cpu'])%"

        $Results.AfterMedianNPUUsage = "$($utilizationStats['after_median_npu'])%"
        $Results.AfterPeakNPUUsage = "$($utilizationStats['after_peak_npu'])%"
        $Results.AfterAverageNPUUsage = "$($utilizationStats['after_avg_npu'])%"

        $Results.AfterMedianMemoryUsage = "$($utilizationStats['after_median_memory'])%"
        $Results.AfterPeakMemoryUsage = "$($utilizationStats['after_peak_memory'])%"
        $Results.AfterAverageMemoryUsage = "$($utilizationStats['after_avg_memory'])%"
		
		$Results.AfterMedianMemoryUsageGB = "$($utilizationStats['after_median_memory_usage_gb'])"
        $Results.AfterPeakMemoryUsageGB = "$($utilizationStats['after_peak_memory_usage_gb'])"
        $Results.AfterAverageMemoryUsageGB = "$($utilizationStats['after_avg_memory_usage_gb'])"

        $diffIndex = ($contentLines | Select-String "--- Statistics Difference \(After vs Before\) ---").LineNumber
        if (-not $diffIndex) {
            Write-Error "'--- Statistics Difference (After vs Before) ---' section not found."
            return $null
        }

        for ($i = $diffIndex; $i -lt $contentLines.Count; $i++) {
            $line = $contentLines[$i].Trim()
            if ($line -match "^---") { continue }
			Parse-UtilizationLine -line $line -prefix 'diff' -utilizationStats $utilizationStats

        }
        $Results.DiffMedianCPUUsage = "$($utilizationStats['diff_median_cpu'])%"
        $Results.DiffPeakCPUUsage = "$($utilizationStats['diff_peak_cpu'])%"
        $Results.DiffAverageCPUUsage = "$($utilizationStats['diff_avg_cpu'])%"

        $Results.DiffMedianNPUUsage = "$($utilizationStats['diff_median_npu'])%"
        $Results.DiffPeakNPUUsage = "$($utilizationStats['diff_peak_npu'])%"
        $Results.DiffAverageNPUUsage = "$($utilizationStats['diff_avg_npu'])%"

        $Results.DiffMedianMemoryUsage = "$($utilizationStats['diff_median_memory'])%"
        $Results.DiffPeakMemoryUsage = "$($utilizationStats['diff_peak_memory'])%"
        $Results.DiffAverageMemoryUsage = "$($utilizationStats['diff_avg_memory'])%"
		
		$Results.DiffMedianMemoryUsageGB = "$($utilizationStats['diff_median_memory_usage_gb'])"
        $Results.DiffPeakMemoryUsageGB = "$($utilizationStats['diff_peak_memory_usage_gb'])"
        $Results.DiffAverageMemoryUsageGB = "$($utilizationStats['diff_avg_memory_usage_gb'])"
    }
    else {
        Write-Error "Invalid execution state: $executionState. Use 'Before', 'After', or 'Diff'."
        return $null
    }

    return $utilizationStats
}

function Parse-UtilizationLine {
    param (
        [string]$line,
        [string]$prefix,
        [hashtable]$utilizationStats,
        [switch]$EnableLog
    )

    if ($line -match "^(.+?)\s*-\s*Median:\s*([\d.]+)%?,\s*Average:\s*([\d.]+)%?,\s*Peak:\s*([\d.]+)%?") {
        $component = ($matches[1].ToLower() -replace '[^a-z0-9]+', '_').Trim('_')

        if ($EnableLog) {
            Write-Log -Message "line matched" -IsOutput >> $pathLogsFolder\ConsoleResults.txt
            Write-Log -Message "component : $component" -IsOutput >> $pathLogsFolder\ConsoleResults.txt
        }

        $utilizationStats["${prefix}_median_$component"] = [double]$matches[2]
        $utilizationStats["${prefix}_avg_$component"]    = [double]$matches[3]
        $utilizationStats["${prefix}_peak_$component"]   = [double]$matches[4]
    }
}