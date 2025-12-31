Purpose
=======
This repository contains the scripts and tools to conduct Windows Studio Effects (WSE) automated End-to-End Functional and Performance testing. These tests ensure the consistent functionality and reliability of Windows Studio Effects audio and camera effects across various settings. The tests utilize UIAutomationClient to automate UI interactions, simulating user actions like enabling/disabling effects or adjusting settings. By leveraging these automated tests, teams can confirm that Windows Studio Effects effects remain functional and performant, even under challenging conditions. Logs are collected and a test report is generated to help provide detailed information to troubleshoot issues.

State of the Repository
=======================
The repository is actively maintained and updated to ensure compatibility with the latest firmware and Windows Studio Effects (WSE) versions. The repository is structured to facilitate easy access to the test scripts and guidelines, ensuring a smooth testing process for authorized personnel.

Set up Repo
===========
**Microsoft Employee**: Link your public GitHub account with Microsoft Corp ID following the steps shared here - **[Link](https://microsoft.sharepoint.com/:w:/r/teams/958_TOR/Shared%20Documents/Validation%20documents/SetupRepo.docx?d=w1768ccca7ad948a2b643c582ed018f69&csf=1&web=1&e=SLJekE)** to create PR and propose changes.

**Non-Microsoft**: No access required. Fork the repo to propose changes.
- Fork the repository.
- Make changes.
- Submit a pull request for review.
- Two reviewers must approve the PR before it can be merged.

Getting Started
===============
Installation
============
### 1. Clone/Fork/Download the Repository
```powershell
# Clone the repository (if using Git)
git clone <repository-url>
# OR manually download and extract the zip file to C:\WSE\WSEAutomationTests\E2E

```
### 2. Verify Folder Structure
```
WSE\WSEAutomationTests\E2E\
├── CheckInTest.ps1
├── ReleaseTest.ps1
├── StressTest.ps1
├── MemoryUsage-Set.ps1
├── ScenarioTest.ps1
├── Framedrop-FPS-Testing.ps1
├── CameraReliabilityTest.ps1
├── Helper/
│   ├── InitializeTest.ps1
│   └── ... (other helper scripts)
├── Library/
│   ├── CameraAppHandlers.ps1
│   ├── TaskManager.ps1
│   └── ... (other libraries)
├── LoggerBinaries/
├── Documents/
└── TestResults/ (generated during runs)
```

Test Environment Setup
----------------------
* Set up the test environment with a stable network and dedicated Wi-Fi (for Smart Plug setup).
* Configure the smart plug to execute automation tests with the device both plugged in and unplugged.
* Ensure audio and video recording works, and Camera app and Settings page opens maximized.
* Arrange posters or mannequins with human faces to activate auto-framing animations.

**Typical Test Durations:**
- CheckInTest: 30-60 minutes
- ReleaseTest: 1-4 days (V1+V2 features, Recording+Previewing, PluggedIn+Unplugged)
- StressTest: 3-4 hours

Test Scripts
============
### 1. **CheckInTest.ps1** - Basic Validation
**Purpose:** Verify basic functionality of each Windows Studio Effect.

**Features:**
- Tests individual effect toggles (On/Off)
- Verifies correct scenario IDs are generated
- End-to-end camera and voice recorder tests
- Tests both plugged-in and unplugged scenarios
- Results are logged and converted into an Excel report for analysis.

#### How to Run Script
##### Basic Execution (No Parameters)
```powershell
cd C:\WSE\WSEAutomationTests\E2E
.\CheckInTest.ps1
```

##### With All Parameters
```powershell
.\CheckInTest.ps1 -token "your_token" -SPId "your_SPId" -targetMepCameraVer "23.0.1" -targetMepAudioVer "23.0.1" -targetPerceptionCoreVer "1.0.0"
```

### 2. **ReleaseTest.ps1** - Comprehensive Coverage
**Purpose:** Extensive testing across multiple resolutions and combinations

**Features:**
- 800+ test combinations
- Run tests with highest, 720p and lowest or 360p video resolutions (device-dependent)
- Run tests with single photo resolutions (Preferably 2.1MP)
- Multiple effect combinations
- Plugged-in and unplugged scenarios
- Battery management with smart plug integration
- Results are logged and converted into an Excel report for analysis.
- ReRunFailedTest.ps1 is generated with the details of all failed tests after ReleaseTest.ps1 finishes.

#### How to Run Script
##### Basic Execution (Plugged-In Only)
```powershell
cd C:\WSE\WSEAutomationTests\E2E
.\ReleaseTest.ps1
```

##### With Parameters
###### I. Both PluggedIn and Unplugged Tests
Run all scenarios by switching between charging states:
```powershell
.\ReleaseTest.ps1 -token <your_token> -SPId <your_SPId> -runMode "Both"
```
or simply:
```powershell
.\ReleaseTest.ps1 -token <your_token> -SPId <your_SPId>
```

###### II. Only PluggedIn tests
```powershell
.\ReleaseTest.ps1 -token <your_token> -SPId <your_SPId> -runMode "PluggedInOnly"
```
or simply connect charger or smart plug and run
```powershell
.\ReleaseTest.ps1 -runMode "PluggedInOnly"
```
or 
```powershell
.\ReleaseTest.ps1
```

###### III. Only Unplugged tests
```powershell
.\ReleaseTest.ps1 -token <your_token> -SPId <your_SPId> -runMode "UnpluggedOnly"
```
`Important`: Ensure the device battery is above 20% before starting the tests when running in UnpluggedOnly mode or in Both mode (which includes unplugged scenarios).

###### IV. All Parameters
```powershell
.\ReleaseTest.ps1 -token "your_token" -SPId "your_SPId" -targetMepCameraVer "23.0.1" -targetMepAudioVer "23.0.1" -targetPerceptionCoreVer "1.0.0" -runMode "Both"
```

### 3. **StressTest.ps1** - Device Stress Testing
**Purpose:** Test device stability under stress conditions

**Features:**
- Multiple hibernation cycles
- Rapid effect toggling
- Repeated camera setting page access
- App minimize/maximize cycles
- Both plugged-in and unplugged scenarios

If running StressTest.ps1, hibernation must be enabled:

**Step 1: Enable Hibernation**
```powershell
# Run as Administrator
powercfg.exe /hibernate on
```

**Step 2: Enable Hibernation in Settings**
1. Open Control Panel → Hardware and Sound → Power Options
2. Click "Choose what the power button does"
3. Enable the "Hibernation" checkbox

**Step 3: Configure Wake Timers**
1. Open Control Panel → Power Options
2. Click "Edit Plan Settings" for your current power plan
3. Click "Change Advanced Power Settings"
4. Navigate to Sleep → "Allow wake timers"
5. Enable for both plugged-in and battery states
6. Setup Auto-Login

#### How to Run Script
##### Basic Execution (No Parameters)
```powershell
cd C:\WSE\WSEAutomationTests\E2E
.\StressTest.ps1
```

##### With All Parameters
```powershell
.\StressTest.ps1 -token "your_token" -SPId "your_SPId" -targetMepCameraVer "23.0.1" -targetMepAudioVer "23.0.1" -targetPerceptionCoreVer "1.0.0"
```

### 4. **MemoryUsage-Set.ps1** - Memory Profiling
**Purpose:** Capture detailed memory usage patterns

**Features:**
- Peak working set tracking for Frame Server process
- Continuous monitoring during video recording
- Both plugged-in and unplugged states
- Time-series data collection

#### How to Run Script
##### Basic Execution (No Parameters)
```powershell
cd C:\WSE\WSEAutomationTests\E2E
.\MemoryUsage-Set.ps1
```

##### With All Parameters
```powershell
.\MemoryUsage-Set.ps1 -token "your_token" -SPId "your_SPId" -targetMepCameraVer "23.0.1" -targetMepAudioVer "23.0.1" -targetPerceptionCoreVer "1.0.0"
```

### 5. **CheckInTest_External_USB_Camera.ps1** - External Camera Validation
**Purpose:** Validate Windows Studio Effects with external USB cameras

**Features:**
- Same coverage as CheckInTest but for external cameras
- Useful for compatibility testing
- Results are logged and converted into an Excel report for analysis.

#### How to Run Script
##### Basic Execution (No Parameters)
```powershell
cd C:\WSE\WSEAutomationTests\E2E
.\CheckInTest_External_USB_Camera.ps1
```

##### With All Parameters
```powershell
.\CheckInTest_External_USB_Camera.ps1 -token "your_token" -SPId "your_SPId" -targetMepCameraVer "23.0.1" -targetMepAudioVer "23.0.1" -targetPerceptionCoreVer "1.0.0" -CameraType "External Camera"
```

### 6. **Framedrop-Fps-Testing.ps1** - Performance Profiling
**Purpose:** Captures KPIs (video fps, processing time, frameabove33ms etc) by running the same camerae2e scenario in a loop, with device plugged in and unplugged.

**Features:**
- Video FPS measurement
- Frame processing time analysis
- Frame above > 33ms tracking
- TimeToFirstFrame for PC measurement
- Results are logged and converted into an Excel report for analysis.
- Generates a graph for video fps, (min/max/avg) processing time, frame above 33 ms

#### How to Run Script
##### Basic Execution (No Parameters)
```powershell
cd C:\WSE\WSEAutomationTests\E2E
.\Framedrop-Fps-Testing.ps1
```

##### With All Parameters
```powershell
.\Framedrop-Fps-Testing.ps1 -token "your_token" -SPId "your_SPId" -targetMepCameraVer "23.0.1" -targetMepAudioVer "23.0.1" -targetPerceptionCoreVer "1.0.0" -CameraType "External Camera"
```

### 7. **ScenarioTest.ps1** - Scenario-Specific Testing
**Purpose:** Validate Camera App behavior for specific recording or preview scenarios by applying configurable AI camera effects, resolutions, Voice Focus settings, and device power states.

**Features:**
- Targeted scenario testing
- Custom scenario configuration
- Detailed scenario logging
- Set -toggleAIEffects "All" to dynamically test all supported AI effects on the device.
- If Voice Focus policy is not available, the script automatically sets VF to NA.
- Results are logged and converted into an Excel report for analysis.

**Run:**
```powershell
.\ScenarioTest.ps1
```

#### How to Run Script
##### With All Parameters
```powershell
.\ScenarioTest.ps1 -token "<SmartPlugToken>" -SPId "<SmartPlugId>" -targetMepCameraVer "<ExpectedCameraMEPVersion>" -targetMepAudioVer "<ExpectedAudioMEPVersion>" `
-targetPerceptionCoreVer "<ExpectedPCVersion>" -logFile "ScenarioTesting.txt" `
-toggleAIEffects "AFS+BBS+ECS","AFS+BBP+ECS","AFS+CF-I+PL+BBS" -initSetUpDone "false" `
-camsnario "Recording" -VF "On" -vdoRes "1080p, 16 by 9 aspect ratio, 30 fps" `
-ptoRes "2.1 megapixels, 16 by 9 aspect ratio, 1920 by 1080 resolution" -devPowStat "Pluggedin"
```

Logs Format
===========
E2E\Logs\<DateTime>-<TestRunName>

Examples:
- E2E\Logs\2023-12-12-09-26-02-Checkin-Test
- E2E\Logs\2023-12-12-09-26-02-ReleaseTest

Interpretation of Console Output
================================
Console output format:
```
<Scenario> : <Result> (<Execution Time in seconds>)
```
Example:
```
Pluggedin\AFS: Passed (159.27)
```
Logs captured here:
- Asgtrace: 2023-12-12-09-26-02-Checkin-Test\Pluggedin\AFS\Asgtrace (Generated for each individual WSE effect (camera and audio) for both plugged in and unplugged).
- Console Result: 2023-12-12-09-26-02-Checkin-Test\ConsoleResults
- Report: 2023-12-12-09-26-02-Checkin-Test\Report.
- Test run logs: 2023-12-12-09-26-02-Checkin-Test\Pluggedin-AFS (Generated for each individual WSE effect (camera and audio) effect).

## Documentation
For additional guidance, refer to the following documents in `E2E/Documents`:
- Read-ME.txt
- WSE E2E Automation Test Usage Guidelines

## References
**[Test Result Sample](https://github.com/microsoft/WSEAutomationTests/blob/main/E2E/Documents)** - See Output-Sample-For-CheckinTest-and-ReleaseTest.png and Report.png and Report.xlsx under E2E/Documents


Trademarks
----------
This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft’s Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks?oneroute=true). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party’s policies.


