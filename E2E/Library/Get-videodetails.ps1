<#
DESCRIPTION:
    This function retrieves details of the most recent video recorded by the Camera app. It validates whether the video 
    corresponds to the current test scenario based on the modification time.Renames the video with specific test scenario details. The function extracts and logs metadata such as 
    frame rate, frame dimensions, and duration. If the frame rate doesn't meet expectations, the video is saved in the logs folder.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for organizing logs and validating the recorded video.
    - pathLogsFolder [string] :- The path where logs and videos are stored if the validation criteria are not met.
RETURN TYPE:
    - void (Performs validation, logging, and saving operations without returning a value.)
#>
function GetVideoDetails($snarioName,$pathLogsFolder)
{
    Write-Log -Message "Checking latest video recording details in GetVideoDetails function" -IsOutput
    $cameraRoll = "$env:userprofile\Pictures\Camera Roll"
    
    if (!(Test-Path -Path $cameraRoll))
    {
        $cameraRoll = "$env:userprofile\OneDrive\Pictures\Camera Roll"
        if (!(Test-Path -Path $cameraRoll))
        {
        Write-Error " $cameraRoll -Path not found" -ErrorAction Stop 
        }
    }

    $latestVideo = Get-ChildItem $cameraRoll -File -Include *.mp4, *.mkv -Recurse |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 1
               
    if (-not $latestVideo)
    {
        Write-Log -Message "No video files found in Camera Roll" -IsHost -ForegroundColor Yellow
        return
    }
    #Video modified time (Validate video is recorded for current scenario)
    $VideoModifiedTime = $latestVideo.LastWriteTime
    $currentTime = Get-Date
    $timeDiff = ($currentTime - $VideoModifiedTime).TotalMinutes
    if($timeDiff -gt 3)
    {
        Write-Log -Message "   No video recorded for current scenario- $snarioName" -IsHost -ForegroundColor Yellow
    }
    else
    {
       $videoPath      = $latestVideo.FullName
       $videoExtension = $latestVideo.Extension
       $sanitizedScenarioName = $snarioName -replace '[\\/:*?"<>|]', '_'
       $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
       $newVideoName = "WSE_test_${sanitizedScenarioName}_$timestamp$videoExtension"
              
       try
       {
           Rename-Item -Path $videoPath -NewName $newVideoName -Force -ErrorAction Stop
       }
       catch
       {
           Write-Log -Message "Failed to rename video: $_" -IsHost -ForegroundColor Red
           return
       }
       
       $newVideoPath = Join-Path $cameraRoll $newVideoName
       Write-Log -Message "Video renamed from $videoFileName to: $newVideoName" -IsOutput
       Write-Log -Message "video location: $newVideoPath" -IsOutput
       
       #shell objects
       $shell = New-Object -ComObject Shell.Application
       $shellfolder = $shell.namespace((Get-Item  $newVideoPath).DirectoryName)
       $videoFileDetails = $shellfolder.ParseName($newVideoName)

       #Frame rate
       $frameRateValue=$videoFileDetails.ExtendedProperty("System.Video.FrameRate") / 1000.0
       Write-Log -Message "FrameRate: $frameRateValue" -IsOutput
           
       #Frame width
       $frameWidthValue=$videoFileDetails.ExtendedProperty("System.Video.FrameWidth")
       Write-Log -Message "FrameWidth: $frameWidthValue" -IsOutput
       
       #Frame height
       $frameHeightValue=$videoFileDetails.ExtendedProperty("System.Video.FrameHeight")
       Write-Log -Message "FrameHeight: $frameHeightValue" -IsOutput
       
       #Length
       $duration = $videoFileDetails.ExtendedProperty("System.Media.Duration")
       $videoLength = [System.TimeSpan]::FromTicks($duration).ToString("hh\:mm\:ss")
       Write-Log -Message "Length: $videoLength" -IsOutput

                
       $patternmatchcheck =$frameRateValue | Select-String -Pattern "29.\d\d|30.\d\d" -Quiet
       if ($patternmatchcheck -ne "True")
       {
           Copy-Item  $cameraRoll\$newVideoName -Destination $pathLogsFolder\$snarioName
           Write-Log -Message "   $snarioName-Video Framerate is:$frameRateValue" -IsHost -ForegroundColor Yellow
           Write-Log -Message "$snarioName-Video Framerate is:$frameRateValue" -IsOutput >> $pathLogsFolder\ConsoleResults.txt
           Write-Log -Message "Video saved here: $pathLogsFolder\$snarioName" -IsHost -IsOutput >> $pathLogsFolder\ConsoleResults.txt
       }
       $Results.fps = $frameRateValue  
    }
     
    #free shell object
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$shell) | out-null  
}
