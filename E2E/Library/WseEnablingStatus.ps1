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
	This function is designed to parse DxDiag information and collect MEP Opt-in data for internal or external USB cameras.
.PARAMETER CameraType
    Specify "Internal Camera" or "External Camera" to indicate which camera info to parse. Default is Internal Camera.
#>
function parseOptInCameraInfoFromDxDiagInfo([ValidateSet("Internal Camera","External Camera")][string]$CameraType = "Internal Camera")
{
	$parseResults = [PSCustomObject]@{
		optinCameraFriendlyName		= "n/a"
		optinCameraDriverVersion	= "n/a"
		optinCameraHardwareID		= "n/a"
		mepCameraOptedIn			= "n/a"
		mepDriverVersion			= "n/a"
		optinCameraMepHighResMode	= "n/a"
		externalUsbCameras			= [System.Collections.Generic.List[string]]::new()
	}

	$outputDxDiagFilePath = "$pathLogsFolder\$OUTPUT_DXDIAG_FILE_NAME"
	$dxdiagArguments = "/t `"$outputDxDiagFilePath`""

	try {
		$dxdiagProcess = Start-Process "dxdiag.exe" -ArgumentList $dxdiagArguments -Wait -PassThru -ErrorAction Stop

		if ($dxdiagProcess.ExitCode -ne 0) {
			Write-Log -Message "DxDiag process failed with exit code $($dxdiagProcess.ExitCode)" -IsHost -ForegroundColor Red
			return $parseResults
		}
		# Read the content of the generated output DxDiag file
		$dxdiagContent = Get-Content -Path $outputDxDiagFilePath -ErrorAction Stop
	} catch {
		Write-Log -Message "Failed to run or read DxDiag output: $_" -IsHost -ForegroundColor Red
		return $parseResults
	}

	$cameraDevices = [System.Collections.Generic.List[object]]::new()
	$currentDevice = $null
	$inVideoCaptureSection = $false

	foreach ($line in $dxdiagContent) {
		if (-not $inVideoCaptureSection) {
			if ($line -match '^\s*Video Capture Devices\s*$') {
				$inVideoCaptureSection = $true
			}
			continue
		}

		if (($null -ne $currentDevice) -and ($line -match '^\s*-{19}\s*$')) {
			$cameraDevices.Add($currentDevice)
			$currentDevice = $null
			break
		}

		if ($line -match '^\s*FriendlyName:\s*(.+?)\s*$') {
			if ($null -ne $currentDevice) {
				$cameraDevices.Add($currentDevice)
			}

			$currentDevice = [PSCustomObject]@{
				FriendlyName = $Matches[1]
				Category = "n/a"
				DriverVersion = "n/a"
				HardwareID = "n/a"
				MEPOptedIn = "n/a"
				MEPVersion = "n/a"
				MEPHighResMode = "n/a"
				Location = "n/a"
			}
			continue
		}

		if (($null -ne $currentDevice) -and ($line -match '^\s*(Category|DriverVersion|HardwareID|MEPOptedIn|MEPVersion|MEPHighResMode|Location):\s*(.+?)\s*$')) {
			switch ($Matches[1]) {
				"Category" { $currentDevice.Category = $Matches[2] }
				"DriverVersion" { $currentDevice.DriverVersion = $Matches[2] }
				"HardwareID" { $currentDevice.HardwareID = $Matches[2] }
				"MEPOptedIn" { $currentDevice.MEPOptedIn = $Matches[2] }
				"MEPVersion" { $currentDevice.MEPVersion = $Matches[2] }
				"MEPHighResMode" { $currentDevice.MEPHighResMode = $Matches[2] }
				"Location" { $currentDevice.Location = $Matches[2] }
			}
		}
	}

	if ($null -ne $currentDevice) {
		$cameraDevices.Add($currentDevice)
	}

	# Write-Log -Message "$($cameraDevices | Out-String)" -IsHost

	$selectedDevice = $null
	if ($CameraType -eq "Internal Camera") {
		$Global:validatedSoundCaptureDeviceFriendlyName = getSoundCaptureDeviceName -DxdiagContent $dxdiagContent
		$internalCameras = @($cameraDevices | Where-Object {
			$_.Category -ieq "Camera" -and $_.Location -ine "n/a"
		})
		if ($internalCameras.Count -eq 0) {
			# If the camera has a Location of Front or Rear, Windows is typically treating it as an integrated camera based on ACPI PLD information.
			# If no internal cameras are found, fallback to all cameras regardless of location
			$internalCameras = @($cameraDevices | Where-Object { $_.Category -ieq "Camera" })
		}

		# for internal cameras, we prioritize the selection based on MEPOptedIn status: "True" > "explicit" > "False"
		$selectedDevice = $internalCameras |
			Where-Object { $_.MEPOptedIn -ieq "True" } |
			Select-Object -First 1

		if ($null -eq $selectedDevice) {
			$selectedDevice = $internalCameras |
				Where-Object { ($_.MEPOptedIn -ieq "explicit") -and ($_.Location -ne "n/a") } |
				Select-Object -First 1
		} else {
			if ($selectedDevice.Location -eq "n/a") {
				Write-Log -Message "ACPI PLD information is not available so 'EyeContact' is not functioning correctly." -IsHost -ForegroundColor Yellow
			}
		}

		if ($null -eq $selectedDevice) {
			$selectedDevice = $internalCameras |
				Where-Object { ($_.MEPOptedIn -ieq "False") -and ($_.Location -ne "n/a") } |
				Select-Object -First 1
		}

		if (($null -eq $selectedDevice) -and ($internalCameras.Count -eq 1)) {
			$selectedDevice = $internalCameras[0]
		}
	} else {
		$externalUsbCameras = @($cameraDevices | Where-Object {
			$_.Category -ieq "Camera" -and $_.Location -ieq "n/a"
		})

		if (0 -eq $externalUsbCameras.Count) {
			Write-Error "$CameraType is not found / unavailable / not connected." -ErrorAction Stop
		}

		foreach ($device in $externalUsbCameras) {
			$parseResults.externalUsbCameras.Add([string]$device.FriendlyName)
		}

		$selectedDevice = $externalUsbCameras | Where-Object { $_.MEPOptedIn -ieq "explicit" } | Select-Object -First 1

		if ($null -eq $selectedDevice) {
			$selectedDevice = $externalUsbCameras | Select-Object -First 1
		}

	}

	if ($null -eq $selectedDevice) {
		Write-Log -Message "$CameraType unavailable." -IsHost -ForegroundColor Yellow
		return $parseResults
	}

	$parseResults.optinCameraFriendlyName = $selectedDevice.FriendlyName
	$parseResults.optinCameraDriverVersion = $selectedDevice.DriverVersion
	$parseResults.optinCameraHardwareID = $selectedDevice.HardwareID
	$parseResults.mepCameraOptedIn = $selectedDevice.MEPOptedIn
	$parseResults.mepDriverVersion = $selectedDevice.MEPVersion
	$parseResults.optinCameraMepHighResMode = $selectedDevice.MEPHighResMode

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
    Parses dxdiag output to extract and return the last normalized sound capture device name from the “Sound Capture Devices” section.
    Input parameters:
    (Mandatory) $DxdiagContent: The content of Dxdiag file.
#>

function getSoundCaptureDeviceName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]] $DxdiagContent
    )

    # Helper: find the 0-based start/end indices of a named section
    function GetSectionRange {
        param(
            [Parameter(Mandatory)][object[]] $Lines,
            [Parameter(Mandatory)][string]   $StartHeader,
            [Parameter(Mandatory)][string]   $NextHeader
        )

        $startLine = ($Lines | Select-String -SimpleMatch $StartHeader | Select-Object -First 1).LineNumber
        if (-not $startLine) { return $null }

        # Select-String LineNumber is 1-based; convert to 0-based.
        # Keep start index at the header line so the slice is stable/obvious.
        $startIndex = $startLine - 1

        $nextHeaderMatch = $Lines |
            Select-String -SimpleMatch $NextHeader |
            Where-Object { $_.LineNumber -gt $startLine } |
            Select-Object -First 1

        # End index should be the line just BEFORE the next header.
        $endIndex = if ($nextHeaderMatch) {
            ($nextHeaderMatch.LineNumber - 2)   # convert to 0-based and step back one line
        } else {
            ($Lines.Count - 1)
        }

        # Guard against weird ordering / truncated files
        if ($endIndex -lt $startIndex) { return $null }

        return [pscustomobject]@{ Start = $startIndex; End = $endIndex }
    }

    # Helper: extract Description: values from a section
    function GetDescriptionsFromSection {
        param([object[]] $SectionLines)

        foreach ($line in $SectionLines) {
            if ($line -match '^\s*Description:\s*(.+?)\s*$') {
                $Matches[1].Trim()
            }
        }
    }

    # Helper: normalize device names by stripping trailing "(...)" suffix
    function NormalizeDeviceName {
        param([string] $Name)
        ($Name -replace '\s*\(.*\)\s*$', '').Trim()
    }

    # 1) Locate the Sound Capture Devices section
    # (We assume the capture device(s) are listed b/t 'Sound Capture Devices' and 'Video Capture Devices')
    $range = GetSectionRange -Lines $DxdiagContent `
                             -StartHeader 'Sound Capture Devices' `
                             -NextHeader  'Video Capture Devices'

    if (-not $range) {
        Write-Log -Message "Failed to retrieve 'Sound Capture Devices' from DxDiag info" -IsHost -ForegroundColor Red
        return $null
    }

    # 2) Slice section lines
    $sectionLines = $DxdiagContent[$range.Start..$range.End]

    # 3) Extract + normalize all Description entries
    $descriptions = @(GetDescriptionsFromSection -SectionLines $sectionLines)
    $normalized   = @($descriptions | ForEach-Object { NormalizeDeviceName $_ })

    if ($normalized.Count -eq 0) {
        Write-Log -Message "No sound capture devices were found on this device" -IsHost -ForegroundColor Red
        return $null
    }

    # return the LAST device name
    return $normalized[-1].ToString()
}

<#
.DESCRIPTION
	Validates a driver instance against an optional expected driver version.
#>
function Test-DriverVersion($driverInstance, $targetVersion) {
	if ($targetVersion -and ($targetVersion -ne $driverInstance.driverVersion)) {
		return $false
	}

	return $true
}

<#
.DESCRIPTION
	Opens Windows Settings and opts an external camera into Windows Studio Effects when needed.
#>
function Enable-ExternalCamera {
	$ui = OpenApp 'ms-settings:' 'Settings'
	Start-Sleep -Milliseconds 500
	FindCameraEffectsPage $ui
	Start-Sleep -Seconds 5

	$optInAvailable = CheckIfElementExists $ui Button Open
	if (-not $optInAvailable) {
		 Write-Host "External camera already opted-in. Continuing for MEP feature validation..."
		return
	}

	Write-Host "External camera not opted-in. Opting-in now."
	FindAndClick $ui Button "Open" -autoId "SystemSettings_Camera_InfoBarDiscoverWSEOptInAction_Button"
	Start-Sleep -Seconds 2
	FindAndClick $ui Button "Use Windows Studio Effects" -autoId "SystemSettings_Camera_AdvancedConfigItem_WSEOptIn_ToggleSwitch"
	Start-Sleep -Seconds 2
	FindAndClick $ui Button "Apply" -autoId "PrimaryButton"
	Start-Sleep -Seconds 20
	Write-Host "Successfully opted-in external camera. Continuing for MEP feature validation..."
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

function WseEnablingStatus($targetMepCameraVer, $targetMepAudioVer, $targetPerceptionCoreVer, [ValidateSet("Internal Camera","External Camera")][string]$CameraType = "Internal Camera") {

	$isInternalCamera = $CameraType -eq "Internal Camera"

	# check device manager for NPU opt-in
	$wseCameraDriverInstance = getWseCameraDriverInstance
	if ($null -eq $wseCameraDriverInstance) {
		Write-Log -Message "can not find '$WSE_CAMERA_DRIVER_FRIENDLY_NAME' in device manager, extension .inf for MEP camera was not correctly deployed" -IsHost -ForegroundColor Red
		return $false
	}

	# Generate a DxDiag report and extract the relevant MEP-camera information.
	$parseResults = parseOptInCameraInfoFromDxDiagInfo -CameraType $CameraType

	if ($isInternalCamera) {
		# check MEP camera opt-in
		if ($parseResults.mepCameraOptedIn -ieq "n/a")
		{
			Write-Log -Message "can not find Opt-in $CameraType instance" -IsHost -ForegroundColor Red
			return $false
		} elseif ($parseResults.mepCameraOptedIn -ieq "False") {
			Write-Log -Message "$CameraType opt-in was not set" -IsHost -ForegroundColor Red
			return $false
		}
	} else {
		$externalCameraIsAvailable = $parseResults.externalUsbCameras.Count -gt 0
		if (-not $externalCameraIsAvailable) {
			Write-Log -Message "External camera is not available" -IsHost -ForegroundColor Red
			return $false
		}

		$externalCameraIsOptedIn = $parseResults.mepCameraOptedIn -ieq "explicit"
		# if the external camera is not opted in, enable it
		if ($externalCameraIsAvailable -and -not $externalCameraIsOptedIn) {
			Enable-ExternalCamera
		}
	}

	displaySystemInfo
	if ($isInternalCamera) {
		outputMessage "Opt-In Camera Status: $($parseResults.mepCameraOptedIn)"
	}

	$cameraInfo = @(
		@{ Label = "FriendlyName"; Value = $parseResults.optinCameraFriendlyName; MissingMessage = "Opt-In Camera FriendlyName Info not found" }
		@{ Label = "Hardware ID"; Value = $parseResults.optinCameraHardwareID; MissingMessage = "Opt-In Camera Hardware Info not found" }
		@{ Label = "Driver"; Value = $parseResults.optinCameraDriverVersion; MissingMessage = "Opt-In Camera Driver Info not found" }
		@{ Label = "HighRes Mode"; Value = $parseResults.optinCameraMepHighResMode; MissingMessage = "Opt-In Camera HighRes Info not found" }
	)

	foreach ($info in $cameraInfo) {
		if ($info.Value) {
			outputMessage "Opt-In Camera $($info.Label): $($info.Value)"
		} else {
			Write-Log -Message $info.MissingMessage -IsHost
		}
	}
	if ($parseResults.optinCameraFriendlyName) {
		$Global:validatedCameraFriendlyName = $parseResults.optinCameraFriendlyName
	}

	outputDriverInfoByFriendlyName $wseCameraDriverInstance
	if (-not (Test-DriverVersion $wseCameraDriverInstance $targetMepCameraVer)) {
		Write-Log -Message "User input MEP-camera version: $targetMepCameraVer" -IsHost
		return $false
	}

	# output WSE audio driver info if exists
	$wseAudioDriverInstance = getWseAudioDriverInstance
	if ($isInternalCamera -and $wseAudioDriverInstance) {
		outputDriverInfoByFriendlyName $wseAudioDriverInstance
		if (-not (Test-DriverVersion $wseAudioDriverInstance $targetMepAudioVer)) {
			Write-Log -Message "User input MEP-audio version: $targetMepAudioVer" -IsHost
			return $false
		}
		outputMessage "Sound Capture Device FriendlyName: $Global:validatedSoundCaptureDeviceFriendlyName"
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

<#
.SYNOPSIS
    Tries to read the friendly name from a specific registry view.

.PARAMETER RegistryView
    The registry view to use (Registry64 or Registry32).

.OUTPUTS
    Returns the friendly name string if found; otherwise empty string.
#>
function Get-FriendlyNameFromView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryView]$RegistryView
    )

    # Registry constants
    $MepAudioClassGuid = "{5989fce8-9cd0-467d-8a6a-5419e31529d4}"
    $MepAudioClassKeyPath = "SYSTEM\CurrentControlSet\Control\Class\$MepAudioClassGuid"
    $MepAudioEffectPackGuid = "{D38F837A-9439-4256-8D63-DD5885442FA2}"
    $MepAudioFriendlyNameValue = "{B725F130-47EF-101A-A5F1-02608C9EEBAC},10"

    try {
        # Open the base key with the specified view
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
            [Microsoft.Win32.RegistryHive]::LocalMachine,
            $RegistryView
        )

        if ($null -eq $baseKey) {
            return [string]::Empty
        }

        try {
            # Open the class key
            $classKey = $baseKey.OpenSubKey($MepAudioClassKeyPath, $false)

            if ($null -eq $classKey) {
                return [string]::Empty
            }

            try {
                # Iterate subkeys like "0000", "0001", etc. under the class key
                $subKeyNames = $classKey.GetSubKeyNames()

                foreach ($subName in $subKeyNames) {
                    $effectRegPath = "$subName\EffectPackRegistration\$MepAudioEffectPackGuid"

                    $effectRegKey = $classKey.OpenSubKey($effectRegPath, $false)

                    if ($null -eq $effectRegKey) {
                        continue
                    }

                    try {
                        # Get the friendly name value
                        $value = $effectRegKey.GetValue(
                            $MepAudioFriendlyNameValue,
                            $null,
                            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
                        )

                        if (($null -ne $value) -and ($value -is [string]) -and (-not [string]::IsNullOrWhiteSpace($value))) {
                            return $value
                        }
                    }
                    finally {
                        $effectRegKey.Close()
                    }
                }
            }
            finally {
                $classKey.Close()
            }
        }
        finally {
            $baseKey.Close()
        }
    }
    catch [UnauthorizedAccessException] {
        # HKLM read should normally be allowed; if not, return empty gracefully
        Write-Verbose "UnauthorizedAccessException when accessing registry view $RegistryView"
        return [string]::Empty
    }
    catch {
        # Swallow non-fatal exceptions and continue
        Write-Verbose "Exception when accessing registry view $RegistryView : $_"
        return [string]::Empty
    }

    return [string]::Empty
}

<#
.SYNOPSIS
    Attempts to read the WSE Audio Effect Pack friendly name from the registry.

.DESCRIPTION
    Tries both 64-bit and 32-bit registry views to cover WOW64 scenarios.

.OUTPUTS
    Returns a hashtable with 'Success' (bool) and 'FriendlyName' (string) properties.
#>
function GetWseAudioEffectPackFriendlyName {
    [CmdletBinding()]
    param()

    # Registry views to probe: 64-bit first, then 32-bit
    $registryViews = @(
        [Microsoft.Win32.RegistryView]::Registry64,
        [Microsoft.Win32.RegistryView]::Registry32
    )

    $friendlyName = [string]::Empty

    foreach ($view in $registryViews) {
        $name = Get-FriendlyNameFromView -RegistryView $view

        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $friendlyName = $name
            return @{
                Success = $true
                FriendlyName = $friendlyName
            }
        }
    }

    return @{
        Success = $false
        FriendlyName = [string]::Empty
    }
}
