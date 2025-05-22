Purpose
=======
This repository contains the scripts and tools to conduct Windows Studio Effects (WSE) automated End-to-End Functional and Performance testing. These tests ensure the consistent functionality and reliability of Windows Studio Effects audio and camera effects across various settings.
The tests utilize UIAutomationClient to automate UI interactions, simulating user actions like enabling/disabling effects or adjusting settings. By leveraging these automated tests, teams can confirm that Windows Studio Effects effects remain functional and performant, even under challenging conditions.
Logs are collected and a test report is generated to help provide detailed information to troubleshoot issues.

State of the Repository
=======================
The repository is actively maintained and updated to ensure compatibility with the latest firmware and Windows Studio Effects (WSE) versions. The repository is structured to facilitate easy access to the test scripts and guidelines, ensuring a smooth testing process for authorized personnel.

Set up Repo
=============
**Microsoft Employee**: Link your public GitHub account with Microsoft Corp ID following the steps shared here - **[Link](https://microsoft.sharepoint.com/:w:/r/teams/958_TOR/Shared%20Documents/Validation%20documents/SetupRepo.docx?d=w1768ccca7ad948a2b643c582ed018f69&csf=1&web=1&e=SLJekE)** to create PR and propose changes. 

**Non-Microsoft**: No access required. Fork the repo to propose changes.
* Fork the repository. 
* Make changes.
* Submit a pull request for review.
*  Two reviewers must approve the PR before it can be merged.

Tests Overview
==============

1.    **CheckInTest.ps1:** Validate effects can be toggled On/Off in camera setting page, and the correct scenario ID is generated. Also, includes an end-to-end test for both Camera and Voice Recorder, with device plugged in and unplugged. 
2. **ReleaseTest.ps1:** Runs 800+ tests with various combinations of Camera effects, Voice Focus, video/photo resolution, and plugged-in/unplugged scenarios. Supports multiple video and photo resolutions across different devices. 
3. **StressTest.ps1:** A series of tests designed to put the device under stress (both plugged in and unplugged).
4. **MemoryUsage-Set.ps1:** Captures PeakWorkingSetSize for the frame server process every few minutes while video recording with Windows Studio Effects(camera and audio) enabled, for both plugged-in and unplugged scenarios.
5. **Framedrop-Fps-Testing.ps1:** Captures KPIs (video fps, processing time, frameabove33ms etc) by running the same camerae2e scenario in a loop, with device plugged in and unplugged.

**[Test Result Sample](https://github.com/microsoft/WSEAutomationTests/blob/main/E2E/Documents/Output-Sample-For-CheckinTest-and-ReleaseTest.png)** Please refer to Output-Sample-For-CheckinTest-and-ReleaseTest.png shared under E2E\Documents.

How to Run the Script
=====================
Test Environment Setup
----------------------
* Install the latest Python version(Minimum version required:3.9.13) on device under test. Make sure "pywinauto", "pandas" and other dependencies are installed.
* Set up the test environment with a stable network and dedicated Wi-Fi (for Smart Plug setup).
* Configure the smart plug to execute automation tests with the device both plugged in and unplugged.
* Ensure audio and video recording works, and Camera app and Settings page opens maximized.
* Arrange posters or mannequins with human faces to activate auto-framing animations.

Running the Tests
-----------------
* Download the E2E folder from the repository.
* Launch an elevated PowerShell session.
* Navigate to the E2E folder and run the .ps1 scripts.
* Refer to the following documents for additional setup and execution details. Location for these documents: E2E/Documents 
    - Readme-E2E.txt
    - WSE E2E Automation Test Usage Guidelines

**Sample Report**:  **[Link](https://microsoft-my.sharepoint.com/:x:/p/jdugar/ET2SO8WbD19IgubwEp91xXEBuSB6_6gEC5blyvZqzvahFA?e=FIAXIs)** (Microsoft Internals)
**[Report.png](https://github.com/microsoft/WSEAutomationTests/blob/main/E2E/Documents/Report.png)** Please refer to Report.png shared under E2E/Documents.



Trademarks
-----
This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft’s Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks?oneroute=true). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party’s policies.


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

###Placeholder for Sleep pre-req
