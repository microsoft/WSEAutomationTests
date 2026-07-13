# Logger Binaries

This folder contains the helper scripts used to collect and format Windows Studio Effects ETW traces.

## One-Time Setup

Run `Setup-WinSdk.ps1` from PowerShell to install or locate the Windows SDK tools used by the trace scripts:

```powershell
cd E2E\LoggerBinaries
.\Setup-WinSdk.ps1
```

The setup script creates these user environment variables:

- `TRACELOG_EXE`: full path to `tracelog.exe`
- `TRACEFMT_EXE`: full path to `tracefmt.exe`

It also adds the tool directory to the user `PATH`. Open a new terminal after setup if the current shell does not see the new environment variables.

## Manual Trace Collection

`collect.cmd` is intended for ad hoc manual trace collection. The E2E script tests use the same trace collection SDK, but this particular `.cmd` tool is for collecting traces manually outside the automated test flow.

Run `collect.cmd` from an elevated Command Prompt or elevated PowerShell session:

```cmd
cd E2E\LoggerBinaries
collect.cmd
```

`collect.cmd` reads `TRACELOG_EXE` and `TRACEFMT_EXE` from the user environment variables created by `Setup-WinSdk.ps1`. It starts the `AsgTrace` ETW session, waits for you to press a key, stops tracing, and formats the ETL with `tracefmt`.

The script produces these output files in this folder:

- `AsgTrace.etl`: raw ETW trace
- `AsgTraceFmt.txt`: formatted trace text from `tracefmt`
- `AsgTraceLog.txt`: command output and diagnostic log

If `collect.cmd` reports that `TRACELOG_EXE` or `TRACEFMT_EXE` is missing, rerun `Setup-WinSdk.ps1` and then open a new terminal.
