#Pre-requisite for hibernation.
#Setup wake timers- Open control panel>Power options>"Edit Plan setting" for the power plan u are using. Then Select "Change adavanced power setting". Go to Sleep > "Allow wake timers" and enable them
#For Auto-login- Open Edit group policy>Click Administrative Templates> System > Power Management> Sleep Settings > Disable "Require a password when a computer wakes(plugged in) and "Require a password when a computer wakes(on battery)
function Hibernation()
{  
   Write-Output "Entering Hibernation function"   
   $time = Get-Date
   $time=$time.AddMinutes(5)
   $time
   $actions = New-ScheduledTaskAction -Execute 'notepad.exe'
   $trigger = New-ScheduledTaskTrigger -Once -At $time
   $principal = New-ScheduledTaskPrincipal -UserId "$Env:ComputerName\$Env:UserName" -RunLevel Highest 
   $settings = New-ScheduledTaskSettingsSet -WakeToRun
   $task = New-ScheduledTask -Action $actions -Principal $principal -Trigger $trigger -Settings $settings
   Register-ScheduledTask 'hiber' -InputObject $task -User $Env:UserName
   shutdown /h 

   #After Auto-login, sending enter key to wake up the device from black screen
   $wshell = New-Object -ComObject wscript.shell;
   $wshell.AppActivate('title of the application window')
   start-sleep -s 1
   $wshell.SendKeys('Enter')

   #Wait for 20 secs before going into hibernation again
   Start-Sleep -s 20
   
   #Close notepad
   CloseApp 'Notepad'

   #Entering DeleteScheduledTask function to delete task after hibernation completes
   DeleteScheduledTask 
   
   [console]::beep(500,300)
}
function DeleteScheduledTask()
{  
   Write-Output "Entering DeleteScheduledTask function"   
   $task = Get-ScheduledTask | Where-Object {$_.TaskName -eq "hiber"} | Select-Object -First 1    
   if($task -ne $null)
   {
      Unregister-ScheduledTask $task.TaskName -Confirm:$false
   } 
   else
   {
      Write-Error "Scheduled task doesn't exist." -ErrorAction Stop
   } 
}

#Verify each starting.Microsoft.ASG.Perception.provider has stopping.Microsoft.ASG.Perception.provider ending with same provider ID
function VerifyLogs-Hibernation($snarioName)
{  
   GenericError $snarioName
   $pathAsgTraceTxt = "$pathLogsFolder\$snarioName\" + "AsgTrace.txt"
   $pathAsgTraceLogs = resolve-path $pathAsgTraceTxt
   if($pathAsgTraceTxt -eq $null)
   {
      Write-Error "$pathAsgTraceTxt not found " -ErrorAction Stop 
   }
   $pattern1 = ",.starting.Microsoft.ASG.Perception.provider.*"
   $pattern2 = ",.stopping.Microsoft.ASG.Perception.provider.*"
   $wsev2PolicyState = CheckWSEV2Policy
   if($wsev2PolicyState -eq $false)
   {
      $pattern3 = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.81968\,.*"
   }
   else
   {
      $pattern3 = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.737312\,.*"
   }
   $pattern4 = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.81936\,.*"
   $pattern5 = "::PerceptionSessionUsageStats.*PerceptionCore-.*,.512\,.*"

   #Select all pattern with starting.Microsoft.ASG.Perception.provider and assign to array variable
   $startingLogs = @(Select-string -path $pathAsgTraceTxt -Pattern $pattern1)
   if($startingLogs -eq $null)
   {
      Write-Error "$pattern1 not found" -ErrorAction Stop 
   }
      
   #Select all pattern with stopping.Microsoft.ASG.Perception.provider and assign to array variable 
   $stoppingLogs = @(Select-string -path $pathAsgTraceTxt -Pattern $pattern2)

   #Validate starting and stopping logs has same count
   if($startingLogs.Count -ne $stoppingLogs.Count)
   {
      Write-Host "Starting and Stopping logs count are not equal" -ForegroundColor Yellow
   } 
   For($i=0; $i -lt $startingLogs.Count; $i++) 
   {
      if ($startingLogs[$i] -ne $null)
      {  
         #Extract starting.Microsoft.ASG.Perception.provider and ID for each array
         $splitStartingLogs = $startingLogs[$i] -split ","
         $startingPerceptionProviderID = $splitStartingLogs[-1] -split " " , 5 | Select-Object -Last 1
         
         #Extract stopping.Microsoft.ASG.Perception.provider and ID for each array
         $splitStoppingLogs = $stoppingLogs[$i] -split ","
         $stoppingPerceptionProviderID = $splitStoppingLogs[-1] -split " " , 5 | Select-Object -Last 1

         #Match provider ID for starting and stopping logs
         if($startingPerceptionProviderID -eq $stoppingPerceptionProviderID)
         {
            Write-Host "Starting:${startingPerceptionProviderID} and Stopping:${stoppingPerceptionProviderID} logs matched" -ForegroundColor Green
         }
         else
         {
            Write-Host  "Starting:${startingPerceptionProviderID} and Stopping:${stoppingPerceptionProviderID} logs NOT matched" -ForegroundColor Yellow
         }

          #Validate targeted scenarioID after each cycle of hibernation
          $file = Get-Content $pathAsgTraceTxt 
          $firstString = $splitStartingLogs[-1]
          $secondString = $splitStoppingLogs[-1]
          
          #Regex pattern to compare two strings
          $logsBetweenStrings = "$firstString(.*?)$secondString"
         
          #Perform the opperation and store the logs between starting and stopping in result variable
          $result = [regex]::Match($file,$logsBetweenStrings).Groups[1].Value
          if($result.length -ne 0)
          {
             #Check if scenario id is present within Starting and Stopping logs
             if($snarioName -eq "$devPowStat\VoiceRecorderAppHibernation")
             {
                $scenarioIDMatch = $result | Select-String -Pattern $pattern5
                if($scenarioIDMatch -eq $null)
                {
                   Write-host "Scenario ID 512 not found .Logs saved here:$pathAsgTraceLogs" -ForegroundColor Red
                }
                else
                {
                   Write-host "ScenarioID $pattern5 found"
                }
             }
             else
             {
                $scenarioIDMatch = $result | Select-String -Pattern $pattern3 
                if($scenarioIDMatch -eq $null)
                {  
                   $scenarioIDMatch = $result | Select-String -Pattern $pattern4
                   if($scenarioIDMatch -eq $null)
                   {  
                      Write-host "Scenario ID 81968 or 81936 not found. Logs saved here:$pathAsgTraceLogs" -ForegroundColor Red
                   }
                   else
                   {
                      Write-host "ScenarioID $pattern4 found"
                   }
                   
                 }
                 else
                 {
                    Write-host "ScenarioID $pattern3 found"
                 }
             }
          }
          else
          {
             Write-Host "Incomplete Asgtrace generated" -ForegroundColor Red
          }   
             
      }
      #Once the array for starting.Microsoft.ASG.Perception.provider is empty, Print below. 
      else 
      {
         write-host "Logs ended for starting.Microsoft.ASG.Perception.provider"
      }
   }
} 
function GenericError($snarioName)
{
   $pathAsgTraceTxt = "$pathLogsFolder\$snarioName\" + "AsgTrace.txt"
   $pathAsgTraceLogs = resolve-path $pathAsgTraceTxt
   if($pathAsgTraceTxt -eq $null)
   {
      Write-Error "$pathAsgTraceTxt not found " -ErrorAction Stop 
   }
   $pattern = "GenericError"

   #Filter logs with GenericError
   $genericErrorLogs = @(Select-String -path $pathAsgTraceTxt -Pattern $pattern)
   For($i= 1 ; $i -lt $genericErrorLogs.Count ; $i++)
   {
      $commaSeperated = $genericErrorLogs[$i] -split ","
      $errorMessage = $commaSeperated[8].Trim()
      $errorMessage1 = $commaSeperated[9].Trim()
      if($errorMessage -eq "Orientation sensor hardware not detected")
      {  
         continue;
      }
      else
      {
         write-host "GenericError - $errorMessage $errorMessage1" -BackgroundColor Red
         write-Output "GenericError - $errorMessage $errorMessage1" >> $pathLogsFolder\ConsoleResults.txt

      }
   }
}





