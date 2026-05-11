<#
DESCRIPTION:
    This function automates the process of recording audio using the Voice Recorder app on Windows.
    It captures the start time of the app and the precise time when the recording starts, 
    performs the recording for the specified duration, and stops the recording afterward.
    The timestamps are formatted for compatibility with Asg trace logs (in UTC with milliseconds).
INPUT PARAMETERS:
    - scnds [int] :- The duration (in seconds) for which the audio will be recorded.
RETURN TYPE:
    - array (Returns an array containing the start time of the Voice Recorder app and the start time of the audio recording.)
#>
function AudioRecording($duration,$snarioName,$logPath)
{    
     #Open Task Manager and set speed to low
     setTMUpdateSpeedLow

     #Capture Resource Utilization before test starts
     Monitor-Resources -scenario $snarioName -executionState "Before" -logPath $logPath -Once "Once"
     
     #open voice recorder App
     Write-Log -Message "Open Voice Recorder App" -IsOutput
      # Launch Sound Recorder via AUMID (more reliable than WindowsApps paths)
      $ui = $null
      try
      {
          $ui = OpenApp 'shell:AppsFolder\Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe!App' 'Sound Recorder'
      }
      catch
      {
          # Some builds/locales may use a different window title
          $ui = OpenApp 'shell:AppsFolder\Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe!App' 'Voice Recorder'
      }
     
     Start-Sleep -m 500
     
     #Capture the start time for Voice Recorder App
      $voiceRecorderProcess = Get-Process -Name VoiceRecorder -ErrorAction SilentlyContinue | Select-Object -First 1
      if($null -eq $voiceRecorderProcess)
      {
          $voiceRecorderProcess = Get-Process -Name SoundRecorder -ErrorAction SilentlyContinue | Select-Object -First 1
      }
      if($null -eq $voiceRecorderProcess)
      {
          throw 'Sound Recorder process did not start (expected VoiceRecorder.exe or SoundRecorder.exe).'
      }
      $voiceRecorderAppStart = $voiceRecorderProcess.StartTime

     #Set time zone to UTC as Asg trace logs are using UTC date format
     $voiceRecorderAppStartinUTC = $voiceRecorderAppStart.ToUniversalTime()

     #Convert the date to string format to add the milliseconds 
     $voiceRecorderAppStartTostring = $voiceRecorderAppStartinUTC.ToString('yyyy/MM/dd HH:mm:ss:fff')
     Write-Log -Message "voiceRecorder App start time in local time zone: ${voiceRecorderAppStartTostring}" -IsOutput

     #Converting the string back to date format for time calculation in code later in CheckInitTimeVoiceRecorderApp function.
     $voiceRecorderAppStartTime = [System.DateTime]::ParseExact($voiceRecorderAppStartTostring,'yyyy/MM/dd HH:mm:ss:fff',$null)

     #Start audio recording
    Write-Log -Message "Start Audio recording for $duration" -IsOutput
     FindAndClick $ui Button "Start recording"

     #Capture the time record button was pressed. 
     $audioRecordingStart = Get-Date

     # Capture Resource Utilization while test is running
     Monitor-Resources -Scenario $snarioName -duration $duration -executionState "During" -logPath $logPath 
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
    Start-Sleep -Seconds 2

    CloseApp 'VoiceRecorder'
    Write-Log -Message "Closing Sound Recorder App" -IsOutput

     #Return the value to pass as parameter to CheckInitTimeVoiceRecorderApp function in VoiceRecordere2eTest.ps1 
     return ,$voiceRecorderAppStartTime, $audioRecordingStartTime 
}