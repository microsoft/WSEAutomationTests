function Error-Exception($snarioName, $strttme, $rslts, $logFile, $token, $SPID)
{  
   Take-Screenshot "Error-Exception" $snarioName
   Write-Output "Error occured and enter catch statement"
   CloseApp 'systemsettings'
   CloseApp 'WindowsCamera'
   CloseApp 'Taskmgr'
   StopTrace $snarioName
   CheckServiceState 'Windows Camera Frame Server'
   Write-Output $_
   TestOutputMessage $snarioName "Exception" $strttme $_.Exception.Message
   Write-Output $_ >> $pathLogsFolder\ConsoleResults.txt
   Reporting $rslts "$pathLogsFolder\Report.txt"
   $getLogs = Get-Content -Path "$pathLogsFolder\$logFile" -Raw
   write-host $getLogs
   $logs = resolve-path "$pathLogsFolder\$logFile"
   Write-Host "(Logs saved here:$logs)"
   SetSmartPlugState $token $SPID 1
}