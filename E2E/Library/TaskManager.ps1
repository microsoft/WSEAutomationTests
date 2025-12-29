param(
    [string]$scenario,
    [int]$duration = 3,
    [ValidateSet("Before","During")]
    [string]$executionState = "During",
    [string]$logPath,
    [switch]$Once
)
Add-Type -AssemblyName UIAutomationClient
<#
DESCRIPTION:
    Launches Task Manager using UI Automation and returns its UI element handle.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - [UIElement] The automation element for the Task Manager window.
#>
function Start-TaskManager {
    try {

        $uitaskmgr = OpenApp 'Taskmgr' 'Task Manager'
        return $uitaskmgr
    }
    catch {
        Write-Error "Failed to start Task Manager: $_"
        exit 1
    }
}
<#
DESCRIPTION:
    Navigates Task Manager to the Performance tab.
INPUT PARAMETERS:
    - taskmgr [UIElement] :- The UI automation element representing the Task Manager window.
RETURN TYPE:
    - void (Changes tab without returning a value.)
#>
function Switch-ToPerformanceTab {
    param($taskmgr)

    # Navigate to Performance tab
    FindAndClick -uiEle $taskmgr -clsNme "Microsoft.UI.Xaml.Controls.NavigationViewItem" -proptyNme "Performance"
}

<#
DESCRIPTION:
    Retrieves the current CPU usage percentage from Task Manager.
INPUT PARAMETERS:
    - uitaskmgr [UIElement] :- The UI automation element representing the Task Manager window.
RETURN TYPE:
    - [int] The CPU usage percentage, or throws error if not found.
#>
function Get-CPUUsage {
    param($uitaskmgr)
    
    $cpu = FindClickableElementByAutomationID -uiEle $uitaskmgr -autoID "sidebar_cpu_util"
    $cpuUsage = $cpu.GetCurrentPropertyValue([Windows.Automation.AutomationElement]::NameProperty)
    if ($cpuUsage) {
        if ($cpuUsage -match "(\d+)%") { return [int]$matches[1] }
    } else {
        Write-Error "No CPU utilization captured"
    }
}

<#
DESCRIPTION:
    Retrieves the current memory usage percentage and capacity details.
INPUT PARAMETERS:
    - uitaskmgr [UIElement] :- The UI automation element representing the Task Manager window.
RETURN TYPE:
    - [Hashtable] Object with keys:
        Percent [int]   – Current memory usage in percent
        UsedGB  [double] – Memory in GB currently used
        TotalGB [double] – Total system memory in GB
#>
function Get-MemoryUsage {
    param($uitaskmgr)

    $memory = FindClickableElementByAutomationID -uiEle $uitaskmgr -autoID "sidebar_mem_util"
    $memoryUsage = $memory.GetCurrentPropertyValue([Windows.Automation.AutomationElement]::NameProperty)
    if ($memoryUsage) {
        if ($memoryUsage -match "(\d+)%") {
            $percent = [int]$matches[1]
            if ($memoryUsage -match "(\d+(\.\d+)?)/(\d+(\.\d+)?)") {
                return @{
                    Percent = $percent
                    UsedGB  = [double]$matches[1]
                    TotalGB = [double]$matches[3]
                }
            }
            return @{ Percent = $percent; UsedGB=$null; TotalGB=$null }
        } else {
            Write-Error "No memory utilization captured" -ErrorAction stop
        }
    }
}
<#
DESCRIPTION:
    Retrieves the current NPU utilization from Task Manager.
INPUT PARAMETERS:
    - uitaskmgr [UIElement] :- The UI automation element representing the Task Manager window.
RETURN TYPE:
    - [int] The NPU usage percentage, or throws error if not found.
#>
function Get-NPUUsage {
    param($uitaskmgr)

    $npu = FindClickableElementByAutomationID -uiEle $uitaskmgr -autoID "sidebar_gpu_util"
    $npuUsage = $npu.GetCurrentPropertyValue([Windows.Automation.AutomationElement]::NameProperty)
    if ($npuUsage -match "(\d+)%") { return [int]$matches[1] }
    else {
        Write-Error "No Npu utilization captured" -ErrorAction Stop
    }
}

<#
DESCRIPTION:
    Monitors CPU, Memory, and NPU usage during a scenario, logs results to file,
    and produces a summary report depending on execution state ("Before" or "During").
INPUT PARAMETERS:
    - scenario [string]    :- Scenario name for logging context
    - duration [int]       :- Number of iterations (unless -Once is used)
    - executionState [string] :- Whether to log usage "Before" or "During" execution
    - logPath [string]     :- Path to log file
    - Once [switch]        :- Capture only once instead of looping
RETURN TYPE:
    - void (Writes log file and optionally returns summary output.)
#>
function Monitor-Resources {
    param($scenario, $duration, $executionState, $logPath, $Once)

    Write-Output "Entering Monitor-Resources function"
    $pathLogsFolder = Resolve-Path $pathLogsFolder
    $logDir = Split-Path $logPath -Parent
    $logFolder = "$pathLogsFolder\$logDir"
    if (-not (Test-Path $logFolder)) 
    {
       CreateScenarioLogsFolder $logDir
    }

    $logPath = "$pathLogsFolder\$logPath"
    if (-not (Test-Path $logPath)) {
        New-Item -ItemType File -Path $logPath | Out-Null
    }
    $logPath = Resolve-Path -path $logPath 

    $taskmgr = Start-TaskManager
    Switch-ToPerformanceTab $taskmgr

    $logEntries = @()
    $iterations = if ($Once) { 1 } else { $duration }

    for ($i=0; $i -lt $iterations; $i++) {
        Start-Sleep -Seconds 5
        $cpu = Get-CPUUsage $taskmgr
        $mem = Get-MemoryUsage $taskmgr
        $npu = Get-NPUUsage $taskmgr
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $entry = [PSCustomObject]@{
            Timestamp     = $timestamp
            Scenario      = $scenario
            State         = $executionState
            CPUInPercent  = $cpu
            MemInPercent  = $mem.Percent
            NPUInPercent  = $npu
            UsedMemInGB   = $mem.UsedGB
            TotalMemGB    = $mem.TotalGB
        }
        $logEntries += $entry
        $line = "$($entry.Timestamp), State=$($entry.State), CPUInPercent=$($entry.CPUInPercent), NPUInPercent=$($entry.NPUInPercent), UsedMemInGB=$($entry.UsedMemInGB)/$($entry.TotalMemGB)"
        Add-Content -Path $logPath -Value $line

        if (-not $Once) { Start-Sleep -Seconds 1 }
    }
    
# ---- Stats only for "Before" ----
    if ($executionState -eq "Before" -and $logEntries.Count -gt 0)
    {
       $Results.'BeforeMemoryUsage(In GB)'= "$($entry.UsedMemInGB)/$($entry.TotalMemGB)"
       $Results.'BeforeNPUUsage(In %)'= "$($entry.NPUInPercent)"
       $Results.'BeforeCPUUsage(In %)'= "$($entry.CPUInPercent)"

       CloseApp 'Taskmgr'
    }
# ---- Stats only for "During" ----
    if ($executionState -eq "During" -and $logEntries.Count -gt 0)
    {
        stopTaskManager -uitaskmgr $taskmgr -Scenario $scenario

        $cpuStats = $logEntries.CPUInPercent | Measure-Object -Minimum -Maximum -Average
        $memPercentStats = $logEntries.MemInPercent | Measure-Object -Minimum -Maximum -Average
        $memUsedStats = $logEntries.UsedMemInGB | Measure-Object -Minimum -Maximum -Average
        $npuStats = $logEntries.NPUInPercent | Measure-Object -Minimum -Maximum -Average

        # Assume TotalMemGB stays constant across all samples (take first entry)
        $totalMemGB = $logEntries[0].TotalMemGB

        $summary = @"
======== Summary ($Scenario - $executionState) ========
CPUInPercent: Min=$($cpuStats.Minimum)  Max=$($cpuStats.Maximum)  Avg=$([math]::Round($cpuStats.Average,2))
MemInGB: Min=$([math]::Round($memUsedStats.Minimum,2))/$totalMemGB   
     Max=$([math]::Round($memUsedStats.Maximum,2))/$totalMemGB  
     Avg=$([math]::Round($memUsedStats.Average,2))/$totalMemGB 
NPUInPercent: Min=$($npuStats.Minimum)  Max=$($npuStats.Maximum) Avg=$([math]::Round($npuStats.Average,2))
=======================================================
"@

        Add-Content -Path $logPath -Value $summary
        Write-Output $summary
        $Results.'AvgMemoryUsage(In GB)'= "$([math]::Round($memUsedStats.Average,2))/$totalMemGB"
        $Results.'AvgNPUUsage(In %)'= "$([math]::Round($npuStats.Average,2))"
        $Results.'AvgCPUUsage(In %)'= "$([math]::Round($cpuStats.Average,2))"
    
    }
    
    Write-Output "Captured $executionState data. Log: $logPath"
}


<#
DESCRIPTION:
    This function captures CPU and NPU Usage and Stops Task Manager.
INPUT PARAMETERS:
    - uitaskmgr [UIElement] :- The UI automation element representing the Task Manager window.
    - Scenario [string] :- The name of the scenario to be included in the screenshot filenames.
RETURN TYPE:
    - void (Captures resource usage screenshots and closes Task Manager without returning a value.)
#>
function stopTaskManager($uitaskmgr,$Scenario){
   Write-Log -Message "Entering stopTaskManager function" -IsOutput
   
   #capture Screenshot for CPU Usage
   captureCPUUsage -uitaskmgr $uitaskmgr -Scenario $Scenario
  
   #capture Screenshot for CPU Usage
   captureNPUUsage -uitaskmgr $uitaskmgr -Scenario $Scenario

   #Close Taskmanager App
   CloseApp 'Taskmgr'
}

<#
DESCRIPTION:
    This function sets Task Manager Real time Update speed to Low.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - void (Adjusts Task Manager settings without returning a value.)
#>
function setTMUpdateSpeedLow  
{   
    Write-Log -Message "Entering setTMUpdateSpeedLow function" -IsOutput

    $uitaskmgr = OpenApp 'Taskmgr' 'Task Manager'
    Start-Sleep -s 1

    #Click setting on Task Manager
    FindAndClick -uiEle $uitaskmgr -autoID "SettingsItem"

    #Set Real time Update speed to Low"
    FindAndClick -uiEle $uitaskmgr -clsNme ComboBox -proptyNme "General, Real time update speed, Choose how often to update the system resource usage report"
    FindAndClick -uiEle $uitaskmgr -clsNme ComboBoxItem -proptyNme "Low"

    #Close Taskmanager App
    CloseApp 'Taskmgr'
}

<#
DESCRIPTION:
    This function navigates to CPU and takes a screenshot.
INPUT PARAMETERS:
    - uitaskmgr [UIElement] :- The UI automation element representing the Task Manager window.
    - Scenario [string] :- The name of the scenario to be included in the screenshot filename.
RETURN TYPE:
    - void (Captures a screenshot of CPU performance without returning a value.)
#>
function captureCPUUsage($uitaskmgr, $Scenario) 
{
   Write-Log -Message "Entering captureCPUUsage function" -IsOutput
 
   # Navigate to CPU tab
   Write-Log -Message "Navigating to CPU tab" -IsOutput 
   Start-Sleep -s 1
   FindAndClick -uiEle $uitaskmgr -autoID "sidebar_cpu_util"
   Start-Sleep -s 1
   
   # Capture Screenshot for CPU Usage
   Take-Screenshot -FileName "CPU_Performance" -ScnrName $Scenario
   start-sleep -Seconds 1
}

<#
DESCRIPTION:
    This function navigates to NPU and takes a screenshot.
INPUT PARAMETERS:
    - uitaskmgr [UIElement] :- The UI automation element representing the Task Manager window.
    - Scenario [string] :- The name of the scenario to be included in the screenshot filename.
RETURN TYPE:
    - void (Captures a screenshot of NPU performance without returning a value.)
#>
function captureNPUUsage($uitaskmgr, $Scenario) 
{ 

   # Navigate to NPU tab
   Write-Log -Message "Navigating to NPU tab" -IsOutput
   FindAndClick -uiEle $uitaskmgr -proptyNme "NPU 0"
   start-sleep -s 3
   
   # Capture Screenshot for NPU Usage
   Write-Log -Message "Entering Take-Screenshot function to capture NPU usage" -IsOutput
   Take-Screenshot -FileName "NPU_Performance" -ScnrName $Scenario 
   start-sleep -Seconds 1

}

