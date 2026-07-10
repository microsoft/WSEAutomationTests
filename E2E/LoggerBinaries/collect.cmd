@echo off
setlocal DisableDelayedExpansion

rem test for elevated
net session 1>nul 2>nul || (echo collecting traces requires elevated rights... & exit /b 1)

call :LoadUserEnv TRACELOG_EXE
call :LoadUserEnv TRACEFMT_EXE

if not defined TRACELOG_EXE (
	echo TRACELOG_EXE is not set. Run Setup-WinSdk.ps1 and open a new command prompt.
	exit /b 1
)

if not exist "%TRACELOG_EXE%" (
	echo TRACELOG_EXE points to a missing file: "%TRACELOG_EXE%"
	exit /b 1
)

if not defined TRACEFMT_EXE (
	echo TRACEFMT_EXE is not set. Run Setup-WinSdk.ps1 and open a new command prompt.
	exit /b 1
)

if not exist "%TRACEFMT_EXE%" (
	echo TRACEFMT_EXE points to a missing file: "%TRACEFMT_EXE%"
	exit /b 1
)

echo tracelog: "%TRACELOG_EXE%" > AsgTraceLog.txt
echo tracefmt: "%TRACEFMT_EXE%" >> AsgTraceLog.txt

"%TRACELOG_EXE%" -start AsgTrace -f AsgTrace.etl >> AsgTraceLog.txt 2>&1
"%TRACELOG_EXE%" -systemrundown AsgTrace >> AsgTraceLog.txt 2>&1
"%TRACELOG_EXE%" -enableex AsgTrace -guid #AB71FE82-3742-446b-982A-1FEDBB7D9594 -level 0xff >> AsgTraceLog.txt 2>&1

echo Tracing started....
pause >> AsgTraceLog.txt

"%TRACELOG_EXE%" -stop AsgTrace >> AsgTraceLog.txt 2>&1

set "TRACE_FORMAT_PREFIX=[%%9!d!]%%8!04X!.%%3!04X!::%%4!s! [%%1!s!] [%%2!s!]"
"%TRACEFMT_EXE%" AsgTrace.etl -preferJson -jsonMeta 0 -o AsgTraceFmt.txt >> AsgTraceLog.txt 2>&1
REM type AsgTraceFmt.txt

echo Please share output files AsgTrace.etl, AsgTraceFmt.txt, and AsgTraceLog.txt
exit /b 0

:LoadUserEnv
for /f "tokens=2,*" %%A in ('reg query HKCU\Environment /v %~1 2^>nul ^| findstr /i /c:"%~1"') do set "%~1=%%B"
exit /b 0
