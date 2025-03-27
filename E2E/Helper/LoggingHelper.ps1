<#
DESCRIPTION:
    This function logs a message to both the console and the output stream. 
    It provides flexibility to choose where the message should be displayed 
    by using switch parameters for Write-Host and Write-Output.

INPUT PARAMETERS:
    - Message [string] :- The message to be logged. This is the main content that will be displayed.
    - IsHost [switch] :- If provided, the message will be displayed in the console using Write-Host.
    - IsOutput [switch] :- If provided, the message will be sent to the output stream using Write-Output.

RETURN TYPE:
    - void (Outputs the message to the specified destinations without returning a value.)
#>
function Write-Log {
    param (
        [string]$Message,
        [switch]$IsHost,
        [switch]$IsOutput,
        [ConsoleColor]$ForegroundColor = "White" # Default to White
    )

    if ($IsHost) {
        Write-Host $Message -ForegroundColor $ForegroundColor
    }

    if ($IsOutput) {
        Write-Output $Message
    }
}
