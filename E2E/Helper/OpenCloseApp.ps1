function OpenApp($cmd, $titleNme) 
{   
    $allRunningProcess = Get-Process
	if($allRunningProcess.Name -eq $cmd)
	{ 
		write-output "$cmd is already open"
	}
    else
    {
       Start-Process $cmd -WindowStyle Maximized
       Sleep -s 1
    } 
    $settingsWindowId = ((Get-Process).where{$_.MainWindowTitle -eq $titleNme})[0].Id
    $root = [Windows.Automation.AutomationElement]::RootElement
    $condition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ProcessIdProperty, $settingsWindowId)
    return $root.FindFirst([Windows.Automation.TreeScope]::Children, $condition)
}
function CloseApp ($appNme)
{ 
    $allRunningProcess = Get-Process
	if($allRunningProcess.Name -eq $appNme)
	{ 
		write-Output "$appNme is open. Closing $appNme app"
		Stop-Process -Name $appNme
		Sleep -s 1
	}
	else
	{
		Write-Output "$appNme is already closed"
	}
}
