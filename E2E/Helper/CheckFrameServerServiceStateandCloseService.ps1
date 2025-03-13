<#
DESCRIPTION:
    This function checks the status of a specified service and waits until it stops. 
    If the service remains running after 41 seconds, it forcibly stops the service 
    and ensures related applications are closed.
INPUT PARAMETERS:
    - svcName [string] :- The display name of the service to check and stop if necessary.
RETURN TYPE:
    - void
#>
function CheckServiceState($svcName){
   $service = Get-Service -DisplayName $svcName 
   $serviceState =$service.Status
   while ($serviceState -eq "Running")
   {  
      Start-Sleep -Seconds 41
      $service = Get-Service -DisplayName $svcName
      $serviceState =$service.Status
      if($serviceState -eq "Running")
      {
        Write-Log -Message "$svcName didn't stop after 41 secs, killing the service" -IsHost -ForegroundColor yellow
        #Close the App if it's open.
        CloseApp 'systemsettings'
        CloseApp 'WindowsCamera'
        Start-Sleep -Seconds 1
        Stop-Service -DisplayName $svcName
      }
   }
   Write-Log -Message "$svcName service stopped" -IsOutput
}
