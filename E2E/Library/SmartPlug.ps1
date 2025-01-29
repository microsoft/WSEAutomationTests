function list_devices($token) {
    $deviceListBody = "{'method':'getDeviceList'}"

    $response = Invoke-RestMethod "https://wap.tplinkcloud.com?token=$token" -Method POST -Body $deviceListBody -ContentType application/json

    $deviceList = $response.Result.deviceList
    echo $deviceList

    foreach ($device in $deviceList) {
        echo $device.deviceId
    }
}
function get_relay_state($token, $deviceId) {
    $sysinfoBody = "{
        'method':'passthrough',
        'params':{
            'deviceId':'$deviceId',
            'requestData':'{\`"system\`":{\`"get_sysinfo\`":null}}'
        }
    }"

    $response = Invoke-RestMethod "https://wap.tplinkcloud.com?token=$token" -Method POST -Body $sysinfoBody -ContentType application/json

    #echo $response.error_code
    $data = $response.result.responseData | ConvertFrom-Json
    $system = ConvertTo-Json $data.system
    $temp = $system | ConvertFrom-Json
    $sysinfo = $temp.get_sysinfo
    return $sysinfo.relay_state
}
function set_relay_state($token, $deviceId, $relayState) {
    $setRelayStateBody = "{
                'method':'passthrough',
                'params':{
                    'deviceId':'$deviceId',
                    'requestData':'{\`"system\`":{\`"set_relay_state\`":{\`"state\`":$relayState}}}'
                }
            }"

    $response = Invoke-RestMethod "https://use1-wap.tplinkcloud.com?token=$token" -Method POST -Body $setRelayStateBody -ContentType application/json
}
function SetSmartPlugState($token, $smartplugId, $smartplugState)
{
    if($token.Length -eq 0 -and $SPId.Length -eq 0 -and $smartplugState -eq 1)
    {
       Write-output "Assumption:Smartplug is in neutral state when test starts which is pluggedin" 
       return
    }
    if($token.Length -eq 0 -and $SPId.Length -eq 0 -and $smartplugState -eq 0)
    {
       Write-Error "Something went wrong: Not expected Scenario for SmartPlugState" - Stop
    } 

    $smartPlugCurrentState = get_relay_state $token $smartplugId
    if($smartPlugCurrentState -ne $smartPlugState)
    {
       set_relay_state $token $smartplugId $smartPlugState
       Start-Sleep -Seconds 3
       $smartPlugCurrentState = get_relay_state $token $smartplugId
       if($smartPlugCurrentState -ne $smartPlugState)
       {
          Write-Error "Error:Smart-plug is still $smartPlugCurrentState" - Stop
       }
    }
    else
    {
       write-output "Smart plug is already $smartPlugCurrentState"
    }
}
function CheckDevicePowerState($devPowStat, $token, $SPId)
{ 
   if($devPowStat -eq "Unplugged")
   {  
      if($token.Length -ne 0 -and $SPId.Length -ne 0)
      {  
         SetSmartPlugState $token $SPId 0
      }
      else
      {   
         return $false
      }
   }
   elseif($devPowStat -eq "Pluggedin")
   {
      if($token.Length -ne 0 -and $SPId.Length -ne 0)
      {  
         SetSmartPlugState $token $SPId 1
      }
      else
      {
         write-output "SmartPlug details not available, however the device should be Plugged-In state"
      }
   }
   else
   {
      Write-Error " $devPowStat not valid input " -ErrorAction Stop  
   }
}

function Get-BatteryPercentage {
   $battery = Get-WmiObject -Query "Select * from Win32_Battery"
   return $battery.EstimatedChargeRemaining
}
