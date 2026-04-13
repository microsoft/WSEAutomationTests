$ErrorActionPreference = 'Stop'

Set-Location (Split-Path -Parent $PSScriptRoot)  # AcceptanceTests\E2E

. .\CheckInTest\Helper-library.ps1
InitializeTest 'Smoke'

$Global:PerceptionExtractScript = (Resolve-Path .\Helper\Extract-PerceptionSessionUsageStats-TraceFmt.ps1).Path
$pathLogsFolder = (Resolve-Path .\Logs\2026-02-11-19-16-55-Checkin-Test).Path

. .\Library\TraceFmtParsing.ps1

$ok = Invoke-PerceptionExtractorFromTraceFmt -SnarioName 'Pluggedin\AFS' -ExpectedScenario 65536
Write-Output "OK=$ok"

$Global:Results |
    Select-Object ScenarioName, SessionName, PerceptionScenarioId, MatchedScenarioId, FramesAbove33ms, TotalNumberOfFrames, fps,
        'AvgProcessingTimePerFrame(In ms)', 'MaxProcessingTimePerFrame(In ms)', 'MinProcessingTimePerFrame(In ms)' |
    Format-List |
    Out-String |
    Write-Output
