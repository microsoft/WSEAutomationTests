
<#
DESCRIPTION:
    This function checks whether the Voice Focus policy is supported on the system. 
    It verifies the existence of the 'mep_audio_component.inf' file in the DriverStore 
    directory, which indicates the presence of the required audio component for Voice Focus.

INPUT PARAMETERS:
    - None

RETURN TYPE:
    - [bool] (Returns $true if the Voice Focus policy is supported, otherwise returns $false.)
#>function CheckVoiceFocusPolicy
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
    This function checks whether Windows Studio Effects V2 (WSEV2) policy is enabled 
    on the system. It verifies the existence of the 'libSnpeHtpV73Skel.so' library 
    file in the DriverStore directory, which is required for WSEV2 features.

INPUT PARAMETERS:
    - None

RETURN TYPE:
    - [bool] (Returns $true if WSEV2 policy is supported, otherwise returns $false.)
#>
function CheckWSEV2Policy
{
   $libSnpeHtpV73Skel = "C:\Windows\System32\DriverStore\FileRepository\microsofteffectpack_extension.inf*\lib*.so"
   if(!(Test-path -Path $libSnpeHtpV73Skel))
   {
      return $false
   }
   else
   {
      return $true  
   }
}