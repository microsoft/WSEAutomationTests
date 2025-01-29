function StartTrace($snarioName)
{   
    #path to logger binaries
    $pathlogger = ".\LoggerBinaries\tracelog.exe"
    $patheprint = ".\LoggerBinaries\eprint.exe"
    if (!(Test-path -path "$pathLogsFolder\$snarioName" ))
    {
        CreateScenarioLogsFolder $snarioName
    }

    #Setting Scenario specific folders
    $pathAsgTraceETL = "$pathLogsFolder\$snarioName\" + "AsgTrace.etl"
    $pathAsgTraceLogTxt = "$pathLogsFolder\$snarioName\" + "AsgTraceLog.txt"
    $pathAsgTraceTxt = "$pathLogsFolder\$snarioName\" + "AsgTrace.txt"
    
    if(Test-path -Path $pathlogger)
    {
	     write-output "Initiating StartTrace"
         & $pathlogger -start AsgTrace -f $pathAsgTraceETL > $pathAsgTraceLogTxt
         Start-Sleep -m 500
         & $pathlogger -systemrundown AsgTrace >> $pathAsgTraceLogTxt
         Start-Sleep -m 500
         & $pathlogger -enableex AsgTrace -guid `#AB71FE82-3742-446b-982A-1FEDBB7D9594 -level 0xff  >> $pathAsgTraceLogTxt
         write-output "Asg Traces started"
    }
    else
    {
        Write-Error "File does not exist $pathlogger" 
    }
} 

function StopTrace($snarioName)
{   
    #path to logger binaries
    $pathlogger = ".\LoggerBinaries\tracelog.exe"
    $patheprint = ".\LoggerBinaries\eprint.exe"

    #Setting Scenario specific folders
    $pathAsgTraceETL = "$pathLogsFolder\$snarioName\" + "AsgTrace.etl"
    $pathAsgTraceLogTxt = "$pathLogsFolder\$snarioName\" + "AsgTraceLog.txt"
    $pathAsgTraceTxt = "$pathLogsFolder\$snarioName\" + "AsgTrace.txt"
    
    if((Test-path -Path $patheprint) -and (Test-path -Path $pathlogger))
    {
        Write-Output "Initiating StopTrace"
        & $pathlogger -stop AsgTrace >> $pathAsgTraceLogTxt
        Start-Sleep -m 500
        & $patheprint $pathAsgTraceETL /o $pathAsgTraceTxt /oftext /time >> $pathAsgTraceLogTxt
        Start-Sleep -Seconds 2 #Wait for 2 secs so that Asgtrace.txt is generated properly before verifyLogs function starts
        Write-Output "Asg Traces Stopped"
    }
    else
    {
        Write-Error "File does not exist $patheprint or $pathlogger" 
    }
}

