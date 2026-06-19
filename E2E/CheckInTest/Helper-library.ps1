.".\Helper\SetAsgTraceFolders.ps1"
.".\Helper\InitializeTest.ps1"
.".\Helper\LoggingHelper.ps1"
.".\Helper\OpenCloseApp.ps1"
.".\Helper\CheckFrameServerServiceStateandCloseService.ps1"
.".\Helper\OutputMessage.ps1"
.".\Helper\TakeScreenshot.ps1"
.".\Helper\ClearCameraRollVideos.ps1"

.".\Library\SettingsAppHandlers.ps1"
.".\Library\CameraAppHandlers.ps1"
.".\Library\FindClickableElement.ps1"
.".\Library\StartAndStopTrace.ps1"
.".\Library\VerifyLogs.ps1"
.".\Library\Get-videodetails.ps1"
.".\Library\VoiceRecorderAppHandlers.ps1"
.".\Library\Policy.ps1"
.".\Library\SmartPlug.ps1"
.".\Library\Hibernation.ps1"
.".\Library\WseEnablingStatus.ps1"
.".\Library\TaskManager.ps1"
.".\Library\ExceptionError.ps1"
.".\Library\LookUpTable.ps1"
.".\Library\DeviceDetails.ps1"
.".\Library\SetupandCompleteTestRun"
.".\CheckInTest\CameraAppTest.ps1"
.".\CheckInTest\CameraAppTestQuickSettings.ps1"
.".\CheckInTest\SettingAppTest.ps1"
.".\CheckInTest\VoiceFocusToggle.ps1"
.".\CheckInTest\VoiceRecordere2eTest.ps1"
.".\CheckInTest\Camerae2eTest.ps1"
.".\CheckInTest\CameraAppHibernation.ps1"
.".\CheckInTest\SettingAppHibernation.ps1"
.".\CheckInTest\VoiceRecorderAppHibernation.ps1"
.".\CheckInTest\Min-Max-CameraApp.ps1"
.".\CheckInTest\RevisitCameraSettingPage.ps1"
.".\CheckInTest\ToggleAIEffectsMultipleTimes.ps1"
.".\CheckInTest\MemoryUsage.ps1"

# Quick Settings modules — ScreenCapture, OcrHelper, StudioEffectsHandler, and
# CameraAppTestQuickSettings are dot-sourced at script level so their function
# definitions are visible to all callers. OcrHelper gracefully sets $script:OcrAvailable
# to $false if WinRT types are unavailable.
.".\Helper\ScreenCapture.ps1"
.".\Library\OcrHelper.ps1"
.".\Library\StudioEffectsHandler.ps1"

function Import-QuickSettingsModules {
    if ($script:QuickSettingsModulesLoaded) { return }
    # Fail fast if OCR types could not be loaded — downstream modules depend on them
    if (-not $script:OcrAvailable) {
        Write-Error "OCR WinRT types are not available. Quick Settings automation requires OCR support. Aborting." -ErrorAction Stop
    }
    $script:QuickSettingsModulesLoaded = $true
    Write-Log -Message "Quick Settings modules loaded (OCR available)" -IsOutput
}

