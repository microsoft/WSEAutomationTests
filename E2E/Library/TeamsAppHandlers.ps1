<#
DESCRIPTION:
  Starts a Microsoft Teams meeting using the given link and automates
  camera, audio, and join actions.

INPUT PARAMETERS:
  @param teamsMeetingLink [String] - Teams meeting URL.

RETURN TYPE:
  void
#>
function Start-TeamsMeeting
{
    Write-Log -Message "Entering Start-TeamsMeeting function" -IsOutput 

    # Launch the Teams app with the meeting link
    Start-Process "https://teams.live.com/meet/9393388815307?p=DjwPrJ9iFrjS0pdlyT"

    # Toggle Camera button
    [System.Windows.Forms.SendKeys]::SendWait('^+o') 
    
    # Wait and check if Teams process is running 
    Start-Sleep -Seconds 5
    $Teams = Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue
    if (-not $Teams) {
        Write-Host "Teams process not found."
        return
    }
    $TeamsProcessIDDetails = $Teams.Id
    foreach($TeamsProcessID in $TeamsProcessIDDetails)
    {
       $uiTeams = FindUIElementByProcessID -procID $TeamsProcessID
       if ($uiTeams -ne $null)
       { 
         # Click Join, then check camera & mic is On. 
         start-sleep -s 5
         FindAndClick -uiEle $uiTeams -autoID "prejoin-join-button"  
         Start-Sleep -s 5
         Start-Camera -uiEle $uiTeams
         Start-Sleep -s 5
         Start-Audio -uiEle $uiTeams

         # End and Close Teams after 60 secs
         Start-Sleep -s 60
         [System.Windows.Forms.SendKeys]::SendWait('^+H')
         Stop-Process -Name "ms-teams"
         Start-Sleep -s 2              
       }
 
     }
}
<#
DESCRIPTION:
   This function turns on the camera in the Teams app if it's not already on.
INPUT PARAMETERS:
   - uiEle [object] :- The Teams UI element for camera control.
RETURN TYPE:
   - void
#>

function Start-Camera($uiEle) 
{
    Write-Log -Message "Entering Start-Camera function" -IsOutput
    $elemt = CheckIfElementExists -uiEle $uiEle -proptyNme "Turn camera off"
    if ($elemt -ne $null){
        Write-Log -Message "Camera is already On" -IsHost -IsOutput
    }
    else
    {
       FindAndClick -uiEle $uiEle -proptyNme "Turn camera on"
    }
}
<#
DESCRIPTION:
   This function unmutes the microphone in the Teams app if it's muted.
INPUT PARAMETERS:
   - uiEle [object] :- The Teams UI element for audio control.
RETURN TYPE:
   - void
#>

function Start-Audio($uiEle)
{
    Write-Log -Message "Entering Start-Audio function" -IsOutput 
    $elemt = CheckIfElementExists -uiEle $uiEle -proptyNme "Mute mic"
    if ($elemt -ne $null){
        Write-Log -Message "Audio is already On" -IsHost -IsOutput
    }
    else
    {
       FindAndClick -uiEle $uiEle -proptyNme  "Unmute mic"
    }
}