#Pre-requisite for hibernation.
#Setup wake timers- Open control panel>Power options>"Edit Plan setting" for the power plan u are using. Then Select "Change adavanced power setting". Go to Sleep > "Allow wake timers" and enable them
#For Auto-login- Open Edit group policy>Click Administrative Templates> System > Power Management> Sleep Settings > Disable "Require a password when a computer wakes(plugged in) and "Require a password when a computer wakes(on battery)

if (-not (Get-Command Get-TraceFmtProviderStartStopCounts -ErrorAction SilentlyContinue))
{
   $traceFmtLib = Join-Path $PSScriptRoot 'TraceFmtParsing.ps1'
   if (Test-Path -LiteralPath $traceFmtLib) { . $traceFmtLib }
}

<#
DESCRIPTION:
    This function initiates a system hibernation. It schedules a task to wake up the system, 
    performs necessary actions like simulating key presses after waking up, and ensures 
    cleanup by deleting the scheduled task after completion.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - void (Performs hibernation, auto-login, and scheduled task handling without returning a value.)
#>
function Hibernation()
{  
   Write-Log -Message "Entering Hibernation function" -IsOutput  
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

<#
DESCRIPTION:
    This function deletes the scheduled task used for waking up the system after hibernation. 
    It ensures no redundant scheduled tasks exist post-hibernation.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - void (Deletes the scheduled task or raises an error if it doesn't exist.)
#>
function DeleteScheduledTask()
{  
   Write-Log -Message "Entering DeleteScheduledTask function" -IsOutput  
   $task = Get-ScheduledTask | Where-Object {$_.TaskName -eq "hiber"} | Select-Object -First 1    
   if($null -ne $task)
   {
      Unregister-ScheduledTask $task.TaskName -Confirm:$false
   } 
   else
   {
      Write-Error "Scheduled task doesn't exist." -ErrorAction Stop
   } 
}

<#
DESCRIPTION:
   This function verifies each tracefmt "starting Microsoft.ASG.Perception provider <ptr> <id>" has a
   matching "stopping Microsoft.ASG.Perception provider <ptr> <id>" ending with the same provider IDs.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario to validate logs.
RETURN TYPE:
    - void (Performs log validation and reporting without returning a value.)
#>
function VerifyLogs-Hibernation($snarioName)
{  
   GenericError-Hibernation $snarioName

   # Legacy AsgTrace.txt is no longer generated; validate against tracefmt output.
   $pathAsgTraceFmtTxt = "$pathLogsFolder\$snarioName\" + "AsgTraceFmt.txt"
   if (-not (Test-Path -LiteralPath $pathAsgTraceFmtTxt))
   {
      Write-Log -Message "WARN: $pathAsgTraceFmtTxt not found; skipping hibernation log validation." -IsHost -ForegroundColor Yellow
      return
   }

   $counts = Get-TraceFmtProviderStartStopCounts -Path $pathAsgTraceFmtTxt -ProviderName 'Microsoft.ASG.Perception'
   $started = $counts.Started
   $stopped = $counts.Stopped

   if ($started.Count -eq 0)
   {
      Write-Log -Message "No 'starting Microsoft.ASG.Perception provider ...' entries found in $pathAsgTraceFmtTxt" -IsHost -ForegroundColor Yellow
   }

   $providerMismatch = $false
   foreach ($key in $started.Keys)
   {
      $startCount = [int]$started[$key]
      $stopCount = 0
      if ($stopped.ContainsKey($key)) { $stopCount = [int]$stopped[$key] }

      if ($startCount -ne $stopCount)
      {
         $providerMismatch = $true
         Write-Log -Message "Provider start/stop mismatch for [$key]: start=$startCount stop=$stopCount" -IsHost -ForegroundColor Yellow
      }
   }

   foreach ($key in $stopped.Keys)
   {
      if (-not $started.ContainsKey($key))
      {
         $providerMismatch = $true
         Write-Log -Message "Provider stopped without a matching start for [$key]: stop=$($stopped[$key])" -IsHost -ForegroundColor Yellow
      }
   }

   if (-not $providerMismatch)
   {
      Write-Log -Message "Provider start/stop pairs validated (tracefmt)." -IsOutput
   }

   # Validate targeted PerceptionScenario IDs exist in tracefmt output.
   # tracefmt output embeds JSON; we check for PerceptionScenario numeric values (base and base+LDC variants).
   $LDC_MASK = 8388608
   $acceptable = New-Object System.Collections.Generic.List[long]

   if($snarioName -eq "$devPowStat\VoiceRecorderAppHibernation")
   {
      $base = 512
      $acceptable.Add([int64]$base) | Out-Null
      $acceptable.Add([int64]($base + $LDC_MASK)) | Out-Null
   }
   else
   {
      $wsev2PolicyState = CheckWSEV2Policy
      $basePrimary = if($wsev2PolicyState -eq $false) { 81968 } else { 737312 }
      $baseFallback = 81936

      $acceptable.Add([int64]$basePrimary) | Out-Null
      $acceptable.Add([int64]($basePrimary + $LDC_MASK)) | Out-Null
      $acceptable.Add([int64]$baseFallback) | Out-Null
      $acceptable.Add([int64]($baseFallback + $LDC_MASK)) | Out-Null
   }

   $found = $false
   foreach ($id in $acceptable) {
      if (Select-String -Path $pathAsgTraceFmtTxt -Pattern ('"PerceptionScenario"\s*:\s*' + [Regex]::Escape($id.ToString())) -Quiet) {
         Write-Log -Message "PerceptionScenario $id found" -IsHost -ForegroundColor Green
         $found = $true
         break
      }
   }

   if (-not $found) {
      Write-Log -Message "Expected PerceptionScenario not found. Logs saved here: $pathAsgTraceFmtTxt" -IsHost -ForegroundColor Red
   }
} 

<#
DESCRIPTION:
    This function checks for any generic errors in the ASG trace logs and logs any errors 
    found, except for known non-critical issues like "Orientation sensor hardware not detected."
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for identifying relevant logs.
RETURN TYPE:
    - void (Filters and logs generic errors without returning a value.)
#>
function GenericError-Hibernation($snarioName)
{
   $pathAsgTraceFmtTxt = "$pathLogsFolder\$snarioName\" + "AsgTraceFmt.txt"
   if (-not (Test-Path -LiteralPath $pathAsgTraceFmtTxt)) {
      return
   }
   $genericErrorLogs = @(Get-TraceFmtGenericErrors -Path $pathAsgTraceFmtTxt)
   For($i= 1 ; $i -lt $genericErrorLogs.Count ; $i++)
   {
      $line = $genericErrorLogs[$i].Line
      if($line -match "Orientation sensor hardware not detected")
      {  
         continue;
      }
      else
      {
         Write-Log -Message "GenericError - $line" -IsHost -BackgroundColor Red
         Write-Output "GenericError - $line" >> $pathLogsFolder\ConsoleResults.txt

      }
   }
}





