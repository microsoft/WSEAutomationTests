<#
DESCRIPTION:
    Builds a configuration array based on a set of input effects.

INPUT PARAMETERS:
    - effects [string] : A '+'-separated list of effect names (e.g., "AF+PL+BBP").

RETURN TYPE:
    - [string[]] : A 14-element array with feature settings.
                  Includes combined scenario name and ID at the end.

NOTES:
    - Uses default values and overrides based on the given effects.
    - Scenario ID and some values depend on WSEV2 policy state.
#>
function Get-CombinationReturnValues {
    param (
        [string] $effects
    )

    # Define the base array (default values)
    $defaultReturnArray = @("Off","False","False","Off","Off","False","False","Off","False","False","Off","False","False","False","","")
    $wsev2PolicyState = CheckWSEV2Policy
    $WSE8480Policy = Check8480Policy

    # Define overrides with support check
    $overrides = @{
        'AFS'  = @{ supported = $true;                        data = @{ 0 = 'On';  1 = 'True'; 14  = 'AFS';    15 = 65536 } }
        'AFC'  = @{ supported = $WSE8480Policy;               data = @{ 0 = 'On';  2 = 'True';  14 = 'AFC';    15 = 65536 } }
        'ECS'  = @{ supported = $true;                        data = @{ 7 = 'On';  8 = 'True';  14 = 'ECS';    15 = 16 } }
        'ECT'  = @{ supported = $wsev2PolicyState;            data = @{ 7 = 'On';  9 = 'True';  14 = 'ECT';    15 = 131072 } }
        'PL'   = @{ supported = $wsev2PolicyState;            data = @{ 3 = 'On';               14 = 'PL';     15 = 524288 } }
        'CF-I' = @{ supported = $wsev2PolicyState;            data = @{ 10 = 'On'; 11 = 'True'; 14 = 'CF-I';   15 = 2097152 } }
        'CF-A' = @{ supported = $wsev2PolicyState;            data = @{ 10 = 'On'; 12 = 'True'; 14 = 'CF-A';   15 = 2097152 } }
        'CF-W' = @{ supported = $wsev2PolicyState;            data = @{ 10 = 'On'; 13 = 'True'; 14 = 'CF-W';   15 = 2097152 } }
        'BBP'  = @{ supported = $true;                        data = @{ 4 = 'On';  6 = 'True';  14 = 'BBP';    15 = if ($wsev2PolicyState) { 16384 } else { 16416 } } }
        'BBS'  = @{ supported = $true;                        data = @{ 4 = 'On';  5 = 'True';  14 = 'BBS';    15 = if ($wsev2PolicyState) { 64 } else { 96 } } }
    }

    $result = $defaultReturnArray.Clone()
    $scenarioName = @()
    $scenarioID = 0

    $effectList = $effects -split "\+"

    foreach ($effect in $effectList) {
        if ($overrides.ContainsKey($effect)) {
            $check = $overrides[$effect]
            if (-not $check.supported) {
                Write-Host "Effect '$effect' is not supported on this device. Skipping test."
                return $null  # Or throw to fail 
            }

            $override = $check.data
            foreach ($key in $override.Keys) {
                if ($key -eq 14) {
                    $scenarioName += $override[$key]
                } elseif ($key -eq 15) {
                    $scenarioID += $override[$key]
                } else {
                    $result[$key] = $override[$key]
                }
            }
        }
    }

    $result[14] = ($scenarioName -join "+")
    $result[15] = "$scenarioID"

    return ,$result
}
<#
DESCRIPTION:
    This function retrieves the corresponding value(s) for a given input key from a predefined 
    set of mappings. These mappings include configurations for camera resolutions, 
    and other settings.
INPUT PARAMETERS:
    - inputValue [string] :- The key for which the corresponding value needs to be retrieved. 
      This can be a video resolution (e.g., '1080p'), or a photo resolution (e.g., '12.2MP').

RETURN TYPE:
    - [Object] (Returns a string or array of strings corresponding to the input key. If the key 
      does not exist, it returns $null.)
#>
function RetrieveValue($inputValue)
{
 
   $returnValues = @{}
   $key = '1440p' 
   $value = ("1440p, 16 by 9 aspect ratio, 30 fps")
   $returnValues.Add($key, $value)
   $returnValues.Add('1080p' , "1080p, 16 by 9 aspect ratio, 30 fps")
   $returnValues.Add('720p' , "720p, 16 by 9 aspect ratio, 30 fps")
   $returnValues.Add('480p' , "480p, 4 by 3 aspect ratio, 30 fps")
   $returnValues.Add('360p' , "360p, 16 by 9 aspect ratio, 30 fps")
   $returnValues.Add('1440p1' , "1440p, 4 by 3 aspect ratio, 30 fps")
   $returnValues.Add('1080p1' , "1080p, 4 by 3 aspect ratio, 30 fps")
   $returnValues.Add('960p' , "960p, 4 by 3 aspect ratio, 30 fps")
   $returnValues.Add('640p' , "640p, 1 by 1 aspect ratio, 30 fps")
   $returnValues.Add('540p' , "540p, 16 by 9 aspect ratio, 30 fps")
   $returnValues.Add('8.3MP' , "8.3 megapixels, 16 by 9 aspect ratio,  3840 by 2160 resolution")
   $returnValues.Add('12.2MP' , "12.2 megapixels, 4 by 3 aspect ratio,  4032 by 3024 resolution")
   $returnValues.Add('5.0MP' , "5.0 megapixels, 4 by 3 aspect ratio,  2592 by 1944 resolution")
   $returnValues.Add('4.5MP' , "4.5 megapixels, 3 by 2 aspect ratio,  2592 by 1728 resolution")
   $returnValues.Add('3.8MP' , "3.8 megapixels, 16 by 9 aspect ratio,  2592 by 1458 resolution")
   $returnValues.Add('2.1MP' ,  "2.1 megapixels, 16 by 9 aspect ratio,  1920 by 1080 resolution")
   $returnValues.Add('1.6MP' , "1.6 megapixels, 4 by 3 aspect ratio,  1440 by 1080 resolution")
   $returnValues.Add('0.9MP' , "0.9 megapixels, 16 by 9 aspect ratio,  1280 by 720 resolution")
   $returnValues.Add('0.8MP' , "0.8 megapixels, 4 by 3 aspect ratio,  1024 by 768 resolution")
   $returnValues.Add('0.3MP' , "0.3 megapixels, 4 by 3 aspect ratio,  640 by 480 resolution")
   $returnValues.Add('0.2MP' , "0.2 megapixels, 16 by 9 aspect ratio,  640 by 360 resolution")
   $returnValues.Add('1.2MP' , "1.2 megapixels, 4 by 3 aspect ratio,  1280 by 960 resolution")
   $returnValues.Add('0.08MP' , "0.08 megapixels, 4 by 3 aspect ratio,  320 by 240 resolution")
   $returnValues.Add('0.02MP' , "0.02 megapixels, 4 by 3 aspect ratio,  160 by 120 resolution")
   $returnValues.Add('0.1MP' , "0.1 megapixels, 11 by 9 aspect ratio,  352 by 288 resolution")
   $returnValues.Add('0.03MP' , "0.03 megapixels, 11 by 9 aspect ratio,  176 by 144 resolution")
   $returnValues.Add("1440p, 16 by 9 aspect ratio, 30 fps" ,'1440p')
   $returnValues.Add("1080p, 16 by 9 aspect ratio, 30 fps" , '1080p')
   $returnValues.Add("720p, 16 by 9 aspect ratio, 30 fps" , '720p')
   $returnValues.Add("480p, 4 by 3 aspect ratio, 30 fps" , '480p')
   $returnValues.Add("360p, 16 by 9 aspect ratio, 30 fps" , '360p')
   $returnValues.Add("1440p, 4 by 3 aspect ratio, 30 fps" , '1440p1')
   $returnValues.Add("1080p, 4 by 3 aspect ratio, 30 fps" , '1080p1')
   $returnValues.Add("960p, 4 by 3 aspect ratio, 30 fps" , '960p')
   $returnValues.Add("640p, 1 by 1 aspect ratio, 30 fps" , '640p')
   $returnValues.Add("540p, 16 by 9 aspect ratio, 30 fps" , '540p')
   $returnValues.Add("8.3 megapixels, 16 by 9 aspect ratio,  3840 by 2160 resolution" , '8.3MP')
   $returnValues.Add("12.2 megapixels, 4 by 3 aspect ratio,  4032 by 3024 resolution" , '12.2MP')
   $returnValues.Add("5.0 megapixels, 4 by 3 aspect ratio,  2592 by 1944 resolution" , '5.0MP')
   $returnValues.Add("4.5 megapixels, 3 by 2 aspect ratio,  2592 by 1728 resolution" , '4.5MP')
   $returnValues.Add("3.8 megapixels, 16 by 9 aspect ratio,  2592 by 1458 resolution" , '3.8MP')
   $returnValues.Add("2.1 megapixels, 16 by 9 aspect ratio,  1920 by 1080 resolution" , '2.1MP')
   $returnValues.Add("1.6 megapixels, 4 by 3 aspect ratio,  1440 by 1080 resolution" , '1.6MP')
   $returnValues.Add("0.9 megapixels, 16 by 9 aspect ratio,  1280 by 720 resolution" , '0.9MP')
   $returnValues.Add("0.8 megapixels, 4 by 3 aspect ratio,  1024 by 768 resolution" , '0.8MP')
   $returnValues.Add("0.3 megapixels, 4 by 3 aspect ratio,  640 by 480 resolution" , '0.3MP')
   $returnValues.Add("0.2 megapixels, 16 by 9 aspect ratio,  640 by 360 resolution" , '0.2MP')
   $returnValues.Add("1.2 megapixels, 4 by 3 aspect ratio,  1280 by 960 resolution" , '1.2MP')
   $returnValues.Add("0.08 megapixels, 4 by 3 aspect ratio,  320 by 240 resolution" , '0.08MP')
   $returnValues.Add("0.02 megapixels, 4 by 3 aspect ratio,  160 by 120 resolution" , '0.02MP')
   $returnValues.Add("0.1 megapixels, 11 by 9 aspect ratio,  352 by 288 resolution" , '0.1MP')
   $returnValues.Add("0.03 megapixels, 11 by 9 aspect ratio,  176 by 144 resolution" ,'0.03MP')

   
   $outputValue = $returnValues[$inputValue]
   return $outputValue
}   
    