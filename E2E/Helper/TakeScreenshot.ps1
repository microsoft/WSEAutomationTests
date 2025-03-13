# Add necessary .NET assembly
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient

<#
DESCRIPTION:
    This function captures a full-screen screenshot, including all monitors in a multi-monitor setup,
    and saves it as a PNG file in the specified scenario folder.
INPUT PARAMETERS:
    - FileName [string] :- The name of the file to save the screenshot (without extension).
    - ScnrName [string] :- The name of the scenario, used to create a corresponding folder for storing screenshots.
RETURN TYPE:
    - void (Captures and saves a screenshot without returning a value.)
#>
function Take-Screenshot {
   param (
       [string]$FileName,
       [string]$ScnrName
   )
   # Define the screenshot directory
   $scenarioName ="$ScnrName\TaskManagerScreenshots"
   CreateScenarioLogsFolder  $scenarioName
   $ScreenshotDirectory = "$pathLogsFolder\$scenarioName"
   $ScreenshotDirectoryPath = Resolve-path $ScreenshotDirectory
   $FilePath = Join-Path -Path $ScreenshotDirectoryPath -ChildPath "$FileName.png"

   # Capture dimensions of all screens (for multi-monitor setup)
   $ScreenWidth = [System.Windows.Forms.SystemInformation]::VirtualScreen.Width
   $ScreenHeight = [System.Windows.Forms.SystemInformation]::VirtualScreen.Height
   $ScreenX = [System.Windows.Forms.SystemInformation]::VirtualScreen.X
   $ScreenY = [System.Windows.Forms.SystemInformation]::VirtualScreen.Y

   # Create a bitmap to store the screenshot
   $Bitmap = New-Object System.Drawing.Bitmap($ScreenWidth, $ScreenHeight)
   $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)

   # Copy the screen content to the bitmap
   $Graphics.CopyFromScreen($ScreenX, $ScreenY, 0, 0, [System.Drawing.Size]::new($ScreenWidth, $ScreenHeight))

   # Save the screenshot to the specified file
   $Bitmap.Save($FilePath, [System.Drawing.Imaging.ImageFormat]::Png)

   # Dispose of objects to free memory
   $Graphics.Dispose()
   $Bitmap.Dispose()

   # Notify user
   #Write-Host "Screenshot saved to $FilePath"
}

<#
DESCRIPTION:
    This function captures a screenshot of a specific window based on its title. 
    If the window is found, it brings the window to the foreground and captures the screenshot.
    The image is saved as a PNG file in the specified scenario folder.
INPUT PARAMETERS:
    - FileName [string] :- The name of the file to save the screenshot (without extension).
    - ScnrName [string] :- The name of the scenario, used to create a corresponding folder for storing screenshots.
    - windowTitleNme [string] :- The title of the window to capture. The function will search for this window and bring it to the foreground.
RETURN TYPE:
    - void (Captures and saves the window screenshot without returning a value.)
#>
function Take-ForegroundWindowShot
{
   param (
       [string]$FileName,
       [string]$ScnrName,
       [string]$windowTitleNme)

   #Define the file path to save the image
   $scenarioName ="$ScnrName\Screenshots"
   CreateScenarioLogsFolder  $scenarioName
   $ScreenshotDirectory = "$pathLogsFolder\$scenarioName"
   $ScreenshotDirectoryPath = Resolve-path $ScreenshotDirectory
   $filePath = Join-Path -Path $ScreenshotDirectoryPath -ChildPath "$FileName.png"
   
   if($windowTitleNme)
   {
       #Find the window by title name
       $root = [System.Windows.Automation.AutomationElement]::RootElement
       $condition = New-Object System.Windows.Automation.PropertyCondition `
        ([System.Windows.Automation.AutomationElement]::NameProperty, $windowTitleNme)

       $window = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)

       if ($window -ne $null)
       {
          #Bring the window to the foreground
          $window.SetFocus()  
       }
       else
       {  
          #Print Error message if window element is $null
          Write-Error "Error: Window with title '$windowTitleNme' not found."    
       }
   }
    #Simulate pressing Alt + Print Screen to capture screenshot
    [System.Windows.Forms.SendKeys]::SendWait("%{PRTSC}")
   
   #Save the screenshot from the clipboard to an image file
   $clipboard = [System.Windows.Forms.Clipboard]::GetImage()
   if($clipboard)
   {
       $clipboard.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)
       Write-Log -Message "Screenshot saved to $filePath" -IsOutput
   }
   else
   {
       Write-Error "Error: No image found in clipboard" 
   }
}
