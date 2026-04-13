<#
DESCRIPTION:
    This function initiates tracing for a specified scenario using the tracelog utility.
    It starts the trace session, enables system rundown tracing, and configures detailed trace logging.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for which tracing is initiated. This name is used to organize log files.
RETURN TYPE:
    - void (Starts the trace session and logs output without returning a value.)
#>

function Get-MepSdkToolPath {
    param(
        [Parameter(Mandatory = $true)][string]$EnvVar,
        [Parameter(Mandatory = $true)][string]$CommandName
    )

    $p = [Environment]::GetEnvironmentVariable($EnvVar, "User")
    if ($p -and (Test-Path -LiteralPath $p)) { return $p }

    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }

    return $null
}

function StartTrace($snarioName)
{   
    $tracelogExe = Get-MepSdkToolPath -EnvVar "TRACELOG_EXE" -CommandName "tracelog"
    if (-not $tracelogExe) {
        throw "tracelog.exe not found. Run LoggerBinaries\\Setup-WinSdk.ps1 to set TRACELOG_EXE."
    }
    if (!(Test-path -path "$pathLogsFolder\$snarioName" ))
    {
        CreateScenarioLogsFolder $snarioName
    }

    #Setting Scenario specific folders
    $pathAsgTraceETL = "$pathLogsFolder\$snarioName\" + "AsgTrace.etl"
    $pathAsgTraceLogTxt = "$pathLogsFolder\$snarioName\" + "AsgTraceLog.txt"
    
    if(Test-path -Path $tracelogExe)
    {
         Write-Log -Message "Initiating StartTrace" -IsOutput

         # Initialize scenario trace log (keep same filename/path)
         New-Item -ItemType File -Force -Path $pathAsgTraceLogTxt | Out-Null
         "[INFO]  tracelog : $tracelogExe" | Out-File -FilePath $pathAsgTraceLogTxt

         function Invoke-Tracelog {
            param([Parameter(Mandatory=$true)][string[]]$Args)
            $out = & $tracelogExe @Args 2>&1
            $out | Out-File -Append -FilePath $pathAsgTraceLogTxt
            return @{ ExitCode = $LASTEXITCODE; Output = ($out -join "`r`n") }
         }


         # Start trace session
         $startRes = Invoke-Tracelog -Args @('-start','AsgTrace','-f',$pathAsgTraceETL)
         $startFailed = ($startRes.ExitCode -ne 0) -or ($startRes.Output -match 'Could not start logger') -or ($startRes.Output -match 'Operation Status:\s*183L')
         if ($startFailed) {
            # Retry once after an explicit stop.
            Invoke-Tracelog -Args @('-stop','AsgTrace') | Out-Null
            Start-Sleep -Milliseconds 500
            $startRes = Invoke-Tracelog -Args @('-start','AsgTrace','-f',$pathAsgTraceETL)
            $startFailed = ($startRes.ExitCode -ne 0) -or ($startRes.Output -match 'Could not start logger') -or ($startRes.Output -match 'Operation Status:\s*183L')
         }

         if ($startFailed) {
            throw "Failed to start ETW session 'AsgTrace'. See $pathAsgTraceLogTxt for details. (This often happens if a previous AsgTrace session is still running or if not elevated.)"
         }

         Start-Sleep -m 500
         Invoke-Tracelog -Args @('-systemrundown','AsgTrace') | Out-Null
         Start-Sleep -m 500
         Invoke-Tracelog -Args @('-enableex','AsgTrace','-guid','#AB71FE82-3742-446b-982A-1FEDBB7D9594','-level','0xff') | Out-Null
         Invoke-Tracelog -Args @('-enableex','AsgTrace','-guid','#45AA7AE8-974C-5BBD-D7B5-8EA567DAC172','-level','0xff') | Out-Null
         Invoke-Tracelog -Args @('-enableex','AsgTrace','-guid','#641CBF19-268C-44B8-9618-16EA1158E54D','-level','0xff') | Out-Null
         Invoke-Tracelog -Args @('-enableex','AsgTrace','-guid','#21f0190b-6273-5306-5451-77ba8481d945','-level','0xff') | Out-Null
         Invoke-Tracelog -Args @('-enableex','AsgTrace','-guid','#afe60d91-90d2-59bd-ebbf-d321f5691437','-level','0xff') | Out-Null

         Write-Log -Message "Asg Traces started" -IsOutput
    }
    else
    {
        Write-Error "File does not exist $tracelogExe" 
    }
} 

<#
DESCRIPTION:
    This function stops the active trace session for a specified scenario and processes the collected trace logs.
    It converts the trace logs into a readable text format and stores them in the scenario-specific log folder.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for which tracing is stopped. This name is used to locate the correct log files.
RETURN TYPE:
    - void (Stops the trace session and processes the logs without returning a value.)
#>
function StopTrace($snarioName)
{   
    $pathlogger = Get-MepSdkToolPath -EnvVar "TRACELOG_EXE" -CommandName "tracelog"
    $pathtracefmt = Get-MepSdkToolPath -EnvVar "TRACEFMT_EXE" -CommandName "tracefmt"

    #Setting Scenario specific folders
    $pathAsgTraceETL = "$pathLogsFolder\$snarioName\" + "AsgTrace.etl"
    $pathAsgTraceLogTxt = "$pathLogsFolder\$snarioName\" + "AsgTraceLog.txt"
    $pathAsgTraceFmtTxt = "$pathLogsFolder\$snarioName\" + "AsgTraceFmt.txt"

    function Wait-FileReadable {
        param(
            [Parameter(Mandatory = $true)][string]$Path,
            [int]$TimeoutSeconds = 60
        )

        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $lastLength = -1
        $stableCount = 0

        while ((Get-Date) -lt $deadline) {
            if (-not (Test-Path -LiteralPath $Path)) {
                Start-Sleep -Milliseconds 250
                continue
            }

            try {
                $fi = Get-Item -LiteralPath $Path -ErrorAction Stop

                # Many systems keep writing/flushing ETL briefly after tracelog -stop.
                # Treat the ETL as "ready" when it is non-empty AND its length has been stable for ~2 seconds.
                if ($fi.Length -gt 0 -and $fi.Length -eq $lastLength) {
                    $stableCount++
                } else {
                    $stableCount = 0
                }
                $lastLength = $fi.Length

                $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                $stream.Close()

                if ($stableCount -ge 8) {
                    return $true
                }
            } catch {
                # File exists but isn't readable yet (still being flushed/locked)
            }

            Start-Sleep -Milliseconds 250
        }

        return $false
    }
    
    if(Test-path -Path $pathlogger)
    {
        Write-Log -Message "Initiating StopTrace" -IsOutput

        if (-not (Test-Path -LiteralPath $pathAsgTraceLogTxt)) {
            New-Item -ItemType File -Force -Path $pathAsgTraceLogTxt | Out-Null
        }
        "[INFO]  tracelog : $pathlogger" | Out-File -Append -FilePath $pathAsgTraceLogTxt
        if ($pathtracefmt) {
            "[INFO]  tracefmt : $pathtracefmt" | Out-File -Append -FilePath $pathAsgTraceLogTxt
        }

        & $pathlogger -stop AsgTrace 2>&1 | Out-File -Append -FilePath $pathAsgTraceLogTxt
        Start-Sleep -Seconds 2
        # Do not bail out if ETL is still flushing; rely on tracefmt retries (Collect-AsgTrace behavior).

        # Best-effort: wait a bit for the ETL to be readable to reduce tracefmt flakiness.
        try { [void](Wait-FileReadable -Path $pathAsgTraceETL -TimeoutSeconds 30) } catch { }

        $env:TRACE_FORMAT_PREFIX = "[%9!d!]%8!04X!.%3!04X!::%4!s! [%1!s!] [%2!s!]"
        #Write-Host "TRACE_FORMAT_PREFIX set."

        if (-not $pathtracefmt -or -not (Test-Path -LiteralPath $pathtracefmt)) {
            Write-Host "WARN: tracefmt.exe not found. Run LoggerBinaries\Setup-WinSdk.ps1 to set TRACEFMT_EXE." -ForegroundColor Yellow
        } else {
            $formatted = $false
            $deadline = (Get-Date).AddSeconds(60)
            $attempt = 0

            try {
                $outDir = Split-Path -Parent $pathAsgTraceFmtTxt
                if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
            } catch { }

            while ((Get-Date) -lt $deadline) {
                $attempt++
                & $pathtracefmt $pathAsgTraceETL -preferJson -jsonMeta 0 -o $pathAsgTraceFmtTxt 2>&1 |
                    Out-File -Append -FilePath $pathAsgTraceLogTxt

                $exit = $LASTEXITCODE
                $fmtExists = $false
                $fmtLen = 0
                try {
                    if (Test-Path -LiteralPath $pathAsgTraceFmtTxt) {
                        $fmtExists = $true
                        $fmtLen = (Get-Item -LiteralPath $pathAsgTraceFmtTxt).Length
                    }
                } catch { $fmtExists = $false; $fmtLen = 0 }

                if ($exit -eq 0 -and $fmtExists -and $fmtLen -gt 0) {
                    $formatted = $true
                    break
                }

                # If tracefmt claims success but didn't create the output, retrying usually won't help.
                if ($exit -eq 0 -and -not $fmtExists) {
                    Write-Host ("WARN: tracefmt returned exit=0 but did not create AsgTraceFmt.txt (path='{0}')." -f $pathAsgTraceFmtTxt) -ForegroundColor Yellow
                    break
                }

                Write-Host ("WARN: tracefmt attempt {0} failed (exit={1}, exists={2}, len={3}); retrying..." -f $attempt, $exit, $fmtExists, $fmtLen) -ForegroundColor Yellow
                Start-Sleep -Milliseconds ([Math]::Min(5000, 250 * $attempt))
            }

            if (-not $formatted) {
                Write-Host "WARN: tracefmt could not open/format ETL within timeout; continuing without formatted output." -ForegroundColor Yellow
                Write-Log -Message "WARN: tracefmt could not open/format ETL within timeout; continuing without AsgTraceFmt.txt." -IsOutput
            }
        }
        Write-Log -Message "Asg Traces Stopped" -IsOutput
    }
    else
    {
        Write-Error "Windows SDK tooling missing. Ensure TRACELOG_EXE is set (run LoggerBinaries\Setup-WinSdk.ps1)." 
    }
}

