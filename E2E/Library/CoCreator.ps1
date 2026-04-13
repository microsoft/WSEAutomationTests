<#
DESCRIPTION:
    Automates opening Microsoft Paint, loading a specified file, enabling the Co-Creator feature, 
    and sending the text "dolphins in the ocean" to the text box. The function ensures any previous 
    instance of Paint is closed before launching a new one.

INPUT PARAMETERS:
    - $file [string] :- The file name (without path) to open in Paint.
    -scenario [string]:-  The name of the scenario for logging.

RETURN TYPE:
    - void : No return value.
#>
function Co-Creator
{   
    param($file, $scenario)
    $filePathDetails = ".\Helper\$file"
    $filePath = Resolve-path -Path $filePathDetails
    $titleNme = "dolphins - Paint"

    # Close the previous instance if any
    closeApp 'mspaint'
    Start-Process 'mspaint' -ArgumentList $filePath
    Sleep -s 1
 
    $settingsWindowId = ((Get-Process).where{$_.MainWindowTitle -eq $titleNme})[0].Id
    $root = [Windows.Automation.AutomationElement]::RootElement
    $condition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ProcessIdProperty, $settingsWindowId)
    $ui = $root.FindFirst([Windows.Automation.TreeScope]::Children, $condition)
    Start-Sleep -m 500
    FindAndClick -uiEle $ui -autoID "CopilotDropDownButton"
    Start-Sleep -m 500
    FindAndClick -uiEle $ui -autoID "CocreatorItem"
    Start-Sleep -s 2
    FindAndClick -uiEle $ui -autoID "prompt"
    Start-Sleep -s 2
    [System.Windows.Forms.SendKeys]::SendWait('dolphins in the ocean');
    Write-output "Text: dolphins in the ocean- sent to the TextBox."
    start-sleep -s 30
    Take-Screenshot -FileName "CoCreator-Image" -ScnrName $scenario
    Start-Sleep -s 2
    closeApp 'mspaint'
}

