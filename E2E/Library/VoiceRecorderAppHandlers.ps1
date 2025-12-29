<#
DESCRIPTION:
    This function automates the process of recording audio using the Voice Recorder app on Windows.
    It captures the start time of the app and the precise time when the recording starts, 
    performs the recording for the specified duration, and stops the recording afterward.
    The timestamps are formatted for compatibility with Asg trace logs (in UTC with milliseconds).
INPUT PARAMETERS:
    - duration [int] :- The duration is the number of iterations for which the audio will be recorded.
    - snarioName [string] :- Scenario name used for resource logging.
    - logPath [string] :- Path to write resource utilization logs.
RETURN TYPE:
    - array (Returns an array containing the start time of the Voice Recorder app and the start time of the audio recording.)
#>
function AudioRecording($duration,$snarioName,$logPath)
{    
     #Open Task Manager and set speed to low
     setTMUpdateSpeedLow

     #Capture Resource Utilization before test starts.
     Monitor-Resources -scenario $snarioName -executionState "Before" -logPath $logPath -Once "Once"
     
     #open voice recorder App
     Write-Log -Message "Open Voice Recorder App" -IsOutput
     #TODO: Don't use full exe path to open voice recorder. We may have to set the path in the environment variable	
     $ui = OpenApp "C:\Program Files\WindowsApps\Microsoft.WindowsSoundRecorder_*_*__8wekyb3d8bbwe\VoiceRecorder.exe" 'Sound Recorder'
     
     Start-Sleep -m 500
     
     #Capture the start time for Voice Recorder App
     $voiceRecorderApp = Get-Process -Name VoiceRecorder | select starttime
     $voiceRecorderAppStart = $voiceRecorderApp.StartTime

     #Set time zone to UTC as Asg trace logs are using UTC date format
     $voiceRecorderAppStartinUTC = $voiceRecorderAppStart.ToUniversalTime()

     #Convert the date to string format to add the milliseconds 
     $voiceRecorderAppStartTostring = $voiceRecorderAppStartinUTC.ToString('yyyy/MM/dd HH:mm:ss:fff')
     Write-Log -Message "voiceRecorder App start time in local time zone: ${voiceRecorderAppStartTostring}" -IsOutput

     #Converting the string back to date format for time calculation in code later in CheckInitTimeVoiceRecorderApp function.
     $voiceRecorderAppStartTime = [System.DateTime]::ParseExact($voiceRecorderAppStartTostring,'yyyy/MM/dd HH:mm:ss:fff',$null)

     #Start audio recording
     Write-Log -Message "Start Audio recording for $scnds" -IsOutput
     FindAndClick $ui Button "Start recording"

     #Capture the time record button was pressed. 
     $audioRecordingStart = Get-Date

     # Capture Resource Utilization while test is running
     Monitor-Resources -scenario $snarioName -duration $duration -executionState "During" -logPath $logPath 
     Start-Sleep -s 1
     
     #Set time zone to UTC as Asg trace logs are using UTC date format
     $audioRecordingStartinUTC = $audioRecordingStart.ToUniversalTime()

     #Convert the date to string format to add the milliseconds 
     $audioRecordingStartTostring = $audioRecordingStartinUTC.ToString('yyyy/MM/dd HH:mm:ss:fff')
     
     #Converting the string back to date format for time calculation in code later in CheckInitTimeVoiceRecorderApp function.
     $audioRecordingStartTime = [System.DateTime]::ParseExact($audioRecordingStartTostring,'yyyy/MM/dd HH:mm:ss:fff',$null)
              
     #Stop audio recording
     Write-Log -Message "Stop Audio recording" -IsOutput
     FindAndClick $ui Button "Stop recording"
     start-sleep -s 2

     CloseApp 'VoiceRecorder' 

     #Return the value to pass as parameter to CheckInitTimeVoiceRecorderApp function in VoiceRecordere2eTest.ps1 
     return ,$voiceRecorderAppStartTime, $audioRecordingStartTime 
}