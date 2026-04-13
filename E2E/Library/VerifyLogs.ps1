<#
DESCRIPTION:
    This function verifies PerceptionSessionUsageStats logs for a given scenario. It checks for 
    specific scenario IDs, validates frame processing times, and logs results. It also verifies 
    memory usage events if present.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for organizing and locating logs.
    - snarioId [string] :- The scenario ID used to identify specific log entries.
    - strtTime [datetime] :- The start time of the scenario, used for calculating durations.
RETURN TYPE:
    - [bool] (Returns `$false` if asg trace is missing in the specified folder or if the target scenario ID was not found; otherwise, returns `$true`)
#>

if (-not (Get-Command Get-TraceFmtTimestamp -ErrorAction SilentlyContinue))
{
    $traceFmtLib = Join-Path $PSScriptRoot 'TraceFmtParsing.ps1'
    if (Test-Path -LiteralPath $traceFmtLib) { . $traceFmtLib }
}

function VerifyLogs($snarioName, $snarioId, $strtTime)
{
    $pathAsgTraceTxt  = Get-AsgTraceFmtPath $snarioName
    Write-Log -Message "Validating AsgTraceFmt.txt logs" -IsOutput

    if (-not (Test-Path -Path $pathAsgTraceTxt))
    {
        TestOutputMessage $snarioName "Fail" $strtTime "$pathAsgTraceTxt not found "
        Write-Log -Message "$pathAsgTraceTxt not found " -IsHost
        Write-Output "$pathAsgTraceTxt not found " >> "$pathLogsFolder\ConsoleResults.txt"
        return $false
    }

    # Populate $Results from the extractor script (dot-sourced)
    $expected = [int64]$snarioId

    Write-Log -Message "PopulateResultsFromTraceFmt: snarioName=$snarioName, expectedScenario=$expected" -IsOutput
    Write-Log -Message "PerceptionExtractScript: $Global:PerceptionExtractScript" -IsOutput
    Write-Log -Message "AsgTraceFmt.txt exists: $(Test-Path $pathAsgTraceTxt)" -IsOutput

    try {
        [void](PopulateResultsFromTraceFmt $snarioName $expected)
        Write-Log -Message "PopulateResultsFromTraceFmt succeeded. Results.PerceptionScenarioId=$($Results.PerceptionScenarioId)" -IsOutput
    } catch {
        TestOutputMessage $snarioName "Fail" $strtTime "Failed to extract PerceptionSessionUsageStats for PerceptionScenario=$expected"
        Write-Log -Message "EXCEPTION in PopulateResultsFromTraceFmt: $_" -IsHost
        Write-Log -Message "Exception details: $($_.Exception.Message)" -IsHost
        Write-Output "Failed to extract Results for PerceptionScenario=$expected. Error: $_" >> "$pathLogsFolder\ConsoleResults.txt"
        return $false
    }

    # In new format: scenarioId maps to PerceptionScenario
    $actual   = $null
    try { $actual = [int64]$Results.PerceptionScenarioId } catch { $actual = $null }

    if ($actual -ne $expected)
    {
        TestOutputMessage $snarioName "Fail" $strtTime "[PerceptionScenario:$expected] was not found."
        Write-Log -Message "[PerceptionScenario:$expected] was not found. (Extracted PerceptionScenario=$actual). Logs saved at $pathAsgTraceTxt" -IsHost
        Write-Output "[PerceptionScenario:$expected] was not found. (Extracted PerceptionScenario=$actual). Logs saved at $pathAsgTraceTxt" >> "$pathLogsFolder\ConsoleResults.txt"
        return $false
    }

    # Pass path
    TestOutputMessage $snarioName "Pass" $strtTime
    GenericError $snarioName

    # Ensure ScenarioName reflects current scenario folder/run name
    $Results.ScenarioName = $snarioName

    # Frame processing metrics (already extracted into $Results)
    $metrics = Write-PerceptionFrameProcessingMetricsFromResults -ResultsObject $Results

    # Init time (tracefmt text lines)
    CheckInitTimePCOnly $snarioName $snarioId

    Write-PerceptionFrameProcessingWarningsFromMetrics -Metrics $metrics -TracePath $pathAsgTraceTxt -ConsoleResultsPath "$pathLogsFolder\ConsoleResults.txt"

    # Memory (now extracted; function handles missing fields)
    CheckMemoryUsage $snarioName

    return $true
}

function GenericError($snarioName)
{
    # Centralized tracefmt GenericError scanning
    Write-TraceFmtGenericErrors -SnarioName $snarioName -OutputFile "$pathLogsFolder\ConsoleResults.txt"
}

<#
DESCRIPTION:
    This function retrieves the start and first frame processing times from PerceptionSessionUsageStats
    logs for a given scenario ID.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for locating relevant logs.
    - snarioId [string] :- The scenario ID used to filter log entries.
RETURN TYPE:
    - array (Returns an array containing the start time and first frame time if found, otherwise returns $false.)
#>
function PCStartandFirstFrameTime($snarioName, $snarioId)
{
    $pathAsgTraceTxt  = "$pathLogsFolder\$snarioName\AsgTraceFmt.txt"

    if (-not (Test-Path -Path $pathAsgTraceTxt)) {
        return $false
    }

    $startPattern = '"text"\s*:\s*"starting Microsoft\.ASG\.Perception'
    $firstPattern = '"text"\s*:\s*"First frame for PerceptionCore'

    return (Get-TraceFmtStartAndFirstFrameTime -Path $pathAsgTraceTxt -StartPattern $startPattern -FirstPattern $firstPattern)
}

<#
DESCRIPTION:
    This function calculates and logs the initialization time from when the camera app starts 
    until the first frame is processed.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for locating relevant logs.
    - snarioId [string] :- The scenario ID used to filter log entries.
    - camAppStatTme [datetime] :- The timestamp when the camera app was started.
RETURN TYPE:
    - void (Calculates and logs initialization time without returning a value.)
#>
function CheckInitTimePCOnly($snarioName, $snarioId)
{
    [void](Set-InitTimePCOnlyFromTraceFmt -SnarioName $snarioName -SnarioId $snarioId)
}

<#
DESCRIPTION:
    This function calculates and logs the initialization times for the voice recorder app:
    from when the app starts and from when the recording begins until the first frame is processed.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for locating relevant logs.
    - snarioId [string] :- The scenario ID used to filter log entries.
    - voiceRecderAppStatTme [datetime] :- The timestamp when the voice recorder app was started.
    - audioRecdingStatTme [datetime] :- The timestamp when the audio recording was started.
RETURN TYPE:
    - void (Calculates and logs initialization times without returning a value.)
#>
function CheckInitTimeCameraApp($snarioName, $snarioId, $camAppStatTme)
{
    [void](Set-InitTimeCameraAppFromTraceFmt -SnarioName $snarioName -SnarioId $snarioId -CameraAppStartTimeUtc $camAppStatTme)
}

function CheckInitTimeVoiceRecorderApp($snarioName, $snarioId , $voiceRecderAppStatTme, $audioRecdingStatTme)
{
    [void](Set-InitTimeVoiceRecorderAppFromTraceFmt -SnarioName $snarioName -SnarioId $snarioId -VoiceRecorderAppStartTimeUtc $voiceRecderAppStatTme -AudioRecordingStartTimeUtc $audioRecdingStatTme)
}
<#
DESCRIPTION:
    This function verifies PerceptionSessionUsageStats logs specifically for audio blur scenarios.
    It validates frame processing times and logs results if audio blur is enabled.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for organizing and locating logs.
    - snarioId [string] :- The scenario ID used to identify specific log entries.
RETURN TYPE:
    - void (Performs validation and logging without returning a value.)
#>
function VerifyAudioBlurLogs($snarioName, $snarioId)
{
    $voiceFocusExists = CheckVoiceFocusPolicy
    if ($voiceFocusExists -eq $false) { return }

    $pathAsgTraceTxt = Get-AsgTraceFmtPath $snarioName
    Write-Log -Message "Validating AsgTraceFmt.txt logs for Audio Blur" -IsOutput
    if (-not (Test-Path $pathAsgTraceTxt)) { return }

    try { [void](PopulateResultsFromTraceFmt $snarioName ([int64]$snarioId)) } catch { return }

    $extractedScenario = $null
    try { $extractedScenario = [int64]$Results.PerceptionScenarioId } catch { $extractedScenario = $null }

    if ($extractedScenario -ne [int64]$snarioId)
    {
        Write-Log -Message "   [ScenarioID:$snarioId] was not found in extracted Results (PerceptionScenario=$extractedScenario)." -IsHost -ForegroundColor Red

        if ($Results.Status -eq "Fail") {
            Write-Output "[ScenarioID:$snarioId] was not found." >> "$pathLogsFolder\ConsoleResults.txt"
            $Results.ReasonForNotPass = "[ScenarioID:$snarioId] was not found."
        }
        elseif ($Results.Status -eq "Pass") {
            Write-Output "[ScenarioID:$snarioId] was not found. Test is marked as Pass as Camera effects ScenarioID was found." >> "$pathLogsFolder\ConsoleResults.txt"
        }
        else {
            Write-Output "[ScenarioID:$snarioId] was not found (Status: $($Results.Status))." >> "$pathLogsFolder\ConsoleResults.txt"
        }
        return
    }

    Write-Log -Message "Audio blur scenarioID - $snarioId found." -IsOutput

    CheckInitTimePCOnly $snarioName $snarioId

    $metrics = Get-PerceptionFrameProcessingMetricsFromResults -ResultsObject $Results

    $n = [int64]$metrics.FramesAbove33ms
    $min = [double]$metrics.MinMs
    $avg = [double]$metrics.AvgMs
    $max = [double]$metrics.MaxMs

    Write-Log -Message "NumberOfFramesAbove33msforAudioBlur: $n, Min:${min}ms, Avg:${avg}ms, Max:${max}ms" -IsOutput
    $Results.FramesAbove33msForAudioBlur = $n

    Write-PerceptionFrameProcessingWarningsFromMetrics -Metrics $metrics -TracePath $pathAsgTraceTxt -ConsoleResultsPath "$pathLogsFolder\ConsoleResults.txt" -HostCountLabel "NumberOfFramesAbove33msForAudioBlur" -ConsoleCountLabel "NumberOfFramesAbove33msforAudioBlur" -IncludeTracePathMessage:$false
}

<#
DESCRIPTION:
    This function checks for PrivateUsage, PeakWorkingSetSize, PageFaultCount, AvgWorkingSetSize.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for locating relevant logs.
RETURN TYPE:
    - void (Logs memory usage statistics and highlights high memory usage without returning a value.)
#>
function CheckMemoryUsage($snarioName)
{
    Test-MemoryUsageFromResults -SnarioName $snarioName -ResultsObject $Results -ConsoleResultsPath "$pathLogsFolder\ConsoleResults.txt"
}

function Get-AsgTraceFmtPath([string]$snarioName) {
    return "$pathLogsFolder\$snarioName\AsgTraceFmt.txt"
}

function PopulateResultsFromTraceFmt([string]$snarioName, [int64]$expectedScenario)
{
    return (Invoke-PerceptionExtractorFromTraceFmt -SnarioName $snarioName -ExpectedScenario $expectedScenario)
}
