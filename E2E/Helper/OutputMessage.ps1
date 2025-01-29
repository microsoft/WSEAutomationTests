# Install Import-Excel module (if not already installed)
Install-Module -Name ImportExcel -Force -Scope CurrentUser

function TestOutputMessage($snario, $tstReslt, $strtTime, $reasonForNotPass)
{
    $Global:sequenceNumber++
    $currNum = $Global:sequenceNumber.ToString() + "."
    $endTime = Get-Date
    $totalExecutionTimeInSeconds = [math]::round((New-TimeSpan -Start $strtTime -End $endTime).TotalSeconds,2)
    switch ($tstReslt)
    {
        "Pass" {
                  Write-Host -NoNewline "$currNum ${snario}: "; Write-host -NoNewline "Passed " -ForegroundColor Green; Write-Host "(${totalExecutionTimeInSeconds}s)"
                  write-output "$currNum ${snario}:Passed (${totalExecutionTimeInSeconds}s)" >> $pathLogsFolder\ConsoleResults.txt
                  $Results.Status = "Pass"
                  $Results.ReasonForNotPass = $null
               }
        "Fail" {
                 Write-Host -NoNewline "$currNum ${snario}: "; Write-host -NoNewline "Failed " -ForegroundColor Red; Write-Host "(${totalExecutionTimeInSeconds}s)"
                 AddToFailedTestsList "$currNum ${snario}"
                 write-output "$currNum ${snario}:Failed (${totalExecutionTimeInSeconds}s)" >> $pathLogsFolder\ConsoleResults.txt
                 
                 # Reseting all field values to empty for failed case scenario exception for Status and ReasonForNotPass
                 ResetFields

                 $Results.ScenarioName = $snario
                 $Results.Status = "Fail"
                 $Results.ReasonForNotPass = $reasonForNotPass
               }

               
        "Exception" {
                       Write-Host -NoNewline "$currNum ${snario}: "; Write-host -NoNewline "Failed " -ForegroundColor Red; Write-Host  "(${totalExecutionTimeInSeconds}s)"
                       AddToFailedTestsList "$currNum ${snario}"
                       write-output "$currNum ${snario}:Failed(Exception) (${totalExecutionTimeInSeconds}s)" >> $pathLogsFolder\ConsoleResults.txt

                       # Reseting all field values to empty for Exception case scenario exception for Status and ReasonForNotPass
                       ResetFields
                       
                       $Results.ScenarioName = $snario
                       $Results.Status = "Exception"
                       $Results.ReasonForNotPass = $reasonForNotPass
                    }
                 
                    
        "Skipped"{
                    Write-Host -NoNewline "$currNum ${snario}: "; Write-host -NoNewline "Skipped " -ForegroundColor Yellow; Write-Host  "(${reasonForNotPass})" "(${totalExecutionTimeInSeconds}s)"
                    write-output "$currNum ${snario}:Skipped (${reasonForNotPass})(${totalExecutionTimeInSeconds}s)" >> $pathLogsFolder\ConsoleResults.txt

                    # Reseting all field values to empty for skipped case scenario exception for Status and ReasonForNotPass
                    ResetFields

                    $Results.ScenarioName = $snario
                    $Results.Status = "Skipped"
                    $Results.ReasonForNotPass = $reasonForNotPass
                 }
                 
    }
}

function ResetFields {
   $Results.ScenarioName = $null
   $Results.FramesAbove33ms = $null
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

function Reporting($rslt, $outputfile)
{
   Write-output $rslt >> $outputfile
   ResetFields
}

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
                  Write-Host "Warning: Line does not match expected format: $_" -ForegroundColor Yellow
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
       Write-host "   Report generated here:$excelFilePath"
   } 
   else
   {
       Write-Host "Error: The content of the Report text file is null or empty." -ForegroundColor Red
   }
}
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
   $togAiEfft = $splitEachTests[5]
   $token = "111222"
   $SPID ="333444"
   if($functionToCall -eq  "CameraAppTest")
   {
      write-output "$functionToCall -logFile $logFile $token $SPId -camsnario $camsnario -vdoRes $vdoRes -ptoRes $ptoRes -devPowStat $devPowStat -toggleEachAiEffect $togAiEfft >> `$pathLogsFolder\CameraAppTest.txt" >> $pathLogsFolder\ReRunFailedTests.ps1
      write-output $failedTests >> $pathLogsFolder\failedTests.txt
   }
   else
   {
      write-output $failedTests >> $pathLogsFolder\failedTests.txt
   }
}
