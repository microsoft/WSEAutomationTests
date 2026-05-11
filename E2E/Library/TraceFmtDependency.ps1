<#
Shared dependency/setup helpers for TraceFmt.

Centralizes:
- Refreshing process env vars from persisted User/Machine values
- Ensuring TRACEFMT_EXE / TRACELOG_EXE are set and valid
- Bootstrapping via Setup-WinSdk.ps1 when needed
#>

function Update-UserEnv
{
    $env:TRACEFMT_EXE = [Environment]::GetEnvironmentVariable("TRACEFMT_EXE", "User")
    $env:TRACELOG_EXE = [Environment]::GetEnvironmentVariable("TRACELOG_EXE", "User")

    $machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath    = [Environment]::GetEnvironmentVariable("PATH", "User")

    if ($machinePath -and $userPath) {
        $env:PATH = $machinePath + ";" + $userPath
    }
    elseif ($machinePath) {
        $env:PATH = $machinePath
    }
    elseif ($userPath) {
        $env:PATH = $userPath
    }
}

function Initialize-TraceFmt
{
    param(
        [string]$SetupScriptPath = $null
    )

    Update-UserEnv

    # If set and valid, we're done
    if ($env:TRACEFMT_EXE -and (Test-Path -LiteralPath $env:TRACEFMT_EXE) -and
        $env:TRACELOG_EXE -and (Test-Path -LiteralPath $env:TRACELOG_EXE))
    {
        return
    }

    # Prefer Setup-WinSdk.ps1 if provided; else search common locations
    $candidates = @()
    if ($SetupScriptPath) { $candidates += $SetupScriptPath }

    $e2eRoot = $null
    try { $e2eRoot = Split-Path -Parent $Global:ScriptRoot } catch { $e2eRoot = $null }

    $candidates += @(
        (Join-Path $Global:ScriptRoot "Setup-WinSdk.ps1"),
        (Join-Path $PSScriptRoot      "Setup-WinSdk.ps1"),
        ($(if ($e2eRoot) { Join-Path (Join-Path $e2eRoot 'LoggerBinaries') 'Setup-WinSdk.ps1' } else { $null }))
    )

    $setupScript = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1

    if (-not $setupScript) {
        throw "TRACEFMT_EXE is not set or invalid, and Setup-WinSdk.ps1 was not found. Place Setup-WinSdk.ps1 next to the scripts or pass its path."
    }

    Write-Host "[INFO] TraceFmt not initialized. Running setup: $setupScript"
    & $setupScript

    Update-UserEnv

    if (-not $env:TRACEFMT_EXE -or -not (Test-Path -LiteralPath $env:TRACEFMT_EXE)) {
        throw "TraceFmt setup ran, but TRACEFMT_EXE is still missing/invalid."
    }

    if (-not $env:TRACELOG_EXE -or -not (Test-Path -LiteralPath $env:TRACELOG_EXE)) {
        throw "TraceFmt setup ran, but TRACELOG_EXE is still missing/invalid."
    }

    Write-Host "[INFO] Using TraceFmt: $env:TRACEFMT_EXE"
}
