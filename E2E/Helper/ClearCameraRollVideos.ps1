<#
DESCRIPTION:
    This function deletes all video files from the Camera Roll folder. It checks both the local Pictures folder 
    and OneDrive Pictures folder for Camera Roll location. All .mp4 and .mkv files are removed.
    This is called during test initialization to ensure a clean state before tests begin.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - void (Performs deletion operation without returning a value.)
#>
function Clear-CameraRollVideos
{
    Write-Host "Deleting all videos from Camera Roll"
    
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
    
    # Get all video files (mp4 and mkv are common video formats from Camera app)
    $videoFiles = Get-ChildItem -Path $cameraRoll -File -Include *.mp4, *.mkv -Recurse -ErrorAction SilentlyContinue
    
    if ($videoFiles -and $videoFiles.Count -gt 0)
    {
        $videoCount = $videoFiles.Count
        foreach ($video in $videoFiles)
        {
            try
            {
                Remove-Item -Path $video.FullName -Force -ErrorAction Stop
            }
            catch
            {
                Write-Host "Failed to delete video: $($video.Name). Error: $_"
            }
        }
 
    }
    else
    {
        Write-Host "No videos found in Camera Roll to delete"
    }
}
