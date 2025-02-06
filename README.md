Purpose
=======
This repository contains the scripts and tools to conduct Windows Studio Effects (WSE) automated End-to-End Functional and Performance testing. These tests ensure the consistent functionality and reliability of Windows Studio Effects audio and camera effects across various settings.
The tests utilize UIAutomationClient to automate UI interactions, simulating user actions like enabling/disabling effects or adjusting settings. By leveraging these automated tests, teams can confirm that Windows Studio Effects effects remain functional and performant, even under challenging conditions.
Logs are collected and a test report is generated to help provide detailed information to troubleshoot issues.

State of the Repository
=======================
The repository is actively maintained and updated to ensure compatibility with the latest firmware and Windows Studio Effects (WSE) versions. The repository is structured to facilitate easy access to the test scripts and guidelines, ensuring a smooth testing process for authorized personnel.


Tests Overview
==============

1.    **CheckInTest.ps1:** Validate effects can be toggled On/Off in camera setting page, and the correct scenario ID is generated. Also, includes an end-to-end test for both Camera and Voice Recorder, with device plugged in and unplugged.
2. **ReleaseTest.ps1:** Runs 800+ tests with various combinations of Camera effects, Voice Focus, video/photo resolution, and plugged-in/unplugged scenarios. Supports multiple video and photo resolutions across different devices.
3. **StressTest.ps1:** A series of tests designed to put the device under stress (both plugged in and unplugged).
4. **MemoryUsage-Set.ps1:** Captures PeakWorkingSetSize for the frame server process every few minutes while video recording with Windows Studio Effects(camera and audio) enabled, for both plugged-in and unplugged scenarios.
5. **Framedrop-Fps-Testing.ps1:** Captures KPIs (video fps, processing time, frameabove33ms etc) by running the same camerae2e scenario in a loop, with device plugged in and unplugged.  
 
How to Run the Script
=====================
Test Environment Setup
----------------------
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

Sample Report:  **[Link](https://microsoft-my.sharepoint.com/:x:/p/jdugar/ET2SO8WbD19IgubwEp91xXEBuSB6_6gEC5blyvZqzvahFA?e=FIAXIs)** 
---


Trademarks
-----
This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft’s Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks?oneroute=true). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party’s policies.
