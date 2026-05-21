param(
    [string]$LogsFolder = $null
)

$ErrorActionPreference = 'Stop'

Set-Location (Split-Path -Parent $PSScriptRoot)  # AcceptanceTests\E2E

. .\CheckInTest\Helper-library.ps1
InitializeTest 'Smoke'

if ($LogsFolder) {
    $resolvedLogsFolder = Resolve-Path $LogsFolder -ErrorAction Stop
    $pathLogsFolder = $resolvedLogsFolder.Path
}
else {
    $logsRoot = Join-Path (Get-Location) 'Logs'
    if (-not (Test-Path -LiteralPath $logsRoot)) {
        throw "Logs folder not found: $logsRoot. Pass -LogsFolder with an existing test run path."
    }

    $newestExistingRun = Get-ChildItem -Path $logsRoot -Directory |
        Where-Object { $_.FullName -ne (Resolve-Path $Global:pathLogsFolder).Path } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $newestExistingRun) {
        throw "No existing log runs were found under $logsRoot. Pass -LogsFolder with an existing test run path."
    }

    $pathLogsFolder = $newestExistingRun.FullName
}

$Global:pathLogsFolder = $pathLogsFolder
Write-Output "Using logs folder: $pathLogsFolder"

. .\Library\TraceFmtParsing.ps1

$ok = Invoke-PerceptionExtractorFromTraceFmt -SnarioName 'Pluggedin\AFS' -ExpectedScenario 65536
Write-Output "OK=$ok"

$Global:Results |
    Select-Object ScenarioName, SessionName, PerceptionScenarioId, MatchedScenarioId, FramesAbove33ms, TotalNumberOfFrames, fps,
        'AvgProcessingTimePerFrame(In ms)', 'MaxProcessingTimePerFrame(In ms)', 'MinProcessingTimePerFrame(In ms)' |
    Format-List |
    Out-String |
    Write-Output
