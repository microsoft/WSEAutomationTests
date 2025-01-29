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
        Write-Host "$svcName didn't stop after 41 secs, killing the service" -ForegroundColor yellow
        #Close the App if it's open.
        CloseApp 'systemsettings'
        CloseApp 'WindowsCamera'
        Start-Sleep -Seconds 1
        Stop-Service -DisplayName $svcName
      }
   }Write-Output "$svcName service stopped"
}
