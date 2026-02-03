<#
DESCRIPTION:
    This function deletes video files from the Camera Roll folder that are older than 1 week
    and whose names start with 'WSE_test'. It checks both the local Pictures folder and the
    OneDrive Pictures folder for the Camera Roll location. Only .mp4 and .mkv video files
    matching the criteria are removed.
    This is called during test initialization to clean up old test-generated videos.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - void (Performs deletion operation without returning a value.)
#>
function Clear-CameraRollVideos
{
    Write-Host "Deleting WSE_test videos older than 1 week from Camera Roll"
    
    # Determine Camera Roll path
    $cameraRoll = "$env:userprofile\Pictures\Camera Roll"
    
    if (!(Test-Path -Path $cameraRoll))
    {
        $cameraRoll = "$env:userprofile\OneDrive\Pictures\Camera Roll"
        if (!(Test-Path -Path $cameraRoll))
        {
            Write-Host "Camera Roll path not found. Skipping video deletion."
            return
        }
    }
    # Cutoff date (1 week ago)
    $cutoffDate = (Get-Date).AddDays(-7)
        
    # Get matching video files
    $videoFiles = Get-ChildItem -Path $cameraRoll -File -Include *.mp4, *.mkv -Recurse -ErrorAction SilentlyContinue |
                  Where-Object {
                      $_.Name -like "WSE_test*" -and
                      $_.LastWriteTime -lt $cutoffDate
                  }
    if ($videoFiles -and $videoFiles.Count -gt 0)
    {
        Write-Log -Message "Found $($videoFiles.Count) video(s) to delete." -IsHost
        foreach ($video in $videoFiles)
        {
            Remove-Item -Path $video.FullName -Force -ErrorAction SilentlyContinue
        }
    }
    else
    {
        Write-Log -Message "No videos found to delete" -IsHost
    }
}
