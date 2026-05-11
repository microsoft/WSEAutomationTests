<#
.SYNOPSIS
  Extract PerceptionSessionUsageStats JSON events from a tracefmt/text log and populate $Global:Results,
  accepting either BASE scenario, BASE+LDC, (optional) BASE-32, and (optional) (BASE-32)+LDC.

.DESCRIPTION
  - Test input provides the BASE scenario id (e.g., 65536).
  - We consider a match valid if the log contains:
      1) base
      2) base + LDC_MASK (8388608)
      3) if base has bit 32 set: base - 32
      4) if base has bit 32 set: (base - 32) + LDC_MASK
  - By default we mimic old behavior: keep the LAST match found.
  - If -FirstMatchOnly is set, we stop at the FIRST match.

  Populates fields on the existing $Global:Results object (InitializeTest must create it):
    - PerceptionScenarioId     : requested base scenario
    - MatchedScenarioId        : scenario value found in log (could be base or base+LDC or base-32 variants)
    - ScenarioMatchMode        : "Base", "LDC", "Minus32", "Minus32+LDC"
    - SessionName
    - TotalNumberOfFrames
    - Avg/Max/MinProcessingTimePerFrame(In ms)
    - PeakWorkingSetSize(In MB), AvgWorkingSetSize(In MB) (if MemoryCounters exists)

  Prints:
    Scenario Match: Success   (green)

.PARAMETER InputFile
  Path to tracefmt/text log file.

.PARAMETER PerceptionScenario
  Base scenario id requested by the test.

.PARAMETER OutputFile
  Optional output file to append the Results object as compressed JSON (jsonl style).

.PARAMETER FirstMatchOnly
  Use first match instead of last match.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $true)]
    [int64]$PerceptionScenario,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile,

    [switch]$FirstMatchOnly
)

# ---------------------------------------
# Validation
# ---------------------------------------
if (-not (Test-Path -LiteralPath $InputFile)) {
    throw "Input file not found: $InputFile"
}

if ($OutputFile) {
    New-Item -ItemType File -Force -Path $OutputFile | Out-Null
}

# InitializeTest creates $Global:Results as a PSCustomObject with a fixed schema.
# Do NOT replace it; only populate fields.
if (-not $Global:Results) {
    throw "Global:Results is not initialized. Call InitializeTest first."
}

Set-Variable -Name Results -Scope Global -Value $Global:Results

# ---------------------------------------
# Clear extracted fields (avoid fill-forward)
# ---------------------------------------
# Always reset fields this script owns before populating from the matched JSON.
$Results.PerceptionScenarioId = $null
$Results.MatchedScenarioId = $null
$Results.ScenarioMatchMode = $null
$Results.ScenarioMatchOk = $null
$Results.SessionName = $null
$Results.TotalNumberOfFrames = $null
$Results.FramesAbove33ms = $null
$Results.'AvgProcessingTimePerFrame(In ms)' = $null
$Results.'MaxProcessingTimePerFrame(In ms)' = $null
$Results.'MinProcessingTimePerFrame(In ms)' = $null
$Results.'PeakWorkingSetSize(In MB)' = $null
$Results.'AvgWorkingSetSize(In MB)' = $null


# ---------------------------------------
# Scenario candidate generation
# ---------------------------------------
$LDC_MASK = 8388608
$base = [int64]$PerceptionScenario

$candidatesList = New-Object System.Collections.Generic.List[long]

# base + base+LDC
$candidatesList.Add($base) | Out-Null
$candidatesList.Add($base + $LDC_MASK) | Out-Null

# If base has bit 32 set, also try base-32 and (base-32)+LDC
$minus32 = $null
if ( ($base -band 32) -ne 0 ) {
    $minus32 = $base - 32
    if ($minus32 -ge 0) {
        $candidatesList.Add($minus32) | Out-Null
        $candidatesList.Add($minus32 + $LDC_MASK) | Out-Null
    }
}

# Dedup while preserving order
$seen = @{}
$candidates = @(
    $candidatesList | Where-Object {
        if ($seen.ContainsKey($_)) { $false }
        else { $seen[$_] = $true; $true }
    }
)

Write-Verbose "[Extractor] Requested(base) PerceptionScenario: $base"
Write-Verbose "[Extractor] Candidates: $($candidates -join ', ')"

# ---------------------------------------
# Scan + match
# ---------------------------------------
$lastMatch = $null
$lastScenarioMatched = $null
$linesScanned = 0
$jsonLinesSeen = 0
$matchesFound = 0

foreach ($line in Get-Content -LiteralPath $InputFile) {
    $linesScanned++

    if ($line -notmatch '\[PerceptionSessionUsageStats\]') { continue }
    if ($line -notmatch '\{.*\}') { continue }

    $jsonText = $matches[0]
    $jsonLinesSeen++

    try {
        $j = $jsonText | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Verbose ("[Extractor] JSON parse error on line {0}: {1}" -f $linesScanned, $_.Exception.Message)
        continue
    }

    if (-not ($j.PSObject.Properties.Name -contains 'PerceptionScenario')) { continue }

    $ps = [int64]$j.PerceptionScenario
    if ($candidates -notcontains $ps) { continue }

    $lastMatch = $j
    $lastScenarioMatched = $ps
    $matchesFound++

    if ($FirstMatchOnly) { break }
}

if (-not $lastMatch) {
    throw ("No PerceptionSessionUsageStats event found for requested scenario {0}. Tried candidates: {1}. Lines scanned: {2}. JSON lines seen: {3}. Matches found: {4}" -f `
        $base, ($candidates -join ", "), $linesScanned, $jsonLinesSeen, $matchesFound)
}

# ---------------------------------------
# Populate Results
# ---------------------------------------
$j = $lastMatch
$matched = [int64]$lastScenarioMatched

# Harness-friendly: keep requested base scenario
$Results.PerceptionScenarioId = $base

# What we actually matched in the log
$Results.MatchedScenarioId = $matched

# Determine match mode
$Results.ScenarioMatchMode = "Base"
if ($matched -eq ($base + $LDC_MASK)) {
    $Results.ScenarioMatchMode = "LDC"
}
elseif ($null -ne $minus32 -and $matched -eq $minus32) {
    $Results.ScenarioMatchMode = "Minus32"
}
elseif ($null -ne $minus32 -and $matched -eq ($minus32 + $LDC_MASK)) {
    $Results.ScenarioMatchMode = "Minus32+LDC"
}

# Convenience: whether match is acceptable for this base test
$Results.ScenarioMatchOk = ($candidates -contains $matched)

# Core fields
if ($j.PSObject.Properties.Name -contains 'SessionName') {
    $Results.SessionName = $j.SessionName
}

# Frames
if ($j.PSObject.Properties.Name -contains 'NumberOfProcessedFrames') {
    $Results.TotalNumberOfFrames = $j.NumberOfProcessedFrames
}

# Frames above 33ms (sum of histogram buckets >= 33ms)
# PerceptionSessionUsageStats provides buckets such as:
#   NumberOfFrames33msTo35ms, NumberOfFrames35msTo40ms, NumberOfFrames40msTo50ms, NumberOfFramesAbove50ms
$framesAbove33ms = 0L
foreach ($bucketName in @(
        'NumberOfFrames33msTo35ms',
        'NumberOfFrames35msTo40ms',
        'NumberOfFrames40msTo50ms',
        'NumberOfFramesAbove50ms'
    )) {
    if ($j.PSObject.Properties.Name -contains $bucketName) {
        try { $framesAbove33ms += [int64]$j.$bucketName } catch { }
    }
}
$Results.FramesAbove33ms = $framesAbove33ms

# Timing (guard each field)
if ($j.PSObject.Properties.Name -contains 'AverageProcessingTimePerFrameInNanoseconds') {
    $Results.'AvgProcessingTimePerFrame(In ms)' =
        [math]::Round([double]$j.AverageProcessingTimePerFrameInNanoseconds / 1e6, 2)
}

if ($j.PSObject.Properties.Name -contains 'MaximumProcessingTimePerFrameInNanoseconds') {
    $Results.'MaxProcessingTimePerFrame(In ms)' =
        [math]::Round([double]$j.MaximumProcessingTimePerFrameInNanoseconds / 1e6, 2)
}

if ($j.PSObject.Properties.Name -contains 'MinimumProcessingTimePerFrameInNanoseconds') {
    $Results.'MinProcessingTimePerFrame(In ms)' =
        [math]::Round([double]$j.MinimumProcessingTimePerFrameInNanoseconds / 1e6, 2)
}

if ($j.PSObject.Properties.Name -contains 'TimeToProcessedFrameInNanoseconds') {
    $timeToFirstFrame = [math]::Round([double]$j.TimeToProcessedFrameInNanoseconds / 1e9, 4)

    if ($base -eq 512) {
        $Results.'timetofirstframeForAudio(In secs)' = $timeToFirstFrame
    }
    else {
        $Results.'timetofirstframe(In secs)' = $timeToFirstFrame
    }
}

if ($j.PSObject.Properties.Name -contains 'MemoryCounters' -and $j.MemoryCounters) {

    if ($j.MemoryCounters.PSObject.Properties.Name -contains 'PeakWorkingSetSize') {
        $Results.'PeakWorkingSetSize(In MB)' =
            [math]::Round(([double]$j.MemoryCounters.PeakWorkingSetSize) / 1MB, 2)
    }

    if ($j.MemoryCounters.PSObject.Properties.Name -contains 'WorkingSetSize') {
        $Results.'AvgWorkingSetSize(In MB)' =
            [math]::Round(([double]$j.MemoryCounters.WorkingSetSize) / 1MB, 2)
    }
}

# Keep alias consistent
$Global:Results = $Results

# ---------------------------------------
# Console output
# ---------------------------------------
Write-Verbose "Scenario Match: Success"
Write-Verbose "Requested Scenario (base) : $($Results.PerceptionScenarioId)"
Write-Verbose "Matched Scenario (log)    : $($Results.MatchedScenarioId)"
Write-Verbose "Match Mode                : $($Results.ScenarioMatchMode)"
Write-Verbose "Candidates Tried          : $($candidates -join ', ')"
Write-Verbose "Lines Scanned             : $linesScanned"
Write-Verbose "Matches Found             : $matchesFound"
Write-Verbose "--------------------------------------------"

# ---------------------------------------
# Optional output file
# ---------------------------------------
if ($OutputFile) {
    ($Results | ConvertTo-Json -Depth 6 -Compress) | Add-Content -LiteralPath $OutputFile
}