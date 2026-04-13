# CameraApp Release Test Automation

This PowerShell script automates camera app validation across various camera scenarios, video/photo resolutions, and power states (PluggedIn/Unplugged). It uses smart plug automation to simulate real-world battery behavior and toggles AI effects, voice focus, and system settings.

## Usage

To run tests using this script, use one of the following commands depending on the desired mode:

### 1. Both PluggedIn and Unplugged Tests

Run all scenarios by switching between charging states:
```powershell
.\ReleaseTest.ps1 -token <your_token> -SPId <your_SPId> -runMode "Both"
```
or simply:
```powershell
.\ReleaseTest.ps1 -token <your_token> -SPId <your_SPId>
```

### 2. Only PluggedIn tests

```powershell
.\ReleaseTest.ps1 -token <your_token> -SPId <your_SPId> -runMode "PluggedInOnly"
```
or simply connect charger or smart plug and run
```powershell
.\ReleaseTest.ps1 -runMode "PluggedInOnly"
```
or simply connect charger or smart plug and run
```powershell
.\ReleaseTest.ps1 
```

### 3. Only Unplugged tests

```powershell
.\ReleaseTest.ps1 -token <your_token> -SPId <your_SPId> -runMode "UnpluggedOnly"
```

`Important`: Ensure the device battery is above 20% before starting the tests when running in UnpluggedOnly mode or in Both mode (which includes unplugged scenarios).