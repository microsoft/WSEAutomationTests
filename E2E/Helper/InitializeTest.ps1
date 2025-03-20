<#
DESCRIPTION:
    This function initializes the environment for a test run. It sets up global variables 
    for log storage, initializes result tracking structures, and validates the 
    WSE (Windows Subsystem for Enhanced) enabling status based on specified target versions.

INPUT PARAMETERS:
    - TstsetNme [string] :- The name of the test set, used for naming log folders.
    - targetMepCameraVer [string] :- The target version of the MEP Camera component to be validated.
    - targetMepAudioVer [string] :- The target version of the MEP Audio component to be validated.
    - targetPerceptionCoreVer [string] :- The target version of the Perception Core component to be validated.

RETURN TYPE:
    - void
#>
function InitializeTest($TstsetNme, $targetMepCameraVer, $targetMepAudioVer, $targetPerceptionCoreVer)
{
    $Global:pathLogsFolder = ".\Logs\" + "$((get-date).tostring('yyyy-MM-dd-HH-mm-ss'))" + "-$TstsetNme"
    New-Item -ItemType Directory -Force -Path $pathLogsFolder  | Out-Null
    $Global:SequenceNumber = 0
    $Global:Results = '' | SELECT ScenarioName,FramesAbove33ms,AvgProcessingTimePerFrame,MaxProcessingTimePerFrame,MinProcessingTimePerFrame,PCInItTime,CameraAppInItTime,VoiceRecorderInItTime,fps,PCInItTimeForAudio,FramesAbove33msForAudioBlur,PeakWorkingSetSize,AvgWorkingSetSize,Status,ReasonForNotPass
    $Global:validatedCameraFriendlyName = ""
    
    # once if the WseEnabingStatus validation fails, stop and exit the test
    if ((WseEnablingStatus $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer) -eq $false)
    {
        Write-Error "WseEnablingStatus fail!"
        exit
    }
}