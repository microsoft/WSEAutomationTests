$photoResolutionList = "2.1 megapixels, 16 by 9 aspect ratio,  1920 by 1080 resolution" , "3.8 megapixels, 16 by 9 aspect ratio,  2592 by 1458 resolution" ,  "12.2 megapixels, 4 by 3 aspect ratio,  4032 by 3024 resolution"

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
        #Create Scenario folder
        $scenarioLogFolder = $scenarioName
        CreateScenarioLogsFolder $scenarioLogFolder

        #Toggling All effects on
        Write-Output "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On"
        ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                     -ECVal "On" -ECSVal "False" -ECEVal "True" -VFVal "On" `
                                     -CF "On" -CFI "False" -CFA "False" -CFW "True"
                                     
                     
        #Open Camera App and set default setting to "Use system settings" 
        Set-SystemSettingsInCamera
       
        #Set video resolution
        SetvideoResolutionInCameraApp $scenarioName $startTime "1080p, 16 by 9 aspect ratio, 30 fps"
        
        #Set photo resolution 
        foreach ($ptoRes in $photoResolutionList)
        {
           #Create scenario folder specific to photoresolution for collecting logs
           Write-Output "Creating folder for capturing logs"
           $ptoResfolder = $ptoRes.Split(", ") | Select-Object -First 1
           $ptoResfoldername = $ptoResfolder + "MP"
           $scenarioLogFolder = "$scenarioName\$ptoResfoldername" 
           CreateScenarioLogsFolder $scenarioLogFolder
           
           $result = SetphotoResolutionInCameraApp $scenarioLogFolder $startTime $ptoRes
           if($result[-1]  -ne $false)
           {
              #Checks if frame server is stopped
              Write-Output "Entering CheckServiceState function"
              CheckServiceState 'Windows Camera Frame Server'
                            
              #Strating to collect Traces
              Write-Output "Entering StartTrace function"
              StartTrace $scenarioLogFolder
              
              #Start video recording and close the camera app once finished recording 
              #Open Camera App
              Write-Output "Open camera App"
              $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
              Start-Sleep -s 1
                                                                        
              #Switch to video mode if not in video mode
              SwitchModeInCameraApp $ui "Switch to video mode" "Take video" 
              Start-Sleep -s 2
              
              #record video inbetween space presses
              Write-Output "Start recording a video for $scnds seconds"
              [System.Windows.Forms.SendKeys]::SendWait(' ');
              
              #Sleep for 1 minute before capturing PeakWorkingSetSize
              Start-Sleep -s 60
              $i=1
              Foreach($sec in 1200, 1200, 1200, 1200, 1200)
              {  
                 #Capture Initial PeakWorkingSetSize before starting sleep again for adiitional $sec secs 
                 $pekWorkSetSiz = PeakWorkingSetSize
                 Write-host "Initial PeakWorkingSetSize before starting sleep again for adiitional $sec secs: $pekWorkSetSiz"
                 Write-Output "Initial PeakWorkingSetSize before starting sleep again for adiitional $sec secs: $pekWorkSetSiz"

                 #Sleep for additional 20 minute before capturing PeakWorkingSetSize
                 start-Sleep -s $sec
                 $pekWorkSetSiz20min = PeakWorkingSetSize
                 Write-host "PeakWorkingSetSize after $sec secs : $pekWorkSetSiz20min" 
                 Write-Output "PeakWorkingSetSize after $sec secs: $pekWorkSetSiz20min"
                 
                 #Compare the Peakworking set and check if the difference is greater than 1000KB between every $sec secs
                 $difference = $pekWorkSetSiz20min - $pekWorkSetSiz
                 Write-Output "Difference between PeakWorkingSet after every $sec secs: $difference"
                 if(($difference -gt 0) -and ($difference -gt 1000))
                 {
                    $greaterThan1000KB = $True
                    write-host "PeakworkingSet difference is greater than 1000KB for run $i. Difference after every $sec is: $difference = $pekWorkSetSiz20min - $pekWorkSetSiz" -BackgroundColor Red
                    write-Output "PeakworkingSet difference is greater than 1000KB for run $i. Difference after every $sec is: $difference = $pekWorkSetSiz20min - $pekWorkSetSiz"  >>  $pathLogsFolder\ConsoleResults.txt
                 } 
                 else
                 {
                    write-host "PeakworkingSet difference is not greater than 1000KB for run $i. Difference after every $sec is: $difference = $pekWorkSetSiz20min - $pekWorkSetSiz"
                 }
                 $i++
              
              }
              Start-Sleep -s 2
              
              #Close Camera App
              CloseApp 'WindowsCamera'
              
                                        
              #Checks if frame server is stopped
              Write-Output "Entering CheckServiceState function"
              CheckServiceState 'Windows Camera Frame Server' 
              
              #Stop the Trace
              Write-Output "Entering StopTrace function"
              StopTrace $scenarioLogFolder
              
              #Fail the test if Peakworkingset size difference is greater than 1000KB
              if($greaterThan1000KB -eq $True)
              {
                 TestOutputMessage $scenarioLogFolder "Fail" $startTime "PeakworkingSet difference is greater than 1000KB"
              }
              else
              {
                 TestOutputMessage $scenarioLogFolder "Pass" $startTime "PeakworkingSet difference is not greater than 1000KB"
              } 
                           
                                                         
              #For our Sanity, we make sure that we exit the test in netural state,which is pluggedin
              SetSmartPlugState $token $SPId 1    

           }             
 
        }
    }
    catch
    {   
       Error-Exception -snarioName $scenarioLogFolder -strttme $startTime -rslts $Results -logFile $logFile -token $token -SPID $SPID
    }
}
