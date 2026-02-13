param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null

) 
# Sign In Teams with UserName: MEPTesting and check @jdugar for password. One time setup- Teams meeting link opens in browser, Select option to open in App always.

<#
DESCRIPTION:
   This function runs an end-to-end test for the Teams application,
   checking device power states, starting a Teams meeting, and capturing performance data.
INPUT PARAMETERS:
   - token [string] :- Authentication token required to control the smart plug.
   - SPId [string] :- Smart plug ID used to control device power states.
   - targetMepCameraVer [string] :- Target version of the MEP.
   - targetMepAudioVer [string] :- Target version of the MEP.
   - targetPerceptionCoreVer [string] :- Target version of the Perception Core.
   RETURN TYPE:
   - void
#>
function Teamse2eTesting
{
    Write-Log -Message "Entering Teamse2eTesting function" -IsOutput 
    $startTime = Get-Date    
    $ErrorActionPreference='Stop'
    foreach($devPowStat in "Pluggedin" , "Unplugged")
    {
       $scenarioLogFolder = "$devPowStat\Teamse2eTesting"
       $logFile = "Teamse2eTesting.txt"
           
       try
	   {  
           # Create Scenario folder
           CreateScenarioLogsFolder $scenarioLogFolder
        
           $devState = CheckDevicePowerState $devPowStat $token $SPId
           if($devState -eq $false)
           {   
              TestOutputMessage  $scenarioLogFolder "Skipped" $startTime "Token is empty"  
              return
           }  


           # Toggling All effects on
           Write-Output "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On"
           ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                        -ECVal "On" -ECSVal "False" -ECTVal "True" -VFVal "On" `
                                        -CF "On" -CFI "False" -CFA "False" -CFW "True"        
         
           
            # Checks if frame server is stopped
            Write-Output "Entering CheckServiceState function"
            CheckServiceState 'Windows Camera Frame Server'
                          
            # Starting to collect Traces
            Write-Output "Entering StartTrace function"
            StartTrace $scenarioLogFolder
            
            # Open Task Manager
            Write-output "Opening Task Manager"
            $uitaskmgr = OpenApp 'Taskmgr' 'Task Manager'
            Start-Sleep -s 1
            setTMUpdateSpeedLow -uiEle $uitaskmgr

            # Start Teams Meeting
            Start-sleep -s 2
            Start-TeamsMeeting 

            # Capture CPU and NPU Usage screenshot
            Write-output "Entering CPUandNPU-Usage function to capture CPU and NPU usage Screenshot"  
            stopTaskManager -uitaskmgr $uitaskmgr -Scenario $scenarioLogFolder
            
            # Verify logs and capture results.
            Complete-TestRun $scenarioLogFolder $startTime $token $SPId
        }
        catch
        {   
           Error-Exception -snarioName $scenarioLogFolder -strttme $startTime -rslts $Results -logFile $logFile -token $token -SPID $SPID
        }
     }
     #For our Sanity, we make sure that we exit the test in neutral state, which is plugged in
     SetSmartPlugState $token $SPId 1
}            
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms

.".\CheckInTest\Helper-library.ps1"
InitializeTest 'Teamse2eTesting' $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer
Teamse2eTesting |  Out-File -FilePath "$pathLogsFolder\Teamse2eTesting.txt" -Append
