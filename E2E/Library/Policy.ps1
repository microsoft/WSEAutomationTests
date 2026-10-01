<#
DESCRIPTION:
    This function checks whether the Voice Focus policy is supported on the system.
    It verifies the existence of the 'mep_audio_component.inf' file in the DriverStore
    directory, which indicates the presence of the required audio component for Voice Focus.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - [bool] (Returns $true if the Voice Focus policy is supported, otherwise returns $false.)
#>
function CheckVoiceFocusPolicy
{
   $audioComponent = "C:\Windows\System32\DriverStore\FileRepository\mep_audio_component.inf*\mep_audio_component.inf"
   if(!(Test-path -Path $audioComponent))
   {
      return $false
   }
   else
   {
      return $true
   }
}

<#
DESCRIPTION:
   This function checks whether Windows Studio Effects V2 (WSEV2) is supported.
   Support is indicated by a V73 or V81 policy library, or a supported hardware ID.
INPUT PARAMETERS:
    - None
RETURN TYPE:
    - [bool] (Returns $true if WSEV2 policy is supported, otherwise returns $false.)
#>
function CheckWSEV2Policy
{
   return Test-WSEPolicySupport -LibraryNames @(
      "libSnpeHtpV73Skel"
      "libQnnHtpV81Skel"
   )
}

<#
DESCRIPTION:
   This function checks whether Windows Studio Effects V2/V3 features are supported.
   Support is indicated by the V81 policy library or a supported hardware ID.
INPUT PARAMETERS:
   - None
RETURN TYPE:
   - [bool] (Returns $true if WSEV2/V3 features are supported, otherwise returns $false.)
#>
function CheckWSEV2V3Policy
{
   return Test-WSEPolicySupport -LibraryNames "libQnnHtpV81Skel"
}

function Test-WSEPolicySupport
{
   param(
      [Parameter(Mandatory)]
      [string[]]$LibraryNames
   )

   $driverStorePath = "C:\Windows\System32\DriverStore\FileRepository\microsofteffectpack_extension.inf*"
   foreach($libraryName in $LibraryNames)
   {
      if(Test-Path -Path "$driverStorePath\$libraryName.so")
      {
         return $true
      }
   }

   return Test-WSEHardwareSupport
}

function Test-WSEHardwareSupport {
    $hardwareIds = @(
        'SWC\MEP_VEN_8086_DEV_D71D',
        'SWC\MEP_VEN_1022_DEV_17F1'
    )

    $device = Get-PnpDevice -PresentOnly | Where-Object {
        $_.Status -eq 'OK' -and
        ($_.HardwareId | Where-Object { $_ -in $hardwareIds })
    }

    return [bool]$device
}