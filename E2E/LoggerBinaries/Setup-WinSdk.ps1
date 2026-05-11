# Setup-WinSdk.ps1
# One-time dependency check + install + env var setup for TraceFmt (Windows SDK)

$ErrorActionPreference = "Stop"

function Write-Info($msg)  { Write-Host "[INFO]  $msg" }
function Write-Warn($msg)  { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err ($msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Add-ToUserPathIfMissing {
    param([Parameter(Mandatory=$true)][string]$Dir)

    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if (-not $userPath) { $userPath = "" }

    # PATH is semicolon-separated; do a case-insensitive exact match check.
    $parts = $userPath -split ';' | Where-Object { $_ -and $_.Trim() -ne "" }
    $already = $parts | Where-Object { $_.TrimEnd('\') -ieq $Dir.TrimEnd('\') }

    if ($already) {
        Write-Info "PATH already contains: $Dir"
        return
    }

    $newUserPath = if ($userPath.Trim()) { "$userPath;$Dir" } else { $Dir }
    [Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
    Write-Info "Added to User PATH: $Dir"
}

function Get-TraceFmtCandidate {
    # Choose arch based on *process* architecture (important on ARM64 Windows).
    $procArch = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
    switch ($procArch) {
        "Arm64" { $sdkArch = "arm64" }
        "X64"   { $sdkArch = "x64" }
        "X86"   { $sdkArch = "x86" }
        default { throw "Unsupported process architecture: $procArch" }
    }

    $rootsKey = "HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots"
    if (-not (Test-Path $rootsKey)) { return $null }

    $kitsRoot = (Get-ItemProperty $rootsKey).KitsRoot10
    if (-not $kitsRoot -or -not (Test-Path $kitsRoot)) { return $null }

    $binRoot = Join-Path $kitsRoot "bin"

    # Find newest tracefmt/tracelog for the chosen arch (version-agnostic)
    $tracefmtFound = Get-ChildItem $binRoot -Recurse -Filter tracefmt.exe -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -match "\\$sdkArch\\" } |
             Sort-Object FullName -Descending |
             Select-Object -First 1

    $tracelogFound = Get-ChildItem $binRoot -Recurse -Filter tracelog.exe -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -match "\\$sdkArch\\" } |
             Sort-Object FullName -Descending |
             Select-Object -First 1

    if (-not $tracefmtFound -or -not $tracelogFound) { return $null }

    return [pscustomobject]@{
        ProcessArchitecture = $procArch
        SdkArch             = $sdkArch
        KitsRoot10          = $kitsRoot
        TraceFmtPath        = $tracefmtFound.FullName
        TraceFmtDir         = $tracefmtFound.Directory.FullName
        TraceLogPath        = $tracelogFound.FullName
        TraceLogDir         = $tracelogFound.Directory.FullName
    }
}

# --- 1) Check winget ---
Write-Info "Checking winget..."
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from Microsoft Store (or ensure winget is available) and rerun."
}
Write-Info "winget OK."

# --- 2) Check TraceFmt before install ---
Write-Info "Checking for tracefmt.exe in installed Windows SDK..."
$candidate = Get-TraceFmtCandidate

# If not found, install SDK via winget
if (-not $candidate) {
    Write-Warn "tracefmt.exe not found. Installing Windows SDK (Microsoft.WindowsSDK.10.0.26100)..."

    $logPath = Join-Path $env:USERPROFILE "Desktop\sdk-install.log"
    # Install (silent-ish) and log
    winget install --source winget --exact --id Microsoft.WindowsSDK.10.0.26100 --log $logPath

    Write-Info "Install completed (log: $logPath). Re-checking..."
    $candidate = Get-TraceFmtCandidate
}

if (-not $candidate) {
    throw "Windows SDK tools still not found after install (tracefmt/tracelog). Check sdk-install.log and confirm Windows SDK installed correctly."
}

Write-Info "Found TraceFmt:"
Write-Host "        ProcessArch : $($candidate.ProcessArchitecture)"
Write-Host "        SDK arch     : $($candidate.SdkArch)"
Write-Host "        KitsRoot10   : $($candidate.KitsRoot10)"
Write-Host "        TraceFmt.exe : $($candidate.TraceFmtPath)"
Write-Host "        TraceLog.exe : $($candidate.TraceLogPath)"

# --- 3) Set env var TRACEFMT_EXE ---
$existing = [Environment]::GetEnvironmentVariable("TRACEFMT_EXE", "User")
if ($existing -and ($existing -ieq $candidate.TraceFmtPath)) {
    Write-Info "TRACEFMT_EXE already set correctly."
} else {
    [Environment]::SetEnvironmentVariable("TRACEFMT_EXE", $candidate.TraceFmtPath, "User")
    Write-Info "Set TRACEFMT_EXE (User) = $($candidate.TraceFmtPath)"
}

# --- 3b) Set env var TRACELOG_EXE ---
$existingTraceLog = [Environment]::GetEnvironmentVariable("TRACELOG_EXE", "User")
if ($existingTraceLog -and ($existingTraceLog -ieq $candidate.TraceLogPath)) {
    Write-Info "TRACELOG_EXE already set correctly."
} else {
    [Environment]::SetEnvironmentVariable("TRACELOG_EXE", $candidate.TraceLogPath, "User")
    Write-Info "Set TRACELOG_EXE (User) = $($candidate.TraceLogPath)"
}


# --- 4) Ensure PATH contains TraceFmt directory ---
Add-ToUserPathIfMissing -Dir $candidate.TraceFmtDir

# --- 4b) Ensure PATH contains TraceLog directory ---
Add-ToUserPathIfMissing -Dir $candidate.TraceLogDir


# --- 5) Verify in current session (no restart needed) ---
# Refresh this session's env vars (User vars are not auto-loaded into current process)
$env:TRACEFMT_EXE = [Environment]::GetEnvironmentVariable("TRACEFMT_EXE", "User")
$env:TRACELOG_EXE = [Environment]::GetEnvironmentVariable("TRACELOG_EXE", "User")
$env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + `
            [Environment]::GetEnvironmentVariable("PATH", "User")

Write-Info "Verifying TraceFmt runs..."
& $env:TRACEFMT_EXE -h | Out-Null
Write-Info "TraceFmt works."

Write-Info "Verifying TraceLog runs..."
& $env:TRACELOG_EXE -h | Out-Null
Write-Info "TraceLog works."


Write-Host ""
Write-Info "Done."
Write-Host "You can now run: tracefmt -h"
Write-Host "Or in scripts:  & `$env:TRACEFMT_EXE <args>"

