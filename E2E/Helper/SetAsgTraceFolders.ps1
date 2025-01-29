function CreateScenarioLogsFolder ($snario)
{
    $scenarioLogsFolder = $pathLogsFolder + "\$snario"
    If (!(test-path $scenarioLogsFolder)) {
        New-Item -ItemType Directory -Force -Path $scenarioLogsFolder  | Out-Null
    }
}
