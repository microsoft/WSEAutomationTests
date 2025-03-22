<#
DESCRIPTION:
    This function retrieves details of the most recent video recorded by the Camera app. It validates whether the video 
    corresponds to the current test scenario based on the modification time. The function extracts and logs metadata such as 
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
    $videoFileName = (Get-ChildItem $cameraRoll -File | Sort-Object LastWriteTime -Descending| Select-Object -First 1).name 
    $videoPath = "$cameraRoll\$videoFileName"
    Write-Log -Message "video location: $videoPath" -IsOutput

    #shell objects
    $shell = New-Object -ComObject Shell.Application
    $shellfolder = $shell.namespace((Get-Item  $videoPath).DirectoryName)
    $videoFileDetails = $shellfolder.ParseName($videoFileName)

    #Video modified time (Validate video is recorded for current scenario)
    $VideoModifiedTime = $videoFileDetails.Modifydate 
    $currentTime = Get-Date
    $timeDiff = ($currentTime - $VideoModifiedTime).Totalminutes
    if($timeDiff -gt 3)
    {
        Write-Log -Message "   No video recorded for current scenario- $snarioName" -IsHost -ForegroundColor Yellow
    }
    else
    {
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
           Copy-Item  $cameraRoll\$videoFileName -Destination $pathLogsFolder\$snarioName
           Write-Log -Message "   $snarioName-Video Framerate is:$frameRateValue" -IsHost -ForegroundColor Yellow
           Write-Log -Message "$snarioName-Video Framerate is:$frameRateValue" -IsOutput >> $pathLogsFolder\ConsoleResults.txt
           Write-Log -Message "Video saved here: $pathLogsFolder\$snarioName" -IsHost -IsOutput >> $pathLogsFolder\ConsoleResults.txt
       }
       $Results.fps = $frameRateValue  
    }
     
    #free shell object
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$shell) | out-null  
}
