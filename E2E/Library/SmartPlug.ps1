<#
DESCRIPTION:
    This function retrieves and lists all devices associated with the given TP-Link cloud account token.
    It fetches the device list via a REST API call and outputs each device's ID.

INPUT PARAMETERS:
    - token [string] :- The authentication token for accessing the TP-Link cloud API.

RETURN TYPE:
    - void (Outputs the list of devices and their IDs to the console.)
#>
function list_devices($token) {
    $deviceListBody = "{'method':'getDeviceList'}"

    $response = Invoke-RestMethod "https://wap.tplinkcloud.com?token=$token" -Method POST -Body $deviceListBody -ContentType application/json

    $deviceList = $response.Result.deviceList
    echo $deviceList

    foreach ($device in $deviceList) {
        echo $device.deviceId
    }
}

<#
DESCRIPTION:
    This function retrieves the relay (power) state of a specified smart device.
    It queries the device's system information via a REST API call.

INPUT PARAMETERS:
    - token [string] :- The authentication token for accessing the TP-Link cloud API.
    - deviceId [string] :- The unique identifier of the device for which the relay state is being retrieved.

RETURN TYPE:
    - [int] (Returns the relay state of the device: 1 for ON, 0 for OFF.)
#>
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

<#
DESCRIPTION:
    This function sets the relay (power) state of a specified smart device.
    It sends a REST API request to turn the device ON or OFF based on the provided state.

INPUT PARAMETERS:
    - token [string] :- The authentication token for accessing the TP-Link cloud API.
    - deviceId [string] :- The unique identifier of the device for which the relay state is being set.
    - relayState [int] :- The desired relay state (1 for ON, 0 for OFF).

RETURN TYPE:
    - void (Sends the API request to set the relay state without returning a value.)
#>
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

<#
DESCRIPTION:
    This function ensures that a smart plug is in the desired state (plugged in or unplugged).
    It compares the current state with the desired state and adjusts it if necessary.

INPUT PARAMETERS:
    - token [string] :- The authentication token for accessing the TP-Link cloud API.
    - smartplugId [string] :- The unique identifier of the smart plug.
    - smartplugState [int] :- The desired state of the smart plug (1 for Plugged in, 0 for Unplugged).

RETURN TYPE:
    - void (Ensures the smart plug is in the desired state without returning a value.)
#>
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

<#
DESCRIPTION:
    This function checks and sets the power state of a device based on the specified condition (Plugged in or Unplugged).
    It interacts with the smart plug to control the power supply.

INPUT PARAMETERS:
    - devPowStat [string] :- The desired power state ("Pluggedin" or "Unplugged").
    - token [string] :- The authentication token for accessing the TP-Link cloud API.
    - SPId [string] :- The unique identifier of the smart plug controlling the device.

RETURN TYPE:
    - [bool] (Returns false if the device should be unplugged but smart plug details are unavailable, otherwise performs actions without returning a value.)
#>
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

<#
DESCRIPTION:
    This function retrieves the current battery percentage of the device.

INPUT PARAMETERS:
    - None

RETURN TYPE:
    - [int] (Returns the current battery percentage of the device.)
#>
function Get-BatteryPercentage {
   $battery = Get-WmiObject -Query "Select * from Win32_Battery"
   return $battery.EstimatedChargeRemaining
}
