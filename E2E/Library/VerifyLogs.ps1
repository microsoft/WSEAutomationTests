<#
DESCRIPTION:
    This function verifies PerceptionSessionUsageStats logs for a given scenario. It checks for 
    specific scenario IDs, validates frame processing times, and logs results. It also verifies 
    memory usage events if present.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for organizing and locating logs.
    - snarioId [string] :- The scenario ID used to identify specific log entries.
    - strtTime [datetime] :- The start time of the scenario, used for calculating durations.
RETURN TYPE:
    - void (Performs validation and logging without returning a value.)
#>
function VerifyLogs($snarioName, $snarioId, $strtTime)
{  
   $pathAsgTraceTxt = "$pathLogsFolder\$snarioName\" + "AsgTrace.txt"
   Write-Log -Message "Validating AsgTrace.txt logs" -IsOutput
   if (Test-path -Path $pathAsgTraceTxt) 
   {   
      $pathAsgTraceLogs = resolve-path $pathAsgTraceTxt

      #Find Usage line with desired scenario ID
      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.$snarioId\,.*"
      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
      if(($frameProcessingDetails.count -eq 0) -and ($snarioId -eq "96"  -or "16416" -or "65632" -or "81952" -or "112" -or "16432" -or "65648" -or "81968"))
      {

         switch ($snarioId)
         {
            "96"  {
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.64\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                  }
            "16416"{
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.16384\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
            
            "65632"{
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.65600\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
            "81952"{
                       $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.81920\,.*"
                       $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
            "112"  {
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.80\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
            "16432"{
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.16400\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
            "65648"{
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.65616\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
            "81968"{
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.81936\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
         }
      }
      else 
      {    
          $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
      }     
      if ($frameProcessingDetails.Count -gt 20)
      {             
          #Prints Test Passed for specific scenario as proper scenarioID was found.
          TestOutputMessage $snarioName "Pass" $strtTime
          GenericError $snarioName
          
          #Reading log file to get frames Processing time details
          $numberOfFramesAbove33ms = $frameProcessingDetails[20].Trim()
		  $totalnoOfFrames = $frameProcessingDetails[9].Trim()
          $minProcessingTimePerFrame = [math]::round(($frameProcessingDetails[12]/1000000),2)
          $avgProcessingTimePerFrame = [math]::round(($frameProcessingDetails[11]/1000000),2)
          $maxProcessingTimePerFrame = [math]::round(($frameProcessingDetails[13]/1000000),2)

                 
          #Write the frame processing time details to the log file
          Write-Log -Message "NumberOfFramesAbove33ms: $numberOfFramesAbove33ms, MinProcessingTimePerFrame: ${minProcessingTimePerFrame}ms, AvgProcessingTimePerFrame: ${avgProcessingTimePerFrame}ms, MaxProcessingTimePerFrame: ${maxProcessingTimePerFrame}ms" -IsOutput

          $Results.ScenarioName = $snarioName
          $Results.FramesAbove33ms = $numberOfFramesAbove33ms
		  $Results.TotalNumberOfFrames = $totalnoOfFrames
		  $Results.AvgProcessingTimePerFrame = "${avgProcessingTimePerFrame}ms"
          $Results.MaxProcessingTimePerFrame = "${maxProcessingTimePerFrame}ms"
          $Results.MinProcessingTimePerFrame = "${minProcessingTimePerFrame}ms"
          
          CheckInitTimePCOnly $snarioName $snarioId

          #check if numberOfFramesAbove33ms is greater than 0
          if ( $numberOfFramesAbove33ms -gt 0 )
          {   
             #Prints to the console if numberOfFramesAbove33ms is greater than 0
             Write-Log -Message "   NumberOfFramesAbove33ms:$numberOfFramesAbove33ms [${minProcessingTimePerFrame}ms, ${avgProcessingTimePerFrame}ms, ${maxProcessingTimePerFrame}ms] " -IsHost -ForegroundColor Yellow
             Write-Log -Message "NumberOfFramesAbove33ms:$numberOfFramesAbove33ms [${minProcessingTimePerFrame}ms, ${avgProcessingTimePerFrame}ms, ${maxProcessingTimePerFrame}ms]" -IsOutput >> $pathLogsFolder\ConsoleResults.txt
             Write-Log -Message "AsgTraceLog saved here: $pathAsgTraceLogs" -IsHost -IsOutput >> $pathLogsFolder\ConsoleResults.txt

          }
        
          #As memory usage event are added on recent PC version. $frameProcessingDetails.count>32 validates memory usage events are present in PerceptionSessionUsageStats traces.
          if ($frameProcessingDetails.Count -gt 32)
          {
             CheckMemoryUsage $snarioName
          }  
          
      }
      else
      {
         #Prints Test failed for specific scenario as proper scenarioID was not found.  
         TestOutputMessage $snarioName "Fail" $strtTime "[ScenarioID:$snarioId] was not found."
         Write-Log -Message "[ScenarioID:$snarioId] was not found. Logs saved at $pathAsgTraceLogs" -IsHost -IsOutput >> "$pathLogsFolder\ConsoleResults.txt"
      }
   }
   else
   {
      Write-Error "$pathAsgTraceTxt not found " -ErrorAction Stop 
   }
 
}

<#
DESCRIPTION:
    This function retrieves the start and first frame processing times from PerceptionSessionUsageStats
    logs for a given scenario ID.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for locating relevant logs.
    - snarioId [string] :- The scenario ID used to filter log entries.
RETURN TYPE:
    - array (Returns an array containing the start time and first frame time if found, otherwise returns $false.)
#>
function PCStartandFirstFrameTime($snarioName, $snarioId)
{
   $pathAsgTraceTxt = "$pathLogsFolder\$snarioName\" + "AsgTrace.txt"
   $pathAsgTraceLogs = resolve-path $pathAsgTraceTxt
  
   #Find Usage line with desired scenario ID
   $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.$snarioId\,.*"
   $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
          if(($frameProcessingDetails.count -eq 0) -and ($snarioId -eq "96"  -or "16416" -or "65632" -or "81952" -or "112" -or "16432" -or "65648" -or "81968"))
      {

         switch ($snarioId)
         {
            "96"  {
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.64\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                  }
            "16416"{
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.16384\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
            
            "65632"{
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.65600\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
            "81952"{
                       $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.81920\,.*"
                       $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
            "112"  {
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.80\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
            "16432"{
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.16400\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
            "65648"{
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.65616\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
            "81968"{
                      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.81936\,.*"
                      $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
                   }
         }
      }
   else 
   {    
       $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
   }     
   if($frameProcessingDetails.length -eq 0)
   {
      return $false
   }

   #Extract process id from Usage line
   $processIdToMatch = $frameProcessingDetails[1] -replace  "[^0-9]" , ''
   
   #Find "starting Microsoft.ASG.Perception" line with mentioned process id
   $pattern1 = "<Unknown>..$processIdToMatch.,.*,.starting Microsoft.ASG.Perception"
   $PCStartTime = (Select-string -path $pathAsgTraceTxt -Pattern $pattern1) -split ","
   if($PCStartTime -ne $null)
   {
      #Find "First frame for PerceptionCore" line with mentioned process id
      $pattern2  = "<Unknown>..$processIdToMatch.,.*,.First frame for PerceptionCore"
      $PCFirstFrameTime = (Select-string -path $pathAsgTraceTxt -Pattern $pattern2) -split ","
      if($PCFirstFrameTime -ne $null)
      {   
         return $PCStartTime[3],$PCFirstFrameTime[3]
      }
      else
      {
         return $false
      }
   }
   else
   {
      Write-Log -Message "   No log for - starting Microsoft.ASG.Perception found for Scenario ID $snarioId. Logs are saved here: $pathAsgTraceLogs " -IsHost -ForegroundColor Yellow
      Write-Log -Message "No log for - starting Microsoft.ASG.Perception found for Scenario ID $snarioId. Logs are saved here: $pathAsgTraceLogs" -IsOutput >> "$pathLogsFolder\ConsoleResults.txt"
      return $false
   }
          
}

<#
DESCRIPTION:
    This function calculates and logs the initialization time from the start of the perception core
    to the first processed frame for a given scenario.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for locating relevant logs.
    - snarioId [string] :- The scenario ID used to filter log entries.
RETURN TYPE:
    - void (Calculates and logs initialization time without returning a value.)
#>
function CheckInitTimePCOnly($snarioName, $snarioId)
{  
   $PCStartandFirstFrameTime = PCStartandFirstFrameTime $snarioName $snarioId
   if($PCStartandFirstFrameTime -eq $false)
   {
      Write-Log -Message "   No match found for PC Time To First Frame for Scenario $snarioId. Logs are saved here: $pathAsgTraceLogs" -IsHost -ForegroundColor Yellow
      Write-Log -Message "No match found for PC Time To First Frame for Scenario $snarioId. Logs are saved here: $pathAsgTraceLogs" -IsOutput >> "$pathLogsFolder\ConsoleResults.txt"
   }
   else
   { 
      $PCStartTime = $PCStartandFirstFrameTime[0]
      $PCFirstFrameTime = $PCStartandFirstFrameTime[1]
      
      #calculate time PC trace started until PC trace reported first frame processed
      $InitTimePCOnly = [math]::round((New-TimeSpan -Start $PCStartTime -End $PCFirstFrameTime).TotalSeconds,4)
      if($snarioId -eq "512")
      {  
         Write-Log -Message "PC Time To First Frame: ${InitTimePCOnly}secs" -IsOutput
         $Results.PCInItTimeForAudio = "${InitTimePCOnly}sec"
      }
      else
      {
         Write-Log -Message "PC Time To First Frame: ${InitTimePCOnly}secs" -IsOutput
         $Results.PCInItTime = "${InitTimePCOnly}sec"
      } 
      
   }
}

<#
DESCRIPTION:
    This function calculates and logs the initialization time from when the camera app starts 
    until the first frame is processed.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for locating relevant logs.
    - snarioId [string] :- The scenario ID used to filter log entries.
    - camAppStatTme [datetime] :- The timestamp when the camera app was started.
RETURN TYPE:
    - void (Calculates and logs initialization time without returning a value.)
#>
function CheckInitTimeCameraApp($snarioName, $snarioId, $camAppStatTme)
{  
   $PCStartandFirstFrameTime = PCStartandFirstFrameTime $snarioName $snarioId
   if($PCStartandFirstFrameTime -ne $false)
   { 
      $PCFirstFrameTime = $PCStartandFirstFrameTime[1]  
      
      # Calculate Time from camera app started until PC trace first frame processed
      $InitTimeCameraApp = [math]::round((New-TimeSpan -Start $camAppStatTme -End $PCFirstFrameTime).TotalSeconds,4)
      
      Write-Log -Message "Time from camera app started until PC trace first frame processed: ${InitTimeCameraApp}secs" -IsOutput
      $Results.CameraAppInItTime = "${InitTimeCameraApp}sec"
   }      
}

<#
DESCRIPTION:
    This function calculates and logs the initialization times for the voice recorder app:
    from when the app starts and from when the recording begins until the first frame is processed.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for locating relevant logs.
    - snarioId [string] :- The scenario ID used to filter log entries.
    - voiceRecderAppStatTme [datetime] :- The timestamp when the voice recorder app was started.
    - audioRecdingStatTme [datetime] :- The timestamp when the audio recording was started.
RETURN TYPE:
    - void (Calculates and logs initialization times without returning a value.)
#>
function CheckInitTimeVoiceRecorderApp($snarioName, $snarioId , $voiceRecderAppStatTme, $audioRecdingStatTme)
{  
   $PCStartandFirstFrameTime = PCStartandFirstFrameTime $snarioName $snarioId
   if($PCStartandFirstFrameTime -ne $false)
   { 
      $PCFirstFrameTime = $PCStartandFirstFrameTime[1]  
      
      # Calculate Time from voiceRecorder app started until PC trace first frame processed
      $InitTimeFromVoiceRecorderAppStarts = [math]::round((New-TimeSpan -Start $voiceRecderAppStatTme -End $PCFirstFrameTime).TotalSeconds,4)
      Write-Log -Message "Time from voiceRecorder app started until PC trace first frame processed: ${InitTimeFromVoiceRecorderAppStarts}secs" -IsOutput
      
      # Calculate Time from Record button was pressed until PC trace first frame processed
      $InitTimeFromAudioRecordingStarts = [math]::round((New-TimeSpan -Start $audioRecdingStatTme -End $PCFirstFrameTime).TotalSeconds,4)
      Write-Log -Message "Time from record button was pressed until PC trace first frame processed: ${InitTimeFromAudioRecordingStarts}secs" -IsOutput
      $Results.VoiceRecorderInItTime = "${InitTimeFromAudioRecordingStarts}sec"
   }     
}

<#
DESCRIPTION:
    This function verifies PerceptionSessionUsageStats logs specifically for audio blur scenarios.
    It validates frame processing times and logs results if audio blur is enabled.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for organizing and locating logs.
    - snarioId [string] :- The scenario ID used to identify specific log entries.
RETURN TYPE:
    - void (Performs validation and logging without returning a value.)
#>
function VerifyAudioBlurLogs($snarioName, $snarioId)
{  
   $voiceFocusExists = CheckVoiceFocusPolicy 
   if($voiceFocusExists -eq $false)
   {
      return
   }
   else
   {  
      $pathAsgTraceTxt = "$pathLogsFolder\$snarioName\" + "AsgTrace.txt"

      Write-Log -Message "Validating AsgTrace.txt logs for Audio Blur" -IsOutput
      if (Test-path -Path $pathAsgTraceTxt)
      {
         $pathAsgTraceLogs = resolve-path $pathAsgTraceTxt
         #Find Usage line with desired scenario ID
         $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.$snarioId\,.*"
         $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
         if ($frameProcessingDetails.Count -gt 20)
         {             
             #Prints for specific scenario as proper scenarioID was found.
             Write-Log -Message "Audio blur scenarioID - $snarioId found." -IsOutput

             CheckInitTimePCOnly $snarioName $snarioId
                          
             #Reading log file to get frames Processing time details
             $numberOfFramesAbove33msforAudioBlur = $frameProcessingDetails[20].Trim()
             $minProcessingTimePerFrameforAudioBlur = [math]::round(($frameProcessingDetails[12]/1000000),2)
             $avgProcessingTimePerFrameforAudioBlur = [math]::round(($frameProcessingDetails[11]/1000000),2)
             $maxProcessingTimePerFrameforAudioBlur = [math]::round(($frameProcessingDetails[13]/1000000),2)
             Write-Log -Message "NumberOfFramesAbove33msforAudioBlur: $numberOfFramesAbove33msforAudioBlur, MinProcessingTimePerFrameforAudioBlur:${minProcessingTimePerFrameforAudioBlur}ms, AvgProcessingTimePerFrameforAudioBlur: ${avgProcessingTimePerFrameforAudioBlur}ms, MaxProcessingTimePerFrameforAudioBlur: ${maxProcessingTimePerFrameforAudioBlur}ms" -IsOutput

             $Results.FramesAbove33msForAudioBlur = $numberOfFramesAbove33msforAudioBlur

             if ( $numberOfFramesAbove33msforAudioBlur -gt 0 )
             {   
                #Prints to the console if numberOfFramesAbove33ms is greater than 0
                Write-Log -Message "   NumberOfFramesAbove33msForAudioBlur:$numberOfFramesAbove33msforAudioBlur [${minProcessingTimePerFrameforAudioBlur}ms, ${avgProcessingTimePerFrameforAudioBlur}ms, ${maxProcessingTimePerFrameforAudioBlur}ms] " -IsHost -ForegroundColor Yellow
                Write-Log -Message "NumberOfFramesAbove33msforAudioBlur:$numberOfFramesAbove33msforAudioBlur [${minProcessingTimePerFrameforAudioBlur}ms, ${avgProcessingTimePerFrameforAudioBlur}ms, ${maxProcessingTimePerFrameforAudioBlur}ms]" -IsOutput >> $pathLogsFolder\ConsoleResults.txt
                Write-Log -Message "AsgTraceLog saved here: $pathAsgTraceLogs" -IsHost -IsOutput >> $pathLogsFolder\ConsoleResults.txt
             } 

         
         }
         else
         {
            #Prints scenarioID was not found for Audio Blur.  
            Write-Log -Message "   [ScenarioID:$snarioId] was not found.`n   AsgTraceLog saved here: $pathAsgTraceLogs" -IsHost -ForegroundColor Red
            Write-Log -Message "[ScenarioID:$snarioId] was not found. Test is marked as Pass as Camera effects ScenarioID was found. AsgTraceLog saved here: $pathAsgTraceLogs" -IsOutput >> $pathLogsFolder\ConsoleResults.txt            
            $Results.ReasonForNotPass = "[ScenarioID:$snarioId] was not found.Test is marked as Pass as Camera effects ScenarioID was found "

         }  
      }
      else
      {
         return
      }       
    }  
}

<#
DESCRIPTION:
    This function checks for PrivateUsage, PeakWorkingSetSize, PageFaultCount, AvgWorkingSetSize.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for locating relevant logs.
RETURN TYPE:
    - void (Logs memory usage statistics and highlights high memory usage without returning a value.)
#>
function CheckMemoryUsage($snarioName)
{  
   $pathAsgTraceTxt = "$pathLogsFolder\$snarioName\" + "AsgTrace.txt"
   Write-Log -Message "Validating AsgTrace.txt logs for memory Usage" -IsOutput

   if (Test-path -Path $pathAsgTraceTxt) 
   {   
      $pathAsgTraceLogs = resolve-path $pathAsgTraceTxt

      #Find PerceptionSessionUsageStats for all scenarios.
      $pattern = "::PerceptionSessionUsageStats.*PerceptionCore"
      $frameProcessingDetailsAll = @(Select-string -path $pathAsgTraceTxt -Pattern $pattern)
      $i = 0
      while($i -lt $frameProcessingDetailsAll.count)
      { 
         #Check memory usage for each PerceptionSessionUsageStats
         $frameProcessingDetails = ($frameProcessingDetailsAll[$i]) -split ","
         $privateUsage = ($frameProcessingDetails[29].TrimStart(" {")) /1000000
         $peakWorkingSetSize = ($frameProcessingDetails[30].Trim())/1000000
         $pageFaultCount = $frameProcessingDetails[31].Trim()
         $avgWorkingSetSize = ($frameProcessingDetails[32].TrimEnd("}"))/1000000
         $Results.PeakWorkingSetSize = "${peakWorkingSetSize}MBs"
         $Results.AvgWorkingSetSize = "${avgWorkingSetSize}MBs"
                
         Write-Log -Message "PrivateUsage:${privateUsage}MBs, PeakWorkingSetSize:${peakWorkingSetSize}MBs, PageFaultCount:${pageFaultCount} , AvgWorkingSetSize:${avgWorkingSetSize}MBs" -IsOutput
          
         #Print error if the average working set size is greater than 250MBs
         if ( $avgWorkingSetSize -ge 250 )
         {   
            #Prints to the console if $avgWorkingSetSize is greater than or equal to 250MBs
            Write-Log -Message "AvgWorkingSetSize is greater than 250MBs [PrivateUsage:${privateUsage}MBs, PeakWorkingSetSize:${peakWorkingSetSize}MBs, PageFaultCount:${pageFaultCount}, AvgWorkingSetSize:${avgWorkingSetSize}MBs]" -IsOutput -IsHost -BackgroundColor Red >> $pathLogsFolder\ConsoleResults.txt
            Write-Log -Message "AsgTraceLog saved here: $pathAsgTraceLogs" -IsHost -IsOutput >> $pathLogsFolder\ConsoleResults.txt
         }
         $i++
      }
          
   }
   else
   {
      Write-Error "$pathAsgTraceTxt not found " -ErrorAction Stop 
   }
       
}
