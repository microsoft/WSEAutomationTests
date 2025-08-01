# this is the common defintion used in the script
Set-Variable WSE_CAMERA_DRIVER_FRIENDLY_NAME		-Option ReadOnly -Value "Windows Studio Effects Camera"
# definition of the driver store path related to WSE
Set-Variable WINDOWS_DRIVER_FILE_REPOSITORY_PATH	-Option ReadOnly -Value "C:\Windows\System32\DriverStore\FileRepository\*"
# definition of the Dxdiag file name
Set-Variable OUTPUT_DXDIAG_FILE_NAME				-Option ReadOnly -Value "DxDiagOutput.txt"
# definition of the output file name
Set-Variable OUTPUT_TRAGET_FILE_NAME				-Option ReadOnly -Value "WseEnablingStatus.txt"

<#
.DESCRIPTION
	This function output message to console and target file.
#>
function outputMessage($message) {
	Write-Log -Message $message -IsHost
	Write-Log -Message $message -IsOutput >> "$pathLogsFolder\$OUTPUT_TRAGET_FILE_NAME"

}

<#
.DESCRIPTION
	This function output driver info with its friendly name and version.
#>
function outputDriverInfoByFriendlyName($driverInstance) {
	$driverFriendlyName = $driverInstance.FriendlyName
	$driverVersion = $driverInstance.driverVersion
	outputMessage "${driverFriendlyName}: ${driverVersion}"
}

<#
.DESCRIPTION
	This function retrieve the first WSE camera driver instance from device manager.
#>
function getWseCameraDriverInstance() {
	# Looking into Device Manager,
	# making sure the "Windows Studio Effects Camera" is listed under "Software Components";
	# This means the extension .inf for MEP camera was deployed.

	$wseCameraDeviceNamingList = "Windows Camera Effects", "Windows Studio Camera Effects"

	return Get-CimInstance -Class win32_PnpSignedDriver |
		   Where-Object {($_.DeviceClass -eq "SoftwareComponent") -and ($wseCameraDeviceNamingList -contains $_.DeviceName)} |
		   Select-Object -First 1
}

<#
.DESCRIPTION
	This function retrieve the first WSE audio driver instance from device manager.
#>
function getWseAudioDriverInstance() {

	$wseAudioDeviceNamingList = "MSVoiceClarity APO", "MSAudioBlur APO"

	return Get-CimInstance -Class win32_PnpSignedDriver |
		   Where-Object {($_.DeviceClass -eq "AUDIOPROCESSINGOBJECT") -and ($wseAudioDeviceNamingList -contains $_.DeviceName)} |
		   Select-Object -First 1
}


<#
.DESCRIPTION
    This function is designed to parse DxDiag information and collect MEP Opt-in data for Internal or External USB Camera.
.PARAMETER CameraType
    Specify "Internal Camera" or "External Camera" to indicate which camera info to parse. Default is Internal Camera.
#>
function parseOptInCameraInfoFromDxDiagInfo([ValidateSet("Internal Camera","External Camera")][string]$CameraType = "Internal Camera")
{
    $parseResults = [PSCustomObject]@{
        optinCameraFriendlyName       = "n/a"
        optinCameraDriverVersion      = "n/a"
        optinCameraHardwareID         = "n/a"
        mepCameraOptedIn              = "n/a"
        mepDriverVersion              = "n/a"
        optinCameraMepHighResMode     = "n/a"
        externalUsbCameras            = @()
    }

    $outputDxDiagFilePath = "$pathLogsFolder\$OUTPUT_DXDIAG_FILE_NAME"

    $dxdiagProcess = Start-Process "dxdiag.exe" -ArgumentList "/t $outputDxDiagFilePath" -Wait -PassThru

    if ($dxdiagProcess.ExitCode -ne 0) {
        Write-Log -Message "DxDiag process failed with exit code $($dxdiagProcess.ExitCode)" -IsHost -ForegroundColor Red
        return $parseResults
    }

    # Read the content of the generated output DxDiag file
    $dxdiagContent = Get-Content -Path $outputDxDiagFilePath

    # Extract information using Select-String and regex patterns
    $videoCaptureDeviceFriendlyNameArray = $dxdiagContent | Select-String -Pattern "^\s+FriendlyName: (.+)" | ForEach-Object { $_.Line -replace "^\s+FriendlyName: ", "" }
    $videoCaptureDeviceCategoryArray = $dxdiagContent | Select-String -Pattern "^\s+Category: (.+)" | ForEach-Object { $_.Line -replace "^\s+Category: ", "" }
    $videoCaptureDeviceDriverVersionArray = $dxdiagContent | Select-String -Pattern "^\s+DriverVersion: (.+)" | ForEach-Object { $_.Line -replace "^\s+DriverVersion: ", "" }
    $videoCaptureDeviceHardwareIDArray = $dxdiagContent | Select-String -Pattern "^\s+HardwareID: (.+)" | ForEach-Object { $_.Line -replace "^\s+HardwareID: ", "" }
    $videoCaptureDeviceMEPOptedInArray = $dxdiagContent | Select-String -Pattern "^\s+MEPOptedIn: (.+)" | ForEach-Object { $_.Line -replace "^\s+MEPOptedIn: ", "" }
    $videoCaptureDeviceMEPVersionArray = $dxdiagContent | Select-String -Pattern "^\s+MEPVersion: (.+)" | ForEach-Object { $_.Line -replace "^\s+MEPVersion: ", "" }
    $videoCaptureDeviceFMEPHighResModeArray = $dxdiagContent | Select-String -Pattern "^\s+MEPHighResMode: (.+)" | ForEach-Object { $_.Line -replace "^\s+MEPHighResMode: ", "" }
    $videoCaptureDeviceLocationArray = $dxdiagContent | Select-String -Pattern "^\s+Location: (.+)" | ForEach-Object { $_.Line -replace "^\s+Location: ", "" }

    if ($CameraType -eq "Internal Camera")
    {
        $optInCameraDeviceIndex = -1
        $nonOptInCameraDeviceIndex = -1

        # if there is only one object returned from the Select-String results, we can access the element directly
        if (1 -eq $videoCaptureDeviceFriendlyNameArray.Count) {
            # We are only focused on capture devices with the 'Category: Camera' property
            if ("Camera" -ieq $videoCaptureDeviceCategoryArray) {
                $parseResults.optinCameraFriendlyName   = $videoCaptureDeviceFriendlyNameArray
                $parseResults.optinCameraDriverVersion  = $videoCaptureDeviceDriverVersionArray
                $parseResults.optinCameraHardwareID     = $videoCaptureDeviceHardwareIDArray
                $parseResults.mepCameraOptedIn          = $videoCaptureDeviceMEPOptedInArray
                $parseResults.mepDriverVersion           = $videoCaptureDeviceMEPVersionArray
                $parseResults.optinCameraMepHighResMode = $videoCaptureDeviceFMEPHighResModeArray
            }
            return $parseResults
        }

        for ($i = 0; $i -lt $videoCaptureDeviceFriendlyNameArray.Count; $i++) {
            # We are only focused on capture devices with the 'Category: Camera' property
            if ("Camera" -ieq $videoCaptureDeviceCategoryArray[$i]) {
                if ("True" -ieq $videoCaptureDeviceMEPOptedInArray[$i]) {
                    $optInCameraDeviceIndex = $i
                    break;
                } elseif ((-1 -eq $nonOptInCameraDeviceIndex) -and ("False" -ieq $videoCaptureDeviceMEPOptedInArray[$i])) {
                    $nonOptInCameraDeviceIndex = $i
                }
            }
        }

        if (-1 -ne $optInCameraDeviceIndex) {
            $parseResults.optinCameraFriendlyName   = $videoCaptureDeviceFriendlyNameArray[$optInCameraDeviceIndex]
            $parseResults.optinCameraDriverVersion  = $videoCaptureDeviceDriverVersionArray[$optInCameraDeviceIndex]
            $parseResults.optinCameraHardwareID     = $videoCaptureDeviceHardwareIDArray[$optInCameraDeviceIndex]
            $parseResults.mepCameraOptedIn          = $videoCaptureDeviceMEPOptedInArray[$optInCameraDeviceIndex]
            $parseResults.mepDriverVersion           = $videoCaptureDeviceMEPVersionArray[$optInCameraDeviceIndex]
            $parseResults.optinCameraMepHighResMode = $videoCaptureDeviceFMEPHighResModeArray[$optInCameraDeviceIndex]
        } elseif (-1 -ne $nonOptInCameraDeviceIndex) {
            $parseResults.mepCameraOptedIn = $videoCaptureDeviceMEPOptedInArray[$nonOptInCameraDeviceIndex]
        }

    }
    elseif ($CameraType -eq "External Camera")
    {
        # 🔍 Parse external USB cameras
        Write-Host "Parsing External USB Cameras..."
        $selectedIndex = -1

        for ($i = 0; $i -lt $videoCaptureDeviceFriendlyNameArray.Count; $i++) {
            if ($videoCaptureDeviceLocationArray[$i] -ieq 'n/a') {
                Write-Host "External USB Camera: $($videoCaptureDeviceFriendlyNameArray[$i])"
                Write-Host "Location: $($videoCaptureDeviceLocationArray[$i])"

                # Add to externalUsbCameras array
                $parseResults.externalUsbCameras += $videoCaptureDeviceFriendlyNameArray[$i]

                # Select the first external USB camera for opt-in checks
                if ($selectedIndex -eq -1) {
                    $selectedIndex = $i
                }
            }
        }

        # 🛡️ Safe property assignments with null checks
        if ($selectedIndex -ge 0) {
            if ($videoCaptureDeviceFriendlyNameArray) {
                $parseResults.optinCameraFriendlyName = $videoCaptureDeviceFriendlyNameArray[$selectedIndex]
            }
            if ($videoCaptureDeviceDriverVersionArray) {
                $parseResults.optinCameraDriverVersion = $videoCaptureDeviceDriverVersionArray[$selectedIndex]
            }
            if ($videoCaptureDeviceHardwareIDArray) {
                $parseResults.optinCameraHardwareID = $videoCaptureDeviceHardwareIDArray[$selectedIndex]
            }
		if ($videoCaptureDeviceMepDriverVersionArray) {
			$parseResults.mepDriverVersion = $videoCaptureDeviceMepDriverVersionArray[$selectedIndex]
		}
		if ($videoCaptureDeviceMepHighResModeArray) {
			$parseResults.optinCameraMepHighResMode = $videoCaptureDeviceMepHighResModeArray[$selectedIndex]
		}
	} else {
		Write-Warning "No external USB camera found. Skipping camera detail assignment."
	}

        # Priority 1: external (Location=n/a) + opted-in
        for ($i = 0; $i -lt $videoCaptureDeviceFriendlyNameArray.Count; $i++) {
            if ("Camera" -ieq $videoCaptureDeviceCategoryArray[$i] -and $videoCaptureDeviceLocationArray[$i] -ieq "n/a") {
                if ("True" -ieq $videoCaptureDeviceMEPOptedInArray[$i]) {
                    $selectedIndex = $i
                    break
                }
            }
        }

        # Priority 2: any external (Location=n/a)
        if ($selectedIndex -eq -1) {
            for ($i = 0; $i -lt $videoCaptureDeviceFriendlyNameArray.Count; $i++) {
                if ("Camera" -ieq $videoCaptureDeviceCategoryArray[$i] -and $videoCaptureDeviceLocationArray[$i] -ieq "n/a") {
                    $selectedIndex = $i
                    break
                }
            }
        }

        # Priority 3: any internal camera with MEPOptedIn = True
        if ($selectedIndex -eq -1) {
            for ($i = 0; $i -lt $videoCaptureDeviceFriendlyNameArray.Count; $i++) {
                if ("Camera" -ieq $videoCaptureDeviceCategoryArray[$i] -and "True" -ieq $videoCaptureDeviceMEPOptedInArray[$i]) {
                    $selectedIndex = $i
                    break
                }
            }
        }

        # Fill parseResults with selected camera info
        if ($selectedIndex -ne -1) {
            $parseResults.optinCameraFriendlyName   = $videoCaptureDeviceFriendlyNameArray[$selectedIndex]
            $parseResults.optinCameraDriverVersion  = $videoCaptureDeviceDriverVersionArray[$selectedIndex]
            $parseResults.optinCameraHardwareID     = $videoCaptureDeviceHardwareIDArray[$selectedIndex]
            $parseResults.mepDriverVersion           = $videoCaptureDeviceMEPVersionArray[$selectedIndex]
            $parseResults.optinCameraMepHighResMode = $videoCaptureDeviceFMEPHighResModeArray[$selectedIndex]
        }
    }

    return $parseResults
}

<#
.DESCRIPTION
	This function retrieve camera HW info by its friendly name from device manager.
	be aware that the device with the specified friendly name may not always exist,
	so it might return null objects.
#>
function getOptInCameraHwInfoByFriendlyName($optinCameraFriendlyName) {

	return Get-CimInstance -Class win32_PnpSignedDriver |
		   Where-Object {$_.DeviceClass -eq "CAMERA" -and
		   				($_.FriendlyName -eq $optinCameraFriendlyName -or $_.Description -eq $optinCameraFriendlyName)}
}

<#
.DESCRIPTION
	This function collect the PerceptionCore.dll version info. from driver store path.
#>
function getPerceptionCoreInfo() {

	# Lookup all the PerceptionCore.dll under DriverStore path
	$perceptionCoreInfo =
		Get-ChildItem -Path $WINDOWS_DRIVER_FILE_REPOSITORY_PATH -Recurse -ErrorAction SilentlyContinue |
		Where-Object {$_.Name -eq "PerceptionCore.dll"}

	return $perceptionCoreInfo
}

<#
.DESCRIPTION
	This function output system related information.
#>
function displaySystemInfo() {

	$systemName = $env:COMPUTERNAME
	$currentOSProductName = (Get-WmiObject -Query "SELECT Caption FROM Win32_OperatingSystem").Caption

	$cmdOutput = cmd /c ver
	# Use Select-String to extract the version number
	$osBuildNumber = ($cmdOutput | Select-String -Pattern "\d+\.\d+\.\d+\.\d+").Matches.Value

	outputMessage "System Name: $systemName"
	outputMessage "System OS Info: $currentOSProductName ($osBuildNumber)"
}


<#
.DESCRIPTION
    This is main function to output the Opt-In camera status.
    Input parameters:
    (optional) $targetMepCameraVer: The version of MEP camera that the user expected.
    (optional) $targetMepAudioVer: The version of MEP audio that the user expected.
    (optional) $targetPerceptionCoreVer: The version of PerceptionCore.dll that the user expected.

    Output return code:
    $true: MEP enablement is successful.
    $false: there was a failure in MEP enablement.
.PARAMETER CameraType
    Specify "Internal Camera" or "External Camera" to indicate which camera type is being checked.
#>
function WseEnablingStatus($targetMepCameraVer, $targetMepAudioVer, $targetPerceptionCoreVer, [ValidateSet("Internal Camera","External Camera")][string]$CameraType = "Internal Camera")
{
    Write-Host "CameraType is: $CameraType"
    # check device manager for NPU opt-in
    $wseCameraDriverInstance = getWseCameraDriverInstance
    if ($null -eq $wseCameraDriverInstance) {
        Write-Log -Message "can not find '$WSE_CAMERA_DRIVER_FRIENDLY_NAME' in device manager, extension .inf for MEP camera was not correctly deployed" -IsHost -ForegroundColor Red
        return $false
    }

    if ($CameraType -eq "Internal Camera")
    {
        # to generate a DxDiag report and extract the relevant MEP-camera information from the output
        $parseResults = parseOptInCameraInfoFromDxDiagInfo
        $mepCameraOptedIn = $parseResults.mepCameraOptedIn
        $optinCameraFriendlyName = $parseResults.optinCameraFriendlyName
        $optinCameraHardwareID = $parseResults.optinCameraHardwareID
        $optinCameraDriverVersion = $parseResults.optinCameraDriverVersion
        $mepDriverVersion = $parseResults.mepDriverVersion
        $optinCameraMepHighResMode = $parseResults.optinCameraMepHighResMode

        # check MEP camera opt-in
        if ($mepCameraOptedIn -ieq "n/a")
	{
            Write-Log -Message "can not find Opt-in camera instance" -IsHost -ForegroundColor Red
            return $false
        } elseif ($mepCameraOptedIn -ieq "False") {
            Write-Log -Message "camera opt-in was not set" -IsHost -ForegroundColor Red
            return $false
        }

        displaySystemInfo
        outputMessage "Opt-In Camera Status: $mepCameraOptedIn"

        if ($optinCameraFriendlyName) {
            outputMessage "Opt-In Camera FriendlyName: $optinCameraFriendlyName"
            $Global:validatedCameraFriendlyName = $optinCameraFriendlyName
        } else {
            Write-Log -Message "Opt-In Camera FriendlyName Info not found" -IsHost
        }

        if ($optinCameraHardwareID) {
            outputMessage "Opt-In Camera Hardware ID: $optinCameraHardwareID"
        } else {
            Write-Log -Message "Opt-In Camera Hardware Info not found" -IsHost
        }

        if ($optinCameraDriverVersion){
            outputMessage "Opt-In Camera Driver: $optInCameraDriverVersion"
        } else {
            Write-Log -Message "Opt-In Camera Driver Info not found" -IsHost
        }

        if ($optinCameraMepHighResMode){
            outputMessage "Opt-In Camera HighRes Mode: $optinCameraMepHighResMode"
        } else {
            Write-Log -Message "Opt-In Camera HighRes Info not found" -IsHost
        }

    }
    elseif ($CameraType -eq "External Camera")
    {
        # to generate a DxDiag report and extract the relevant MEP-camera information from the output
        $parseResults = parseOptInCameraInfoFromDxDiagInfo -CameraType "External Camera"
        $optinCameraFriendlyName = $parseResults.optinCameraFriendlyName
        $optinCameraHardwareID = $parseResults.optinCameraHardwareID
        $optinCameraDriverVersion = $parseResults.optinCameraDriverVersion
        $mepDriverVersion = $parseResults.mepDriverVersion
        $optinCameraMepHighResMode = $parseResults.optinCameraMepHighResMode

        displaySystemInfo

        if ($optinCameraFriendlyName) {
            outputMessage "Opt-In Camera FriendlyName: $optinCameraFriendlyName"
            $Global:validatedCameraFriendlyName = $optinCameraFriendlyName
        } else {
            Write-Log -Message "Opt-In Camera FriendlyName Info not found" -IsHost
        }

        if ($optinCameraHardwareID) {
            outputMessage "Opt-In Camera Hardware ID: $optinCameraHardwareID"
        } else {
            Write-Log -Message "Opt-In Camera Hardware Info not found" -IsHost
        }

        if ($optinCameraDriverVersion){
            outputMessage "Opt-In Camera Driver: $optInCameraDriverVersion"
        } else {
            Write-Log -Message "Opt-In Camera Driver Info not found" -IsHost
        }

        if ($optinCameraMepHighResMode){
            outputMessage "Opt-In Camera HighRes Mode: $optinCameraMepHighResMode"
        } else {
            Write-Log -Message "Opt-In Camera HighRes Info not found" -IsHost
        }

        $ui = OpenApp 'ms-settings:' 'Settings'
        Start-Sleep -Milliseconds 500
        FindCameraEffectsPage $ui
        Start-Sleep -Seconds 5

        # Check if the external camera is opted-in or not.
        $exists = CheckIfElementExists $ui Button Open
        if ($exists) {
            Write-Host "External camera not opted-in. Opting-in now."
            FindAndClick $ui Button "Open" -autoId "SystemSettings_Camera_InfoBarDiscoverWSEOptInAction_Button"
            Start-Sleep -Seconds 2
            FindAndClick $ui Button "Use Windows Studio Effects" -autoId "SystemSettings_Camera_AdvancedConfigItem_WSEOptIn_ToggleSwitch"
            Start-Sleep -Seconds 2
            FindAndClick $ui Button "Apply" -autoId "PrimaryButton"
            Start-Sleep -Seconds 20
            Write-Host "Successfully opted-in external camera. Continuing for MEP feature validation..."
            return
        } else {
            Write-Host "External camera already opted-in. Continuing for MEP feature validation..."
            return
        }
    }

    # output WSE camera driver info if exists
    if ($wseCameraDriverInstance) {
        outputDriverInfoByFriendlyName $wseCameraDriverInstance
        if ($targetMepCameraVer -and ($targetMepCameraVer -ne $wseCameraDriverInstance.driverVersion)) {
            Write-Log -Message "User input MEP-camera version: $targetMepCameraVer" -IsHost
            return $false
        }
    }

    # output WSE audio driver info if exists
    $wseAudioDriverInstance = getWseAudioDriverInstance
    if ($wseAudioDriverInstance) {
        outputDriverInfoByFriendlyName $wseAudioDriverInstance
        if ($targetMepAudioVer -and ($targetMepAudioVer -ne $wseAudioDriverInstance.driverVersion)) {
            Write-Log -Message "User input MEP-audio version: $targetMepAudioVer" -IsHost
            return $false
        }
    }

    # output PerceptionCore.dll version info if exists
    $perceptionCoreInfo = getPerceptionCoreInfo
    if ($perceptionCoreInfo) {
        # to verify whether the specified target perceptionCore version exists on the system.
        # if $targetPerceptionCoreVer was provided, set the value to false.
        $isPerceptionCoreVersionMatched = $true
        if ($targetPerceptionCoreVer) {
            $isPerceptionCoreVersionMatched = $false
        }

        foreach ($pcInfo in $perceptionCoreInfo) {
            $versionInfo = $pcInfo | Get-ItemProperty | Select-Object -ExpandProperty VersionInfo
            $pcProductVersion = $versionInfo.ProductVersion
            outputMessage "PerceptionCore.dll: $pcProductVersion [Path: $($pcInfo.FullName)]"
            if ($targetPerceptionCoreVer -and ($pcProductVersion -match $targetPerceptionCoreVer)) {
                $isPerceptionCoreVersionMatched = $true
            }
        }
        if (!($isPerceptionCoreVersionMatched)) {
            Write-Log -Message "User input PerceptionCore version: $targetPerceptionCoreVer" -IsHost
            return $false
        }
    } else {
        Write-Log -Message "PerceptionCore.dll not found" -IsHost
        return $false
    }

    # output Camera UWP version
    $camerAppVersion = Get-AppXPackage -Name "Microsoft.WindowsCamera"  | Select-Object -ExpandProperty Version
    if ($camerAppVersion) {
        outputMessage "CameraApp(UWP): $camerAppVersion"
    }

    return $true
}
