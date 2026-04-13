<#
DESCRIPTION:
    The `Open-Browser` function automates the process of searching for a set of terms on Wikipedia using either Google Chrome or Microsoft Edge. It performs the following operations:
    - Checks if Google Chrome or Microsoft Edge is installed on the system.
    - Opens a Wikipedia search page for each search term provided in the `$srchDetails` array.
    - Scrolls the search results page a specified number of times (`$Noofscrolls`).
    - Closes the browser once the scrolling is completed.

PARAMETERS:
    - $srchDetails [array]: An array of search terms to be used in the Wikipedia search.
    - $Noofscrolls [int]: The number of times to scroll down the Wikipedia search page.

RETURNS:
    void: This function does not return a value. It automates the process of opening the browser, searching, and scrolling.
#>
function Open-Browser($srchDetails, $Noofscrolls)
{
    #Define the paths to Chrome and Edge executables
    $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
    $edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    
    #Search terms
    foreach ($search in $srchDetails)
    { 
        # Manually encode the search term (replace spaces with %20)
        $SearchTerm = $search -replace ' ', '%20'
        
        # URL for Wikipedia search
        $url = "https://en.wikipedia.org/wiki/Special:Search?search=$SearchTerm" 
        start-sleep -s 2
        
        #Check if Chrome is installed
        if (Test-Path $chromePath) {
            # Check if Chrome is already running and terminate if necessary
            $chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
            if ($chromeProcesses) {
                Get-Process chrome | ForEach-Object { $_.CloseMainWindow() } | Out-Null
                Write-Log -Message "Existing Chrome processes terminated." -IsOutput
                Start-Sleep -s 4
            }
            
            # Launch Chrome with the search URL
            $chromeProcess = Start-Process $chromePath -ArgumentList "`"$url`"" -WindowStyle Maximized -PassThru
            Write-Log -Message"Chrome is launched." -IsOutput
        }
        # If Chrome is not found, check if Edge is installed
        elseif (Test-Path $edgePath) {
            # Check if Edge is already running and terminate if necessary
            $edgeProcesses = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
            if ($edgeProcesses) {
                Get-process msedge | ForEach-Object { $_.CloseMainWindow() } | Out-Null
                Write-Log -Message  "Existing Edge processes terminated." -IsOutput
            }
            
            # Launch Edge with the search URL
            $edgeProcess = Start-Process $edgePath -ArgumentList "`"$url`"" -WindowStyle Maximized -PassThru
            Write-Log -Message "Edge is launched." -IsOutput
        }
        else
        {
            Write-Error "Neither Chrome nor Edge is installed." -ErrorAction Stop 
        }
        
        # Wait for the browser to launch and load the search results page
        Start-Sleep -Seconds 5
        
        # Try to find the browser window
        $browserWindow = $null
        $retryAttempts = 0
        while ($browserWindow -eq $null -and $retryAttempts -lt 5) {
            $browserWindow = Get-Process | Where-Object { $_.MainWindowTitle -like "*Wikipedia*" }
            Start-Sleep -Seconds 2
            $retryAttempts++
        }
        
        if ($browserWindow)
        {
            # Load Windows Forms for keypress simulation
            [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
           
            $scrollAttempts = 0
           
            # Scroll down in a loop until a set number of scrolls
            [System.Windows.Forms.SendKeys]::SendWait("{Enter}")
            while ($scrollAttempts -lt $Noofscrolls) {
                [System.Windows.Forms.SendKeys]::SendWait("{DOWN}")  # Send Down Arrow key to scroll
                Start-Sleep -Seconds 10  # Delay between scrolls
                $scrollAttempts++
            }
        }
        else
        {
            Write-Error "Browser window with Wikipedia search results not found." -ErrorAction Stop 
        }
        if ($chromeProcesses)
        {
           Get-Process chrome | ForEach-Object { $_.CloseMainWindow() } | Out-Null
           Write-Log -Message "Existing Chrome processes terminated." -IsOutput
           Start-Sleep -s 2
        }
        $edgeProcesses = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
        if ($edgeProcesses)
        {
           Get-process msedge | ForEach-Object { $_.CloseMainWindow() } | Out-Null
           Write-Log -Message  "Existing Edge processes terminated." -IsOutput
           Start-Sleep -s 2
        } 

    }
}
