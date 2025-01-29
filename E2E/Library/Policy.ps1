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
function CheckWSEV2Policy
{
   $libSnpeHtpV73Skel = "C:\Windows\System32\DriverStore\FileRepository\microsofteffectpack_extension.inf*\libSnpeHtpV73Skel.so"
   if(!(Test-path -Path $libSnpeHtpV73Skel))
   {
      return $false
   }
   else
   {
      return $true  
   }
}