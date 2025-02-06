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
