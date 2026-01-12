param (
   [string] $token = $null,
   [string] $SPId = $null,
   [string] $targetMepCameraVer = $null,
   [string] $targetMepAudioVer = $null,
   [string] $targetPerceptionCoreVer = $null,
   [int]    $iteration = 0
)

# definition of the scenario name & scenario ID
Set-Variable -Name "WSE_ALL_CAMERA_EFFECTS_SCENARIO_V1"     -Option ReadOnly -Value "AFS+EC+BBP"
Set-Variable -Name "WSE_ALL_CAMERA_EFFECTS_SCENARIO_ID_V1"  -Option ReadOnly -Value 81968
Set-Variable -Name "WSE_ALL_CAMERA_EFFECTS_SCENARIO_V2"     -Option ReadOnly -Value "AFS+PL+ECS+BBP+CFA"
Set-Variable -Name "WSE_ALL_CAMERA_EFFECTS_SCENARIO_ID_V2"  -Option ReadOnly -Value 2703376
Set-Variable -Name "VIDEO_RECORDING_DURATION"               -Option ReadOnly -Value 20
Set-Variable -Name "NUMBER_OF_ITERATION"                    -Option ReadOnly -Value 10

function VerifyVideoMode {
    param ($assessmentScenario, $videoResName, $iter)

    $timeStamp = Get-Date
    $scenarioLogFolder = "CameraReliabilityTest\$assessmentScenario\iteration_$iter"
    $wsev2PolicyState = CheckWSEV2Policy

    # Start collecting traces
    StartTrace $scenarioLogFolder $timeStamp

    StartVideoRecording $VIDEO_RECORDING_DURATION

    # Check if frame server is stopped
    CheckServiceState 'Windows Camera Frame Server'

    # Stop the trace
    StopTrace $scenarioLogFolder $timeStamp

    $scenarioID = if ($wsev2PolicyState) {
        $WSE_ALL_CAMERA_EFFECTS_SCENARIO_ID_V2
    } else {
        $WSE_ALL_CAMERA_EFFECTS_SCENARIO_ID_V1
    }

    return Verifylogs $scenarioLogFolder $scenarioID $timeStamp
}

function VerifyPhotoMode {
    param ($iter)

    $timeStamp = Get-Date
    $scenarioLogFolder = "CameraReliabilityTest\photo\iteration_$iter"

    # Start collecting traces
    StartTrace $scenarioLogFolder $timeStamp

    StartPhotoCapturing

    # Check if frame server is stopped
    CheckServiceState 'Windows Camera Frame Server'

    # Stop the trace
    StopTrace $scenarioLogFolder $timeStamp

    $scenarioID = 0
    return Verifylogs $scenarioLogFolder $scenarioID $timeStamp
}

function CameraReliabilityTest {
    param ($iteration)

    $wsev2PolicyState = CheckWSEV2Policy

    # Tweak camera to use the highest resolution
    $videoResName = SetHighestVideoResolutionInCameraApp

    $assessmentScenario = if ($wsev2PolicyState) {
        $WSE_ALL_CAMERA_EFFECTS_SCENARIO_V2
    } else {
        $WSE_ALL_CAMERA_EFFECTS_SCENARIO_V1
    }

    # Toggle all effects on
    Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to toggle all effects On" -IsOutput
    ToggleAIEffectsInSettingsApp -AFVal "On" -AFSVal "True" -AFCVal "False" `
                                 -PLVal "On" `
                                 -BBVal "On" -BSVal "False" -BPVal "True" `
                                 -ECVal "On" -ECSVal "True" -ECTVal "False" `
                                 -VFVal "Off" `
                                 -CF "On" -CFI "False" -CFA "True" -CFW "False"

    # Check if frame server is stopped
    CheckServiceState 'Windows Camera Frame Server'

    for ($iter = 1; $iter -le $iteration; $iter++) {
        Write-Log -Message "`nCameraReliabilityTest [$iter / $iteration] rounds" -IsHost

        if (-not (VerifyVideoMode $assessmentScenario $videoResName $iter)) {
            Write-Log -Message "Video mode for run ${iter}: FAIL" -IsHost -ForegroundColor Red
        } else {
            Write-Log -Message "Video mode for run ${iter}: PASS" -IsHost -ForegroundColor Green
        }

        if (-not (VerifyPhotoMode $iter)) {
            Write-Log -Message "Photo mode for run ${iter}: FAIL" -IsHost -ForegroundColor Red
        } else {
            Write-Log -Message "Photo mode for run ${iter}: PASS" -IsHost -ForegroundColor Green
        }
    }

    # Restore the default state for AI effects
    Write-Log -Message "Entering ToggleAIEffectsInSettingsApp function to Restore the default state for AI effects" `
              -IsOutput
    ToggleAIEffectsInSettingsApp -AFVal "Off" -AFSVal "False" -AFCVal "False"`
                                 -PLVal "Off" `
                                 -BBVal "Off" -BSVal "False" -BPVal "False" `
                                 -ECVal "Off" -ECSVal "False" -ECTVal "False" `
                                 -VFVal "Off" `
                                 -CF "Off" -CFI "False" -CFA "False" -CFW "False"
}

# Load helper library and initialize test
.".\CheckInTest\Helper-library.ps1"
InitializeTest 'CameraReliabilityTest' `
               $targetMepCameraVer `
               $targetMepAudioVer `
               $targetPerceptionCoreVer

# If the user does not specify the iteration parameter, default to NUMBER_OF_ITERATION.
if ($iteration -eq 0) {
   $iteration = $NUMBER_OF_ITERATION
}

Set-SystemSettingsInCamera
CameraReliabilityTest $iteration