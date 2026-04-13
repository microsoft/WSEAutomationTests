<#
DESCRIPTION:
    This function logs a message to both the console and the output stream. 
    It provides flexibility to choose where the message should be displayed 
    by using switch parameters for Write-Host and Write-Output.

INPUT PARAMETERS:
    - Message [string] :- The message to be logged. This is the main content that will be displayed.
    - IsHost [switch] :- If provided, the message will be displayed in the console using Write-Host.
    - IsOutput [switch] :- If provided, the message will be sent to the output stream using Write-Output.
    - ForegroundColor [ConsoleColor] :- The color of the text in the console. Default is "White".
    - BackgroundColor [ConsoleColor] :- The background color of the text in the console. Default is "Black".
    - NoNewline [switch] :- If provided, the message will be displayed without a newline at the end.

RETURN TYPE:
    - void (Outputs the message to the specified destinations without returning a value.)
#>
function Write-Log {
    param (
        [string]$Message,
        [switch]$IsHost,
        [switch]$IsOutput,
        [ConsoleColor]$ForegroundColor = "White", # Default to White
        [ConsoleColor]$BackgroundColor = "Black", # Default to Black
        [switch]$NoNewline
    )

    if ($IsHost) {
        if ($NoNewline) {
            Write-Host -NoNewline $Message -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
        } else {
            Write-Host $Message -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
        }
    }

    if ($IsOutput) {
        Write-Output $Message
    }
}
