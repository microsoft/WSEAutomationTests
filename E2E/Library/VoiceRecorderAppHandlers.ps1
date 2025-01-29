function AudioRecording($scnds)
{    
     #open voice recorder App
     Write-Output "Open Voice Recorder App"
     #TODO: Don't use full exe path to open voice recorder.we may have to set the path in the envoronment variable	
     $ui = OpenApp "C:\Program Files\WindowsApps\Microsoft.WindowsSoundRecorder_*_arm64__8wekyb3d8bbwe\VoiceRecorder.exe" 'Sound Recorder'
     
     Start-Sleep -m 500
     
     #Capture the start time for Voice Recorder App
     $voiceRecorderApp = Get-Process -Name VoiceRecorder | select starttime
     $voiceRecorderAppStart = $voiceRecorderApp.StartTime

     #Set time zone to UTC as Asg trace logs are using UTC date format
     $voiceRecorderAppStartinUTC = $voiceRecorderAppStart.ToUniversalTime()

     #Convert the date to string format to add the milliseconds 
     $voiceRecorderAppStartTostring = $voiceRecorderAppStartinUTC.ToString('yyyy/MM/dd HH:mm:ss:fff')
     Write-Output "voiceRecorder App start time in local time zone: ${voiceRecorderAppStartTostring}"

     #Coverting the string back to date format for time calculation in code later in CheckInitTimeVoiceRecorderApp function.
     $voiceRecorderAppStartTime = [System.DateTime]::ParseExact($voiceRecorderAppStartTostring,'yyyy/MM/dd HH:mm:ss:fff',$null)

     #Start audio recording
     Write-Output "Start Audio recording for $scnds"
     FindAndClick $ui Button "Start recording"

     #Capture the time record button was pressed. 
     $audioRecordingStart = Get-Date
    
     Start-Sleep -s $scnds
     
     #Set time zone to UTC as Asg trace logs are using UTC date format
     $audioRecordingStartinUTC = $audioRecordingStart.ToUniversalTime()

     #Convert the date to string format to add the milliseconds 
     $audioRecordingStartTostring = $audioRecordingStartinUTC.ToString('yyyy/MM/dd HH:mm:ss:fff')
     
     #Coverting the string back to date format for time calculation in code later in CheckInitTimeVoiceRecorderApp function.
     $audioRecordingStartTime = [System.DateTime]::ParseExact($audioRecordingStartTostring,'yyyy/MM/dd HH:mm:ss:fff',$null)
              
     #Stop audio recording
     Write-Output "Stop Audio recording"
     FindAndClick $ui Button "Stop recording"
     start-sleep -s 2

     CloseApp 'VoiceRecorder' 

     #Return the value to pass as parameter to CheckInitTimeVoiceRecorderApp function in VoiceRecordere2eTest.ps1 
     return ,$voiceRecorderAppStartTime, $audioRecordingStartTime 
}