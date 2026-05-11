<#
DESCRIPTION:
    This function initializes the environment for a test run. It sets up global variables 
    for log storage, initializes result tracking structures, and validates the 
    WSE (Windows Subsystem for Enhanced) enabling status based on specified target versions.

    UPDATED:
    - Adds one-time dependency + setup checks for TraceFmt (Windows SDK) and required scripts.
    - Sets/refreshes TRACEFMT_EXE and PATH for the current session (User-scope persistence).

INPUT PARAMETERS:
    - TstsetNme [string] :- The name of the test set, used for naming log folders.
    - targetMepCameraVer [string] :- The target version of the MEP Camera component to be validated.
    - targetMepAudioVer [string] :- The target version of the MEP Audio component to be validated.
    - targetPerceptionCoreVer [string] :- The target version of the Perception Core component to be validated.
RETURN TYPE:
    - void
#>

function InitializeTest($TstsetNme, $targetMepCameraVer, $targetMepAudioVer, $targetPerceptionCoreVer)
{
    # -------------------------------
    # Resolve ScriptRoot robustly
    # -------------------------------
    $scriptRootVar = Get-Variable -Name ScriptRoot -Scope Global -ErrorAction SilentlyContinue
    if (-not $scriptRootVar -or -not $scriptRootVar.Value) {
        $Global:ScriptRoot = $PSScriptRoot
        if (-not $Global:ScriptRoot) {
            $invPath = $MyInvocation.MyCommand.Path
            if ($invPath) { $Global:ScriptRoot = Split-Path -Parent $invPath }
        }
        if (-not $Global:ScriptRoot) { $Global:ScriptRoot = (Get-Location).Path }
    }

    # -------------------------------
    # Dependency / setup checks
    # -------------------------------
    if (-not (Get-Command Initialize-TraceFmt -ErrorAction SilentlyContinue))
    {
        $e2eRoot = Split-Path -Parent $PSScriptRoot
        $traceFmtDep = Join-Path (Join-Path $e2eRoot 'Library') 'TraceFmtDependency.ps1'
        if (Test-Path -LiteralPath $traceFmtDep) { . $traceFmtDep }
    }

    # Ensure tracefmt is ready for downstream Extract-PerceptionSessionUsageStats-TraceFmt.ps1 usage
    if (-not (Get-Command Initialize-TraceFmt -ErrorAction SilentlyContinue)) {
        throw "Initialize-TraceFmt not found. Expected TraceFmtDependency.ps1 to be available under E2E\\Library."
    }

    Initialize-TraceFmt

    # -------------------------------
    # Logs folder + globals
    # -------------------------------
    $Global:pathLogsFolder = ".\Logs\" + "$((get-date).tostring('yyyy-MM-dd-HH-mm-ss'))" + "-$TstsetNme"
    New-Item -ItemType Directory -Force -Path $pathLogsFolder | Out-Null

    $Global:SequenceNumber = 0

    $Global:Results = '' | Select-Object ScenarioName, SessionName, PerceptionScenarioId, MatchedScenarioId, ScenarioMatchMode, ScenarioMatchOk, fps,TotalNumberOfFrames,FramesAbove33ms,
        'AvgProcessingTimePerFrame(In ms)','MaxProcessingTimePerFrame(In ms)','MinProcessingTimePerFrame(In ms)',
        'timetofirstframe(In secs)','CameraAppInItTime(In secs)','VoiceRecorderInItTime(In secs)',
        'timetofirstframeForAudio(In secs)',FramesAbove33msForAudioBlur,
        'PeakWorkingSetSize(In MB)','AvgWorkingSetSize(In MB)',
        'AvgNPUUsage(In %)','AvgCPUUsage(In %)' ,'AvgMemoryUsage(In GB)',
        'BeforeNPUUsage(In %)','BeforeCPUUsage(In %)','BeforeMemoryUsage(In GB)',
        Status,ReasonForNotPass

    Clear-CameraRollVideos
    # IMPORTANT: ensure $Results alias exists for other scripts
    Set-Variable -Name Results -Scope Global -Value $Global:Results

    $Global:validatedCameraFriendlyName = ""
    $Global:validatedSoundCaptureDeviceFriendlyName = ""

    # -------------------------------
    # Stable extractor path + validate it exists
    # -------------------------------
    $Global:PerceptionExtractScript = Join-Path $Global:ScriptRoot 'Extract-PerceptionSessionUsageStats-TraceFmt.ps1'
    if (-not (Test-Path $Global:PerceptionExtractScript)) {
        throw "Extractor script not found: $Global:PerceptionExtractScript"
    }

    # -------------------------------
    # Your existing validation gate
    # -------------------------------
    if ((WseEnablingStatus $targetMepCameraVer $targetMepAudioVer $targetPerceptionCoreVer) -eq $false) {
        Write-Error "WseEnablingStatus fail!"
        exit
    }
}


