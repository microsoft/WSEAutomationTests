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
	Write-Host $message
	Write-Output $message >> $pathLogsFolder\$OUTPUT_TRAGET_FILE_NAME
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
	This function is designed to parse DxDiag information and collect MEP Opt-in data.
#>
function parseOptInCameraInfoFromDxDiagInfo()
{
	$outputDxDiagFilePath = "$pathLogsFolder\$OUTPUT_DXDIAG_FILE_NAME"

	Start-Process "dxdiag.exe" -ArgumentList "/t $outputDxDiagFilePath" -Wait

	# Read the content of the generated output DxDiag file
	$dxdiagContent = Get-Content -Path $outputDxDiagFilePath

	# to extract information using Select-String and regex patterns,
	# in DxDiag, it first outputs the video capture device, followed by the sensor capture device,
	# as we select the first object from the 'Video Capture Devices' information
	$optinCameraFriendlyName = $dxdiagContent | Select-String -Pattern "FriendlyName: (.+)" | Select-Object -First 1 | ForEach-Object { $_ -replace "^\s+FriendlyName: ", "" }
	$optinCameraDriverVersion = $dxdiagContent | Select-String -Pattern "DriverVersion: (.+)" | Select-Object -First 1 | ForEach-Object { $_ -replace "^\s+DriverVersion: ", "" }
	$optinCameraHardwareID = $dxdiagContent | Select-String -Pattern "HardwareID: (.+)" | Select-Object -First 1 | ForEach-Object { $_ -replace "^\s+HardwareID: ", "" }
	$mepCameraOptedIn = $dxdiagContent | Select-String -Pattern "MEPOptedIn: (.+)" | Select-Object -First 1 | ForEach-Object { $_ -replace "^\s+MEPOptedIn: ", "" }
	$mepDriverVersion = $dxdiagContent | Select-String -Pattern "MEPVersion: (.+)" | Select-Object -First 1 | ForEach-Object { $_ -replace "^\s+MEPVersion: ", "" }
	$optinCameraMepHighResMode = $dxdiagContent | Select-String -Pattern "MEPHighResMode: (.+)" | Select-Object -First 1 | ForEach-Object { $_ -replace "^\s+MEPHighResMode: ", "" }

	$parseResults = [PSCustomObject]@{
		optinCameraFriendlyName		= $optinCameraFriendlyName
		optinCameraDriverVersion	= $optinCameraDriverVersion
		optinCameraHardwareID		= $optinCameraHardwareID
		mepCameraOptedIn			= $mepCameraOptedIn
		mepDriverVersion			= $mepDriverVersion
		optinCameraMepHighResMode	= $optinCameraMepHighResMode
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
#>

function WseEnablingStatus($targetMepCameraVer, $targetMepAudioVer, $targetPerceptionCoreVer) {

	# check device manager for NPU opt-in
	$wseCameraDriverInstance = getWseCameraDriverInstance
	if ($null -eq $wseCameraDriverInstance) {
		Write-Host "can not find '$WSE_CAMERA_DRIVER_FRIENDLY_NAME' in device manager, extension .inf for MEP camera was not correctly deployed" -ForegroundColor Red
		return $false
	}

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
		Write-Host "can not find Opt-in camera instance in registry, there is no 'FSMEnableMsEffects' key in registry" -ForegroundColor Red
		return $false
	}
	elseif ($mepCameraOptedIn -ieq "False")
	{
		Write-Host "'FSMEnableMsEffects' key was not set to 1 in registry" -ForegroundColor Red
		return $false
	}

	displaySystemInfo
	outputMessage "Opt-In Camera Status: $mepCameraOptedIn"

	if ($optinCameraFriendlyName) {
		outputMessage "Opt-In Camera FriendlyName: $optinCameraFriendlyName"
	} else {
		Write-Host "Opt-In Camera FriendlyName Info not found"
	}

	if ($optinCameraHardwareID) {
		outputMessage "Opt-In Camera Hardware ID: $optinCameraHardwareID"
	} else {
		Write-Host "Opt-In Camera Hardware Info not found"
	}

	if ($optinCameraDriverVersion){
		outputMessage "Opt-In Camera Driver: $optInCameraDriverVersion"
	} else {
		Write-Host "Opt-In Camera Driver Info not found"
	}

	if ($optinCameraMepHighResMode){
		outputMessage "Opt-In Camera HighRes Mode: $optinCameraMepHighResMode"
	} else {
		Write-Host "Opt-In Camera HighRes Info not found"
	}

	# output WSE camera driver info if exists
	if ($wseCameraDriverInstance) {
		outputDriverInfoByFriendlyName $wseCameraDriverInstance
		if ($targetMepCameraVer -and ($targetMepCameraVer -ne $wseCameraDriverInstance.driverVersion)) {
			Write-Host "User input MEP-camera version: $targetMepCameraVer"
			return $false
		}
	}

	# output WSE audio driver info if exists
	$wseAudioDriverInstance = getWseAudioDriverInstance
	if ($wseAudioDriverInstance) {
		outputDriverInfoByFriendlyName $wseAudioDriverInstance
		if ($targetMepAudioVer -and ($targetMepAudioVer -ne $wseAudioDriverInstance.driverVersion)) {
			Write-Host "User input MEP-audio version: $targetMepAudioVer"
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
			Write-Host "User input PerceptionCore version: $targetPerceptionCoreVer"
			return $false
		}
	} else {
		Write-Host "PerceptionCore.dll not found"
		return $false
	}

	# output Camera UWP version
	$camerAppVersion = Get-AppXPackage -Name "Microsoft.WindowsCamera"  | Select-Object -ExpandProperty Version
	if ($camerAppVersion) {
		outputMessage "CameraApp(UWP): $camerAppVersion"
	}

	return $true
}
