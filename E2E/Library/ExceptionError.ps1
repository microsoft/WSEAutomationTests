<#
DESCRIPTION:
    This function handles exceptions by capturing error details, closing applications, stopping traces, 
    and checking the status of the Windows Camera Frame Server. It also logs error messages and reports 
    results for debugging.
INPUT PARAMETERS:
    - snarioName [string] :- The name of the scenario for logging.
    - strttme [datetime] :- The start time of the test execution.
    - rslts [object] :- The results object containing test details.
    - logFile [string] :- The name of the log file to retrieve and display.
    - token [string] :- The authentication token for setting the smart plug state.
    - SPID [string] :- The ID of the smart plug for restoring the power state.
RETURN TYPE:
    - void (Performs exception handling, logging, and reporting without returning a value.)
#>
function Error-Exception($snarioName, $strttme, $rslts, $logFile, $token, $SPID)
{  
   Take-Screenshot "Error-Exception" $snarioName

   Write-Log -Message "Error occurred and entered catch statement" -IsOutput
   CloseApp 'systemsettings'
   CloseApp 'WindowsCamera'
   CloseApp 'Taskmgr'
   StopTrace $snarioName
   CheckServiceState 'Windows Camera Frame Server'

   Write-Log -Message $_ -IsOutput
   TestOutputMessage $snarioName "Exception" $strttme $_.Exception.Message

   Write-Log -Message $_ -IsOutput >> $pathLogsFolder\ConsoleResults.txt
   Reporting $rslts "$pathLogsFolder\Report.txt"
   $getLogs = Get-Content -Path "$pathLogsFolder\$logFile" -Raw
   Write-Log -Message $getLogs -IsHost

   $logs = resolve-path "$pathLogsFolder\$logFile"
   Write-Log -Message "(Logs saved here:$logs)" -IsHost

   SetSmartPlugState $token $SPID 1
}