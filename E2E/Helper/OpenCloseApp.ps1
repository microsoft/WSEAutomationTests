<#
DESCRIPTION:
    This function opens a specified application if it's not already running. 
    It maximizes the window and returns the UI Automation Element of the app's main window 
    for further UI automation tasks.
INPUT PARAMETERS:
    - cmd [string] :- The command or process name to start the application (e.g., 'ms-settings:', 'notepad').
    - titleNme [string] :- The title of the application's main window to locate the correct UI element.
RETURN TYPE:
    - [Windows.Automation.AutomationElement] (Returns the UI Automation Element of the application's main window.)
#>
function OpenApp($cmd, $titleNme) 
{   
    $allRunningProcess = Get-Process
	if($allRunningProcess.Name -eq $cmd)
	{ 
		Write-Log -Message "$cmd is already open" -IsOutput
	}
    else
    {
       Start-Process $cmd -WindowStyle Maximized
       Sleep -s 1
    } 
    $settingsWindowId = ((Get-Process).where{$_.MainWindowTitle -eq $titleNme})[0].Id
    $root = [Windows.Automation.AutomationElement]::RootElement
    $condition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ProcessIdProperty, $settingsWindowId)
    $appWindow = $root.FindFirst([Windows.Automation.TreeScope]::Children, $condition)

    # -WindowStyle Maximized above only takes effect when a brand new process is started.
    # If the app was already running (e.g. a single-instance UWP app like ms-settings:),
    # its window keeps whatever size it last had, which can be too small to reveal all
    # toggles/controls. Force-maximize the window every time via the WindowPattern so
    # UI Automation always has the full set of elements available regardless of prior state.
    if ($appWindow -ne $null)
    {
        try
        {
            $windowPattern = $appWindow.GetCurrentPattern([Windows.Automation.WindowPattern]::Pattern)
            if ($windowPattern.Current.WindowVisualState -ne [Windows.Automation.WindowVisualState]::Maximized)
            {
                $windowPattern.SetWindowVisualState([Windows.Automation.WindowVisualState]::Maximized)
                Start-Sleep -Milliseconds 500
            }
        }
        catch
        {
            Write-Log -Message "Unable to force-maximize $titleNme window: $($_.Exception.Message)" -IsOutput
        }
    }

    return $appWindow
}

<#
DESCRIPTION:
    This function closes a specified application if it's currently running. 
    If the application is already closed, it outputs a message indicating so.
INPUT PARAMETERS:
    - appNme [string] :- The name of the application process to be closed (e.g., 'notepad', 'ms-settings').
RETURN TYPE:
    - void (Closes the application if running, with no return value.)
#>
function CloseApp ($appNme)
{ 
    $allRunningProcess = Get-Process
	if($allRunningProcess.Name -eq $appNme)
	{ 
		Write-Log -Message "$appNme is open. Closing $appNme app" -IsOutput
		Stop-Process -Name $appNme
        Sleep -s 1
	}
	else
	{
		Write-Log -Message "$appNme is already closed" -IsOutput
	}
}