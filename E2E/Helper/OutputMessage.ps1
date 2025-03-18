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
                       $Results.Status = "Exception"
                       $Results.ReasonForNotPass = $reasonForNotPass
                    }
                 
                    
        "Skipped"{
                    Write-Host -NoNewline "$currNum ${snario}: "; Write-host -NoNewline "Skipped " -ForegroundColor Yellow; Write-Log -Message "(${reasonForNotPass}) (${totalExecutionTimeInSeconds}s)" -IsHost
                    Write-Log -Message "$currNum ${snario}:Skipped (${reasonForNotPass})(${totalExecutionTimeInSeconds}s)" -IsOutput >> $pathLogsFolder\ConsoleResults.txt

                    # Reseting all field values to empty for skipped case scenario exception for Status and ReasonForNotPass
                    ResetFields

                    $Results.ScenarioName = $snario
                    $Results.Status = "Skipped"
                    $Results.ReasonForNotPass = $reasonForNotPass
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
   $Results.AvgProcessingTimePerFrame =$null
   $Results.MaxProcessingTimePerFrame =$null
   $Results.MinProcessingTimePerFrame =$null
   $Results.PCInItTime = $null
   $Results.CameraAppInItTime = $null
   $Results.VoiceRecorderInItTime = $null
   $Results.fps = $null
   $Results.PCInItTimeForAudio = $null
   $Results.FramesAbove33msForAudioBlur = $null
   $Results.Status = $null
   $Results.ReasonForNotPass = $null
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
   Write-output $rslt >> $outputfile
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
      Write-Log -Message "$functionToCall -logFile $logFile $token $SPId -camsnario $camsnario -vdoRes $vdoRes -ptoRes $ptoRes -devPowStat $devPowStat -toggleEachAiEffect $togAiEfft >> `$pathLogsFolder\CameraAppTest.txt" -IsOutput >> $pathLogsFolder\ReRunFailedTests.ps1
      Write-Log -Message $failedTests -IsOutput >> $pathLogsFolder\failedTests.txt
   }
   else
   {
      Write-Log -Message $failedTests -IsOutput >> $pathLogsFolder\failedTests.txt
   }
}