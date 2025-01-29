function InitializeTest($TstsetNme, $targetMepCameraVer, $targetMepAudioVer, $targetPerceptionCoreVer)
{
    $Global:pathLogsFolder = ".\Logs\" + "$((get-date).tostring('yyyy-MM-dd-HH-mm-ss'))" + "-$TstsetNme"
    New-Item -ItemType Directory -Force -Path $pathLogsFolder  | Out-Null
    $Global:SequenceNumber = 0
    $Global:Results = '' | SELECT ScenarioName,FramesAbove33ms,AvgProcessingTimePerFrame,MaxProcessingTimePerFrame,MinProcessingTimePerFrame,PCInItTime,CameraAppInItTime,VoiceRecorderInItTime,fps,PCInItTimeForAudio,FramesAbove33msForAudioBlur,PeakWorkingSetSize,AvgWorkingSetSize,Status,ReasonForNotPass

    # once if the WseEnabingStatus validation fails, stop and exit the test
    if ((WseEnablingStatus $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer) -eq $false)
    {
        Write-Error "WseEnablingStatus fail!"
        exit
    }
}


