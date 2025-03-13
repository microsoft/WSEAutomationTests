Add-Type -AssemblyName UIAutomationClient

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
   captureCPUUsage -uiEle $uitaskmgr -Scenario $Scenario
  
   #capture Screenshot for CPU Usage
   captureNPUUsage -uiEle $uitaskmgr -Scenario $Scenario

   #Close Taskmanager App
   CloseApp 'Taskmgr'
}

<#
DESCRIPTION:
    This function sets Task Manager Real time Update speed to Low.
INPUT PARAMETERS:
    - uiEle [UIElement] :- The UI automation element representing the Task Manager window.
RETURN TYPE:
    - void (Adjusts Task Manager settings without returning a value.)
#>
function setTMUpdateSpeedLow($uiEle)  
{   
    Write-Log -Message "Entering setTMUpdateSpeedLow function" -IsOutput

    #Click setting on Task Manager
    FindAndClick -uiEle $uitaskmgr -autoID "SettingsItem"

    #Set Real time Update speed to Low"
    FindAndClick -uiEle $uitaskmgr -clsNme ComboBox -proptyNme "General, Real time update speed, Choose how often to update the system resource usage report"
    FindAndClick -uiEle $uitaskmgr -clsNme ComboBoxItem -proptyNme "Low"
}

<#
DESCRIPTION:
    This function navigate to CPU and take screenshot.
INPUT PARAMETERS:
    - uiEle [UIElement] :- The UI automation element representing the Task Manager window.
    - Scenario [string] :- The name of the scenario to be included in the screenshot filename.
RETURN TYPE:
    - void (Captures a screenshot of CPU performance without returning a value.)
#>
function captureCPUUsage($uiEle, $Scenario) 
{
   Write-Log -Message "Entering captureCPUUsage function" -IsOutput

   # Navigate to Performance tab
   FindAndClick -uiEle $uitaskmgr -clsNme "Microsoft.UI.Xaml.Controls.NavigationViewItem" -proptyNme "Performance"
 
   # Navigate to CPU tab
   Write-Log -Message "Navigating to CPU tab" -IsOutput 
   FindAndClick -uiEle $uitaskmgr -autoID "dashSidebarCpuButton"
   Start-Sleep -s 1
   
   #capture Screenshot for CPU Usage
   Take-Screenshot -FileName "CPU_Performance" -ScnrName $Scenario
   start-sleep -Seconds 1
}

<#
DESCRIPTION:
    This function navigate to NPU and take screenshot.
INPUT PARAMETERS:
    - uiEle [UIElement] :- The UI automation element representing the Task Manager window.
    - Scenario [string] :- The name of the scenario to be included in the screenshot filename.
RETURN TYPE:
    - void (Captures a screenshot of NPU performance without returning a value.)
#>
function captureNPUUsage($uiEle, $Scenario) 
{ 
   #Navigate to Performance tab
   FindAndClick -uiEle $uiEle -clsNme "Microsoft.UI.Xaml.Controls.NavigationViewItem" -proptyNme "Performance"

   #Navigate to NPU tab
   Write-Log -Message "Navigating to NPU tab" -IsOutput
   FindAndClick -uiEle $uiEle -proptyNme "NPU 0"
   
   # Capture Screenshot for NPU Usage
   Write-Log -Message "Entering Take-Screenshot function to capture NPU usage" -IsOutput
   Take-Screenshot -FileName "NPU_Performance" -ScnrName $Scenario 
   start-sleep -Seconds 1

}
