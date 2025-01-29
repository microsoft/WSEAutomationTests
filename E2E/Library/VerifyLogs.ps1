function VerifyLogs($snarioName, $snarioId, $strtTime)
{  
   $pathAsgTraceTxt = "$pathLogsFolder\$snarioName\" + "AsgTrace.txt"
   Write-Output "Validating AsgTrace.txt logs"
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
          $minProcessingTimePerFrame = [math]::round(($frameProcessingDetails[12]/1000000),2)
          $avgProcessingTimePerFrame = [math]::round(($frameProcessingDetails[11]/1000000),2)
          $maxProcessingTimePerFrame = [math]::round(($frameProcessingDetails[13]/1000000),2)

                 
          #Write the frame processing time details to the log file
          Write-Output "NumberOfFramesAbove33ms: $numberOfFramesAbove33ms, MinProcessingTimePerFrame:${minProcessingTimePerFrame}ms, AvgProcessingTimePerFrame: ${avgProcessingTimePerFrame}ms, MaxProcessingTimePerFrame: ${maxProcessingTimePerFrame}ms"

          $Results.ScenarioName = $snarioName
          $Results.FramesAbove33ms = $numberOfFramesAbove33ms
          $Results.AvgProcessingTimePerFrame = "${avgProcessingTimePerFrame}ms"
          $Results.MaxProcessingTimePerFrame = "${maxProcessingTimePerFrame}ms"
          $Results.MinProcessingTimePerFrame = "${minProcessingTimePerFrame}ms"
          
          CheckInitTimePCOnly $snarioName $snarioId

          #check if numberOfFramesAbove33ms is greater than 0
          if ( $numberOfFramesAbove33ms -gt 0 )
          {   
             #Prints to the console if numberOfFramesAbove33ms is greater than 0
             Write-Host "   NumberOfFramesAbove33ms:$numberOfFramesAbove33ms [${minProcessingTimePerFrame}ms, ${avgProcessingTimePerFrame}ms, ${maxProcessingTimePerFrame}ms] " -ForegroundColor Yellow
             Write-Host "   AsgTraceLog saved here: $pathAsgTraceLogs"
             Write-Output "NumberOfFramesAbove33ms:$numberOfFramesAbove33ms [${minProcessingTimePerFrame}ms, ${avgProcessingTimePerFrame}ms, ${maxProcessingTimePerFrame}ms]" >> $pathLogsFolder\ConsoleResults.txt
             Write-Output "AsgTraceLog saved here: $pathAsgTraceLogs" >> $pathLogsFolder\ConsoleResults.txt
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
         Write-Host "[ScenarioID:$snarioId] was not found. Logs saved at $pathAsgTraceLogs"
         Write-Output "[ScenarioID:$snarioId] was not found. Logs saved at $pathAsgTraceLogs" >> $pathLogsFolder\ConsoleResults.txt
      }
   }
   else
   {
      Write-Error "$pathAsgTraceTxt not found " -ErrorAction Stop 
   }
       
}

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
      Write-host "   No log for - starting Microsoft.ASG.Perception found for Scenario ID $snarioId. Logs are saved here: $pathAsgTraceLogs " -ForegroundColor Yellow
      Write-Output "No log for - starting Microsoft.ASG.Perception found for Scenario ID $snarioId. Logs are saved here: $pathAsgTraceLogs " >> $pathLogsFolder\ConsoleResults.txt
      return $false
   }
          
}
function CheckInitTimePCOnly($snarioName, $snarioId)
{  
   $PCStartandFirstFrameTime = PCStartandFirstFrameTime $snarioName $snarioId
   if($PCStartandFirstFrameTime -eq $false)
   {
      Write-Host "   No match found for PC Time To First Frame for Scenario $snarioId. Logs are saved here: $pathAsgTraceLogs" -ForegroundColor Yellow
      Write-Output "   No match found for PC Time To First Frame for Scenario $snarioId. Logs are saved here: $pathAsgTraceLogs"  >> $pathLogsFolder\ConsoleResults.txt
   }
   else
   { 
      $PCStartTime = $PCStartandFirstFrameTime[0]
      $PCFirstFrameTime = $PCStartandFirstFrameTime[1]
      
      #calculate time PC trace started until PC trace reported first frame processed
      $InitTimePCOnly = [math]::round((New-TimeSpan -Start $PCStartTime -End $PCFirstFrameTime).TotalSeconds,4)
      if($snarioId -eq "512")
      {  
         Write-Output "PC Time To First Frame: ${InitTimePCOnly}secs"
         $Results.PCInItTimeForAudio = "${InitTimePCOnly}sec"
      }
      else
      {
         Write-Output "PC Time To First Frame: ${InitTimePCOnly}secs"
         $Results.PCInItTime = "${InitTimePCOnly}sec"
      } 
      
   }
}
function CheckInitTimeCameraApp($snarioName, $snarioId, $camAppStatTme)
{  
   $PCStartandFirstFrameTime = PCStartandFirstFrameTime $snarioName $snarioId
   if($PCStartandFirstFrameTime -ne $false)
   { 
      $PCFirstFrameTime = $PCStartandFirstFrameTime[1]  
      
      #calculate Time from camera app started until PC trace first frame processed
      $InitTimeCameraApp = [math]::round((New-TimeSpan -Start $camAppStatTme -End $PCFirstFrameTime).TotalSeconds,4)
      Write-Output "Time from camera app started until PC trace first frame processed: ${InitTimeCameraApp}secs"
      $Results.CameraAppInItTime = "${InitTimeCameraApp}sec"
   }      
}
function CheckInitTimeVoiceRecorderApp($snarioName, $snarioId , $voiceRecderAppStatTme, $audioRecdingStatTme)
{  
   $PCStartandFirstFrameTime = PCStartandFirstFrameTime $snarioName $snarioId
   if($PCStartandFirstFrameTime -ne $false)
   { 
      $PCFirstFrameTime = $PCStartandFirstFrameTime[1]  
      
      #calculate Time from voiceRecorder app started until PC trace first frame processed
      $InitTimeFromVoiceRecorderAppStarts = [math]::round((New-TimeSpan -Start $voiceRecderAppStatTme -End $PCFirstFrameTime).TotalSeconds,4)
      Write-Output "Time from voiceRecorder app started until PC trace first frame processed: ${InitTimeFromVoiceRecorderAppStarts}secs"
      
      #calculate Time from Record button was pressed until PC trace first frame processed
      $InitTimeFromAudioRecordingStarts = [math]::round((New-TimeSpan -Start $audioRecdingStatTme -End $PCFirstFrameTime).TotalSeconds,4)
      Write-Output "Time from record button was pressed until PC trace first frame processed: ${InitTimeFromAudioRecordingStarts}secs"
      $Results.VoiceRecorderInItTime = "${InitTimeFromAudioRecordingStarts}sec"
   }     
}
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

      Write-Output "Validating AsgTrace.txt logs for Audio Blur"
      if (Test-path -Path $pathAsgTraceTxt)
      {
         $pathAsgTraceLogs = resolve-path $pathAsgTraceTxt
         #Find Usage line with desired scenario ID
         $pattern = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.$snarioId\,.*"
         $frameProcessingDetails = (Select-string -path $pathAsgTraceTxt -Pattern $pattern | Select-Object -Last 1) -split ","
         if ($frameProcessingDetails.Count -gt 20)
         {             
             #Prints for specific scenario as proper scenarioID was found.
             Write-Output "Audio blur scenarioID - $snarioId found."

             CheckInitTimePCOnly $snarioName $snarioId
                          
             #Reading log file to get frames Processing time details
             $numberOfFramesAbove33msforAudioBlur = $frameProcessingDetails[20].Trim()
             $minProcessingTimePerFrameforAudioBlur = [math]::round(($frameProcessingDetails[12]/1000000),2)
             $avgProcessingTimePerFrameforAudioBlur = [math]::round(($frameProcessingDetails[11]/1000000),2)
             $maxProcessingTimePerFrameforAudioBlur = [math]::round(($frameProcessingDetails[13]/1000000),2)
             Write-Output "NumberOfFramesAbove33msforAudioBlur: $numberOfFramesAbove33msforAudioBlur, MinProcessingTimePerFrameforAudioBlur:${minProcessingTimePerFrameforAudioBlur}ms, AvgProcessingTimePerFrameforAudioBlur: ${avgProcessingTimePerFrameforAudioBlur}ms, MaxProcessingTimePerFrameforAudioBlur: ${maxProcessingTimePerFrameforAudioBlur}ms"
             
             $Results.FramesAbove33msForAudioBlur = $numberOfFramesAbove33msforAudioBlur

             if ( $numberOfFramesAbove33msforAudioBlur -gt 0 )
             {   
                #Prints to the console if numberOfFramesAbove33ms is greater than 0
                Write-Host "   NumberOfFramesAbove33msForAudioBlur:$numberOfFramesAbove33msforAudioBlur [${minProcessingTimePerFrameforAudioBlur}ms, ${avgProcessingTimePerFrameforAudioBlur}ms, ${maxProcessingTimePerFrameforAudioBlur}ms] " -ForegroundColor Yellow
                Write-Host "   AsgTraceLog saved here: $pathAsgTraceLogs"
                Write-Output "NumberOfFramesAbove33msforAudioBlur:$numberOfFramesAbove33msforAudioBlur [${minProcessingTimePerFrameforAudioBlur}ms, ${avgProcessingTimePerFrameforAudioBlur}ms, ${maxProcessingTimePerFrameforAudioBlur}ms]" >> $pathLogsFolder\ConsoleResults.txt
                Write-Output "AsgTraceLog saved here: $pathAsgTraceLogs" >> $pathLogsFolder\ConsoleResults.txt
             } 

         
         }
         else
         {
            #Prints scenarioID was not found for Audio Blur.  
            Write-Host "   [ScenarioID:$snarioId] was not found.`n   AsgTraceLog saved here: $pathAsgTraceLogs" -ForegroundColor Red
            Write-Output "[ScenarioID:$snarioId] was not found. Test is marked as Pass as Camera effects ScenarioID was found AsgTraceLog saved here: $pathAsgTraceLogs" >> $pathLogsFolder\ConsoleResults.txt
            $Results.ReasonForNotPass = "[ScenarioID:$snarioId] was not found.Test is marked as Pass as Camera effects ScenarioID was found "

         }  
      }
      else
      {
         return
      }       
    }  
}
#Checks for PrivateUsage, PeakWorkingSetSize, PageFaultCount, AvgWorkingSetSize
function CheckMemoryUsage($snarioName)
{  
   $pathAsgTraceTxt = "$pathLogsFolder\$snarioName\" + "AsgTrace.txt"
   Write-Output "Validating AsgTrace.txt logs for memory Usage"
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
                
         Write-Output "PrivateUsage:${privateUsage}MBs, PeakWorkingSetSize:${peakWorkingSetSize}MBs, PageFaultCount:${pageFaultCount} , AvgWorkingSetSize:${avgWorkingSetSize}MBs"
          
         #Print error if the average working set size is greater than 250MBs
         if ( $avgWorkingSetSize -ge 250 )
         {   
            #Prints to the console if $avgWorkingSetSize is greater than or equal to 250MBs
            Write-Host "   AvgWorkingSetSize is greater than 250MBs [PrivateUsage:${privateUsage}MBs, PeakWorkingSetSize:${peakWorkingSetSize}MBs, PageFaultCount:${pageFaultCount} , AvgWorkingSetSize:${avgWorkingSetSize}MBs] " -BackgroundColor Red
            Write-Host "   AsgTraceLog saved here: $pathAsgTraceLogs"
            Write-Output "   AvgWorkingSetSize is greater than 250MBs[PrivateUsage:${privateUsage}MBs, PeakWorkingSetSize:${peakWorkingSetSize}MBs, PageFaultCount:${pageFaultCount} , AvgWorkingSetSize:${avgWorkingSetSize}MBs] "  >> $pathLogsFolder\ConsoleResults.txt
            Write-Output "AsgTraceLog saved here: $pathAsgTraceLogs" >> $pathLogsFolder\ConsoleResults.txt
         }
         $i++
      }
          
   }
   else
   {
      Write-Error "$pathAsgTraceTxt not found " -ErrorAction Stop 
   }
       
}
