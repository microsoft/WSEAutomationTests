<#
DESCRIPTION:
    Captures the Peak Working Set Size (maximum amount of memory used) of the FrameServer process.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - int (Returns the Peak Working Set Size of the FrameServer process in bytes.)
#>
function PeakWorkingSetSize()
{
   $processId = Get-WmiObject -Class Win32_Service -Filter "Name LIKE 'FrameServer'" | Select-Object -ExpandProperty ProcessId
   $processIddetails = get-CimInstance Win32_Process -Filter "processid =  $processId"
   $peakWorkingSetSize = $processIddetails.PeakWorkingSetSize
   return $peakWorkingSetSize
}

<#
DESCRIPTION:
    This function measures memory usage of the Camera App while recording a video. 
    It toggles AI effects, sets resolutions, records a video, captures Peak Working Set Size,
    and checks if memory growth exceeds a threshold over a prolonged duration.
INPUT PARAMETERS:
    - devPowStat [string] :- The power state of the device (e.g., "PluggedIn", "OnBattery").
    - token [string] :- Authentication token required to control the smart plug.
    - SPId [string] :- Smart plug ID used to control device power states.
RETURN TYPE:
    - void 
#>
function MemoryUsage-Playlist($devPowStat, $token, $SPId) 
{   
    $startTime = Get-Date    
    $ErrorActionPreference='Stop'
    $scenarioName = "$devPowStat\MemoryUsage"
    $logFile = "$devPowStat-MemoryUsage.txt"

    $devState = CheckDevicePowerState $devPowStat $token $SPId
    if($devState -eq $false)
    {   
       TestOutputMessage $scenarioName "Skipped" $startTime "Token is empty"  
       return
    }
         
    try
	{  
        # Create Scenario folder
        $scenarioLogFolder = $scenarioName
        CreateScenarioLogsFolder $scenarioLogFolder
        
        # Set up camera effects/settings and start collecting trace
        Get-InitialSetUp $scenarioName 
        Start-Sleep -s 2
        
        # Record video inbetween space presses
        Write-Log -Message "Start recording a video for $scnds seconds" -IsOutput
        [System.Windows.Forms.SendKeys]::SendWait(' ');
        
        # Sleep for 1 minute before capturing PeakWorkingSetSize
        Start-Sleep -s 60
        $i=1
        $secArray = @(1200, 1200, 1200, 1200, 1200) # Array of sleep durations
        Foreach($sec in $secArray)
        {  
           # Capture Initial PeakWorkingSetSize before starting sleep again for adiitional $sec secs 
           $pekWorkSetSiz = PeakWorkingSetSize
           Write-Log -Message "Initial PeakWorkingSetSize before starting sleep again for adiitional $sec secs: $pekWorkSetSiz" -IsOutput -IsHost

           # Sleep for additional 20 minute before capturing PeakWorkingSetSize
           start-Sleep -s $sec
           $pekWorkSetSiz20min = PeakWorkingSetSize
           Write-Log -Message "PeakWorkingSetSize after $sec secs : $pekWorkSetSiz20min" -IsOutput -IsHost
           
           # Compare the Peakworking set and check if the difference is greater than 1000KB between every $sec secs
           $difference = $pekWorkSetSiz20min - $pekWorkSetSiz
           Write-Log -Message "Difference between PeakWorkingSet after every $sec secs: $difference" -IsOutput
           # Checking if the value is not negative and greater than 1000KB
           if(($difference -gt 0) -and ($difference -gt 1000))
           {

              # Peakworkingset greater than 1000KB is just an indication that there could be memory leak. Next step would be to enable appvifier and collect dump manually.
              $greaterThan1000KB = $True
              write-host "PeakworkingSet difference is greater than 1000KB for run $i. Difference after every $sec is: $difference = $pekWorkSetSiz20min - $pekWorkSetSiz" -BackgroundColor Red
              write-Output "PeakworkingSet difference is greater than 1000KB for run $i. Difference after every $sec is: $difference = $pekWorkSetSiz20min - $pekWorkSetSiz"  >>  $pathLogsFolder\ConsoleResults.txt
           } 
           else
           {
              Write-Log -Message "PeakworkingSet difference is not greater than 1000KB for run $i. Difference after every $sec is: $difference = $pekWorkSetSiz20min - $pekWorkSetSiz" -IsHost -IsOutput
           }
           $i++
        }
        Start-Sleep -s 2
        
        # Close Camera App
        CloseApp 'WindowsCamera'
        
                                  
        # Checks if frame server is stopped
        Write-Log -Message "Entering CheckServiceState function" -IsOutput
        CheckServiceState 'Windows Camera Frame Server' 
        
        # Stop the Trace
        Write-Log -Message "Entering StopTrace function" -IsOutput
        StopTrace $scenarioLogFolder
        
        # Fail the test if Peakworkingset size difference is greater than 1000KB
        if($greaterThan1000KB -eq $True)
        {
           TestOutputMessage $scenarioLogFolder "Fail" $startTime "PeakworkingSet difference is greater than 1000KB"
        }
        else
        {
           TestOutputMessage $scenarioLogFolder "Pass" $startTime "PeakworkingSet difference is not greater than 1000KB"
        } 
        # For our Sanity, we make sure that we exit the test in netural state,which is pluggedin
        SetSmartPlugState $token $SPId 1    
    }
    catch
    {   
       Error-Exception -snarioName $scenarioLogFolder -strttme $startTime -rslts $Results -logFile $logFile -token $token -SPID $SPID
    }
}
