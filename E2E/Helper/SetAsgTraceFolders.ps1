<#
DESCRIPTION:
    This function creates a directory for storing logs specific to a test scenario. 
    If the directory already exists, it does nothing; otherwise, it creates the necessary folder 
    structure within the global logs folder.

INPUT PARAMETERS:
    - snario [string] :- The name of the test scenario, which is used to create a corresponding log folder.

RETURN TYPE:
    - void (Creates a directory if it does not exist, without returning a value.)
#>
function CreateScenarioLogsFolder ($snario)
{
    $scenarioLogsFolder = $pathLogsFolder + "\$snario"
    If (!(test-path $scenarioLogsFolder)) {
        New-Item -ItemType Directory -Force -Path $scenarioLogsFolder  | Out-Null
    }
}
<#
DESCRIPTION:
    Copies log file content to a test-specific folder. It extracts relevant logs from the main log file
    starting from the most recent test instance and saves them in a dedicated test-specific log file.
INPUT PARAMETERS:
    - scenarioLogFldr [string] :- The name of the scenario-specific folder where logs should be copied.
RETURN TYPE:
    - void
#>
function GetContentOfLogFileAndCopyToTestSpecificLogFile($scenarioLogFldr)
{   
    #copy logs to test specific folder
    $logCopyFrom = "$pathLogsFolder\$logFile"
    $logCopyTo =  "$pathLogsFolder\$scenarioLogFldr\log.txt" 
    $search="Starting Test for "
    $linenumber = Get-Content $logCopyFrom | select-string $search | Select-Object -Last 1
    $lne = $linenumber.LineNumber - 1
    Get-Content -Path $logCopyFrom | Select -Skip $lne > $logCopyTo 
}