<#
Shared helpers for parsing tracefmt output (AsgTraceFmt.txt).

This centralizes:
- Locating per-scenario AsgTraceFmt.txt
- Extracting embedded JSON payload from tracefmt lines
- Parsing the tracefmt timestamp format
- Common queries (PerceptionScenario presence, provider start/stop pairing, GenericError lines)
#>

function Get-TraceFmtJsonFromLine
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    $m = [regex]::Match($Line, '(\{.*\})\s*$')
    if (-not $m.Success) {
        return $null
    }

    try {
        return $m.Groups[1].Value | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Get-TraceFmtTimestamp
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    # Captures "01/27/2026-13:33:33.088" from: [TID]PID.TID::MM/dd/yyyy-HH:mm:ss.fff ...
    $m = [regex]::Match(
        $Line,
        '::(?<ts>\d{2}/\d{2}/\d{4}-\d{2}:\d{2}:\d{2}\.\d{3})'
    )

    if (-not $m.Success) {
        return $null
    }

    try {
        $localTime = [DateTime]::ParseExact(
            $m.Groups['ts'].Value,
            'MM/dd/yyyy-HH:mm:ss.fff',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeLocal
        )

        return $localTime.ToUniversalTime()
    }
    catch {
        return $null
    }
}

function Test-TraceFmtContainsAnyPerceptionScenario
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [long[]]$ScenarioIds
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    foreach ($id in $ScenarioIds)
    {
        if (Select-String -Path $Path -Pattern ('"PerceptionScenario"\s*:\s*' + [Regex]::Escape($id.ToString())) -Quiet) {
            return $true
        }
    }

    return $false
}

function Get-TraceFmtProviderStartStopCounts
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$ProviderName = 'Microsoft.ASG.Perception'
    )

    $result = [ordered]@{
        ProviderName = $ProviderName
        Started = @{}
        Stopped = @{}
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        return $result
    }

    $escaped = [Regex]::Escape($ProviderName)
    $startPattern = '"text"\s*:\s*"starting ' + $escaped + ' provider (?<ptr>0x[0-9A-Fa-f]+) (?<id>0x[0-9A-Fa-f]+)"'
    $stopPattern  = '"text"\s*:\s*"stopping '  + $escaped + ' provider (?<ptr>0x[0-9A-Fa-f]+) (?<id>0x[0-9A-Fa-f]+)"'

    foreach ($line in Get-Content -LiteralPath $Path)
    {
        $m = [regex]::Match($line, $startPattern)
        if ($m.Success)
        {
            $key = "$($m.Groups['ptr'].Value) $($m.Groups['id'].Value)"
            $result.Started[$key] = 1 + [int]($result.Started[$key])
            continue
        }

        $m = [regex]::Match($line, $stopPattern)
        if ($m.Success)
        {
            $key = "$($m.Groups['ptr'].Value) $($m.Groups['id'].Value)"
            $result.Stopped[$key] = 1 + [int]($result.Stopped[$key])
        }
    }

    return $result
}

function Get-TraceFmtGenericErrors
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    $pattern = 'GenericError'
    return @(Select-String -Path $Path -Pattern $pattern)
}

function Get-TraceFmtStartAndFirstFrameTime
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$StartPattern,

        [Parameter(Mandatory = $true)]
        [string]$FirstPattern
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $startTime = $null

    # Scan top-to-bottom and return the FIRST complete (start -> first frame) pair.
    foreach ($line in Get-Content -LiteralPath $Path)
    {
        # Lock onto the FIRST start timestamp.
        if (-not $startTime -and ($line -match $StartPattern))
        {
            $t = Get-TraceFmtTimestamp -Line $line
            if ($t) { $startTime = $t }
            continue
        }

        # Return the FIRST first-frame timestamp that occurs at/after the first start.
        if ($startTime -and ($line -match $FirstPattern))
        {
            $t = Get-TraceFmtTimestamp -Line $line
            if ($t -and $t -ge $startTime) {
                return @($startTime, $t)
            }
        }
    }

    return $false
}

function Get-TraceFmtPCStartAndFirstFrameTime
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$SnarioName
    )

    $path = "$pathLogsFolder\$SnarioName\AsgTraceFmt.txt"
    $startPattern = '"text"\s*:\s*"starting Microsoft\.ASG\.Perception'
    $firstPattern = '"text"\s*:\s*"First frame for PerceptionCore'

    return (Get-TraceFmtStartAndFirstFrameTime -Path $path -StartPattern $startPattern -FirstPattern $firstPattern)
}

function Set-InitTimePCOnlyFromTraceFmt
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$SnarioName,

        [Parameter(Mandatory = $true)]
        [string]$SnarioId
    )

    $times = Get-TraceFmtPCStartAndFirstFrameTime -SnarioName $SnarioName
    if ($times -eq $false)
    {
        Write-Log -Message "   No match found for PC Time To First Frame in AsgTraceFmt.txt for Scenario $SnarioId." -IsHost -ForegroundColor Yellow
        Write-Output "No match found for PC Time To First Frame in AsgTraceFmt.txt for Scenario $SnarioId." >> "$pathLogsFolder\ConsoleResults.txt"
        return $false
    }

    $PCStartTime = $times[0]
    $PCFirstFrameTime = $times[1]

    $InitTimePCOnly = [math]::Round((New-TimeSpan -Start $PCStartTime -End $PCFirstFrameTime).TotalSeconds, 4)
    Write-Log -Message "PC Time To First Frame: ${InitTimePCOnly}secs" -IsOutput

    if ($SnarioId -eq '512') {
        $Results.'timetofirstframeForAudio(In secs)' = $InitTimePCOnly
    } else {
        $Results.'timetofirstframe(In secs)' = $InitTimePCOnly
    }

    return $true
}

function Set-InitTimeCameraAppFromTraceFmt
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$SnarioName,

        [Parameter(Mandatory = $true)]
        [string]$SnarioId,

        [Parameter(Mandatory = $true)]
        [datetime]$CameraAppStartTimeUtc
    )

    $times = Get-TraceFmtPCStartAndFirstFrameTime -SnarioName $SnarioName
    if ($times -eq $false) { return $false }

    $PCFirstFrameTime = $times[1]

    Write-Output "Camera App Start Time: $CameraAppStartTimeUtc" >> "$pathLogsFolder\ConsoleResults.txt"
    Write-Output "PC First Frame Time: $PCFirstFrameTime" >> "$pathLogsFolder\ConsoleResults.txt"

    $InitTimeCameraApp = [math]::Round((New-TimeSpan -Start $CameraAppStartTimeUtc -End $PCFirstFrameTime).TotalSeconds, 4)
    Write-Log -Message "Time from camera app started until PC trace first frame processed: ${InitTimeCameraApp}secs" -IsOutput
    $Results.'CameraAppInItTime(In secs)' = $InitTimeCameraApp
    return $true
}

function Set-InitTimeVoiceRecorderAppFromTraceFmt
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$SnarioName,

        [Parameter(Mandatory = $true)]
        [string]$SnarioId,

        [Parameter(Mandatory = $true)]
        [datetime]$VoiceRecorderAppStartTimeUtc,

        [Parameter(Mandatory = $true)]
        [datetime]$AudioRecordingStartTimeUtc
    )

    $times = Get-TraceFmtPCStartAndFirstFrameTime -SnarioName $SnarioName
    if ($times -eq $false) { return $false }

    $PCFirstFrameTime = $times[1]

    $InitTimeFromVoiceRecorderAppStarts = [math]::Round((New-TimeSpan -Start $VoiceRecorderAppStartTimeUtc -End $PCFirstFrameTime).TotalSeconds, 4)
    Write-Log -Message "Time from voiceRecorder app started until PC trace first frame processed: ${InitTimeFromVoiceRecorderAppStarts}secs" -IsOutput

    $InitTimeFromAudioRecordingStarts = [math]::Round((New-TimeSpan -Start $AudioRecordingStartTimeUtc -End $PCFirstFrameTime).TotalSeconds, 4)
    Write-Log -Message "Time from record button was pressed until PC trace first frame processed: ${InitTimeFromAudioRecordingStarts}secs" -IsOutput

    $Results.'VoiceRecorderInItTime(In secs)' = $InitTimeFromAudioRecordingStarts
    return $true
}

function Write-TraceFmtGenericErrors
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$SnarioName,

        [string]$OutputFile = "$pathLogsFolder\ConsoleResults.txt"
    )

    $pathAsgTraceFmtTxt = "$pathLogsFolder\$SnarioName\AsgTraceFmt.txt"
    if (-not (Test-Path -LiteralPath $pathAsgTraceFmtTxt)) {
        return
    }

    $genericErrorLogs = @(Get-TraceFmtGenericErrors -Path $pathAsgTraceFmtTxt)
    for ($i = 0; $i -lt $genericErrorLogs.Count; $i++)
    {
        $line = $genericErrorLogs[$i].Line
        if ($line -match 'Orientation sensor hardware not detected') {
            continue
        }

        Write-Log -Message "GenericError - $line" -IsHost -BackgroundColor Red
        if ($OutputFile) {
            Write-Output "GenericError - $line" >> $OutputFile
        }
    }
}

function Write-PerceptionFrameProcessingMetricsFromResults
{
    param(
        [Parameter(Mandatory = $true)]
        $ResultsObject
    )

    $metrics = Get-PerceptionFrameProcessingMetricsFromResults -ResultsObject $ResultsObject

    # Important: do not write to the output stream here.
    # Callers frequently assign the return value: $m = Write-PerceptionFrameProcessingMetricsFromResults ...
    # Write-Log -IsOutput would add a string to the pipeline and turn $m into an array, breaking StrictMode property access.
    # Console output is handled by Write-PerceptionFrameProcessingWarningsFromMetrics to ensure consistent gating.

    return $metrics
}

function Get-PerceptionFrameProcessingMetricsFromResults
{
    param(
        [Parameter(Mandatory = $true)]
        $ResultsObject
    )

    $metrics = [ordered]@{
        FramesAbove33ms = 0L
        TotalNumberOfFrames = 0L
        MinMs = 0.0
        AvgMs = 0.0
        MaxMs = 0.0
    }

    try { $metrics.FramesAbove33ms = [int64]($ResultsObject.FramesAbove33ms) } catch { $metrics.FramesAbove33ms = 0L }
    try { $metrics.TotalNumberOfFrames = [int64]($ResultsObject.TotalNumberOfFrames) } catch { $metrics.TotalNumberOfFrames = 0L }
    try { $metrics.MinMs = [double]($ResultsObject.'MinProcessingTimePerFrame(In ms)') } catch { $metrics.MinMs = 0.0 }
    try { $metrics.AvgMs = [double]($ResultsObject.'AvgProcessingTimePerFrame(In ms)') } catch { $metrics.AvgMs = 0.0 }
    try { $metrics.MaxMs = [double]($ResultsObject.'MaxProcessingTimePerFrame(In ms)') } catch { $metrics.MaxMs = 0.0 }

    return $metrics
}

function Write-PerceptionFrameProcessingWarningsFromMetrics
{
    param(
        [Parameter(Mandatory = $true)]
        $Metrics,

        [Parameter(Mandatory = $true)]
        [string]$TracePath,

        [string]$ConsoleResultsPath = "$pathLogsFolder\ConsoleResults.txt",

        [string]$HostCountLabel = "NumberOfFramesAbove33ms",

        [string]$ConsoleCountLabel = "NumberOfFramesAbove33ms",

        [bool]$IncludeTracePathMessage = $true
    )

    # Defensive: if a caller accidentally captured pipeline output, Metrics may be an array.
    if ($Metrics -is [array]) {
        $Metrics = $Metrics | Where-Object { $_ -is [hashtable] -or $_.PSObject.Properties.Count -gt 0 } | Select-Object -Last 1
    }

    $n = 0L
    try { $n = [int64]$Metrics.FramesAbove33ms } catch { $n = 0L }
    if ($n -le 0) {
        return
    }

    $total = 0L
    try { $total = [int64]$Metrics.TotalNumberOfFrames } catch { $total = 0L }

    $min = 0.0
    $avg = 0.0
    $max = 0.0
    try { $min = [double]$Metrics.MinMs } catch { $min = 0.0 }
    try { $avg = [double]$Metrics.AvgMs } catch { $avg = 0.0 }
    try { $max = [double]$Metrics.MaxMs } catch { $max = 0.0 }

    # Print frame info ONLY when frames above 33ms is greater than 1
    if ($n -gt 1) {
        $hostMessage = ("   {0}: {1}, TotalFrames: {2}, Min: {3}ms, Avg: {4}ms, Max: {5}ms" -f $HostCountLabel, $n, $total, $min, $avg, $max)
        Write-Log -Message $hostMessage -IsHost -ForegroundColor Red

        if ($ConsoleResultsPath) {
            $consoleMessage = ("{0}: {1}, TotalFrames: {2}, Min: {3}ms, Avg: {4}ms, Max: {5}ms" -f $ConsoleCountLabel, $n, $total, $min, $avg, $max)
            Write-Output $consoleMessage >> $ConsoleResultsPath
        }
    }

    if (-not $IncludeTracePathMessage) {
        return
    }

    $resolved = $TracePath
    try { $resolved = (Resolve-Path -LiteralPath $TracePath).Path } catch { $resolved = $TracePath }
    Write-Log -Message "AsgTraceLog saved here: $resolved" -IsHost
    if ($ConsoleResultsPath) {
        Write-Output "AsgTraceLog saved here: $resolved" >> $ConsoleResultsPath
    }
}

function Test-MemoryUsageFromResults
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$SnarioName,

        [Parameter(Mandatory = $true)]
        $ResultsObject,

        [double]$AvgWorkingSetThresholdMb = 250,

        [string]$ConsoleResultsPath = "$pathLogsFolder\ConsoleResults.txt"
    )

    Write-Log -Message "Validating memory usage from extracted Results" -IsOutput

    if (-not $ResultsObject) {
        Write-Log -Message "Results not populated; skipping memory check." -IsOutput
        return
    }

    $peakWSRaw = $ResultsObject.'PeakWorkingSetSize(In MB)'
    $avgWSRaw  = $ResultsObject.'AvgWorkingSetSize(In MB)'
    $avgMemRaw = $ResultsObject.'AvgMemoryUsage(In GB)'

    $peakWS = $null
    $avgWS = $null
    $avgMem = $null

    try { if ($null -ne $peakWSRaw -and ("$peakWSRaw").Trim() -ne "") { $peakWS = [double]$peakWSRaw } } catch { $peakWS = $null }
    try { if ($null -ne $avgWSRaw -and ("$avgWSRaw").Trim() -ne "") { $avgWS = [double]$avgWSRaw } } catch { $avgWS = $null }
    try { if ($null -ne $avgMemRaw -and ("$avgMemRaw").Trim() -ne "") { $avgMem = [double]$avgMemRaw } } catch { $avgMem = $null }

    # MemoryCounters may be missing or reported as all-zero in some legacy builds.
    # Treat both as "not present" to avoid false failures.
    $hasAnyCounter = ($null -ne $peakWS -or $null -ne $avgWS -or $null -ne $avgMem)
    $hasAnyNonZeroCounter = (($null -ne $peakWS -and $peakWS -gt 0) -or ($null -ne $avgWS -and $avgWS -gt 0) -or ($null -ne $avgMem -and $avgMem -gt 0))
    if (-not $hasAnyCounter -or -not $hasAnyNonZeroCounter) {
        Write-Log -Message "Memory counters not present in trace for this run (or legacy counters reported as 0)." -IsOutput
        return
    }

    Write-Log -Message ("PeakWorkingSetSize:{0}MBs, AvgWorkingSetSize:{1}MBs, AvgMemoryUsage:{2}GBs" -f $peakWS, $avgWS, $avgMem) -IsOutput

    if ($null -ne $avgWS -and $avgWS -gt 0 -and [double]$avgWS -ge $AvgWorkingSetThresholdMb) {
        Write-Log -Message "AvgWorkingSetSize is greater than 250MBs [PeakWorkingSetSize:${peakWS}MBs, AvgWorkingSetSize:${avgWS}MBs, AvgMemoryUsage:${avgMem}GBs]" -IsHost -BackgroundColor Red
        if ($ConsoleResultsPath) {
            Write-Output "AvgWorkingSetSize is greater than 250MBs [PeakWorkingSetSize:${peakWS}MBs, AvgWorkingSetSize:${avgWS}MBs, AvgMemoryUsage:${avgMem}GBs]" >> $ConsoleResultsPath
        }
    }
}

function Invoke-PerceptionExtractorFromTraceFmt
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SnarioName,

        [Parameter(Mandatory = $true)]
        [int64]$ExpectedScenario
    )

    $pathAsgTraceFmtTxt = "$pathLogsFolder\$SnarioName\AsgTraceFmt.txt"

    if (-not (Test-Path -LiteralPath $pathAsgTraceFmtTxt)) {
        Write-Log -Message "WARN: AsgTraceFmt.txt not found at $pathAsgTraceFmtTxt" -IsHost
        return $false
    }

    if (-not $Global:PerceptionExtractScript -or -not (Test-Path -LiteralPath $Global:PerceptionExtractScript)) {
        $msg = "Extractor script not found: $Global:PerceptionExtractScript"
        Write-Log -Message $msg -IsHost
        throw $msg
    }

    Write-Verbose "Calling extractor with InputFile=$pathAsgTraceFmtTxt, PerceptionScenario=$ExpectedScenario"

    # If the trace file contains multiple appended runs, constrain matching to the most recent run.
    # We derive run start as the LAST "starting Microsoft.ASG.Perception" timestamp in the trace.
    $minTsUtc = $null
    try {
        $startPattern = '"text"\s*:\s*"starting Microsoft\.ASG\.Perception'
        foreach ($line in Get-Content -LiteralPath $pathAsgTraceFmtTxt) {
            if ($line -match $startPattern) {
                $t = Get-TraceFmtTimestamp -Line $line
                if ($t) { $minTsUtc = $t }
            }
        }
    } catch {
        $minTsUtc = $null
    }

    $inputToUse = $pathAsgTraceFmtTxt
    $tempFiltered = $null

    try {
        if ($minTsUtc)
        {
            $tempFiltered = Join-Path (Split-Path -Parent $pathAsgTraceFmtTxt) ('AsgTraceFmt.filtered.{0}.txt' -f ([Guid]::NewGuid().ToString('N')))
            Write-Verbose "Filtering trace to current run window (>= $minTsUtc) -> $tempFiltered"

            $outLines = New-Object System.Collections.Generic.List[string]
            foreach ($line in Get-Content -LiteralPath $pathAsgTraceFmtTxt)
            {
                $t = Get-TraceFmtTimestamp -Line $line
                if ($null -eq $t -or $t -ge $minTsUtc) {
                    $outLines.Add($line) | Out-Null
                }
            }

            Set-Content -LiteralPath $tempFiltered -Value $outLines -Encoding UTF8
            $inputToUse = $tempFiltered
        }

        . $Global:PerceptionExtractScript `
            -InputFile $inputToUse `
            -PerceptionScenario $ExpectedScenario `
            -FirstMatchOnly

        Write-Verbose "Extractor returned successfully"
    }
    catch {
        $msg = "Extractor failed: $_ | StackTrace: $($_.ScriptStackTrace)"
        Write-Log -Message $msg -IsHost
        throw $msg
    }
    finally {
        if ($tempFiltered -and (Test-Path -LiteralPath $tempFiltered)) {
            Remove-Item -LiteralPath $tempFiltered -Force -ErrorAction SilentlyContinue
        }
    }

    # Optional: confirm something got populated
    if (-not $Results -and $Global:Results) {
        Set-Variable -Name Results -Scope Global -Value $Global:Results
    }

    if (-not $Results) {
        Write-Log -Message "WARN: Results object is empty/null after extractor" -IsHost
        return $false
    }

    Write-Verbose "Results populated: PerceptionScenarioId=$($Results.PerceptionScenarioId)"
    return $true
}
