function Get-InitialSetUp($scenarioName)
{
   Write-Log -Message "Entering Get-InitialSetUp function" -IsOutput
    
   # Open Camera App and set default setting to "Use system settings" 
   Set-SystemSettingsInCamera
   
   # Toggling All effects on
   Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On" -IsOutput
   ToggleAIEffectsInSettingsApp -AFVal "On" -PLVal "On" -BBVal "On" -BSVal "False" -BPVal "True" `
                                -ECVal "On" -ECSVal "False" -ECEVal "True" -VFVal "On" `
                                -CF "On" -CFI "False" -CFA "False" -CFW "True"

   # Set photo resolution
   $photoResName = SetHighestPhotoResolutionInCameraApp 
   $phoResNme = RetrieveValue $photoResName[-1]
   
   # Set video resolution
   $videoResName = SetHighestVideoResolutionInCameraApp
   $vdoResNme = RetrieveValue $videoResName[-1]
           
   # Checks if frame server is stopped
   Write-Log -Message "Entering CheckServiceState function" -IsOutput
   CheckServiceState 'Windows Camera Frame Server'
                 
   # Starting to collect Traces
   Write-Log -Message "Entering StartTrace function" -IsOutput
   StartTrace $scenarioName
   
   # Open Camera App
   $ui = OpenApp 'microsoft.windows.camera:' 'Camera'
   
   # Switch to video mode as photo mode doesn't support MEP
   SwitchModeInCameraApp $ui "Switch to video mode" "Take video"  
}

Function Complete-TestRun($scenarioName, $startTime, $token, $SPId)
{
    
   Write-Log -Message "Entering Complete-TestRun function" -IsOutput
   
   # Checks if frame server is stopped
   Write-Log -Message "Entering CheckServiceState function" -IsOutput
   CheckServiceState 'Windows Camera Frame Server'
   
   # Stop the Trace
   Write-Log -Message "Entering StopTrace function" -IsOutput
   StopTrace $scenarioName
                                            
   # Verify and validate if proper logs are generated or not.   
   $wsev2PolicyState = CheckWSEV2Policy
   
   # Set the ScenarioID based on the policy state
   if ($wsev2PolicyState -eq $false) {
       $scenarioID = "81968"  # Based on v1 effects
   } else {
       $scenarioID = "2834432"  # Based on v1+v2 effects, verify if this is correct
   }
   
   # Log the entry to Verifylogs function
   Write-Log -Message "Entering Verifylogs function with ScenarioID $scenarioID" -IsOutput
   
   # Call Verifylogs function
   Verifylogs $scenarioName $scenarioID $startTime
   
  
   #Collect data for Reporting
   Reporting $Results "$pathLogsFolder\Report.txt"

   #For our Sanity, we make sure that we exit the test in neutral state, which is plugged in
   SetSmartPlugState $token $SPId 1
}

