WSE e2e Automation Test Usage Guidelines 

1. Understanding Automation Test Purpose:
•	Familiarize yourself with the primary goal of automation testing, which is to ensure the consistent functionality and reliability of WSE audio and camera effects across various settings
•	Understand that automation tests are designed specifically to confirm that WSE effects remain functional even under challenging conditions.

2. Access Control:
•	Ensure that access to automation test scripts, tools, and results is restricted to authorized personnel only and is not to be shared further.
•	Grant appropriate permissions based on team members' roles and responsibilities. 
•	Limit the sharing of the logger tool to maintain security.
 
3. Test Environment Setup:
•	Set up the test environment with a stable network and dedicated Wi-Fi (for Smart Plug setup). 
•	Configure the smart plug to execute automation tests with the device both plugged in and unplugged. 
•	Arrange posters or mannequins with human faces to activate auto-framing animations.
•	Conduct automation tests in a controlled manner to minimize any potential impact on the application or its surroundings.
 
4. Test Execution Guidelines:
•	Keep the device updated with the latest firmware and install the WSE under test. 
•	Conduct a manual Sanity test: Camera app and Setting app page opens maximized, ensure the ability to toggle WSE effects (both audio and video) in the settings page and perform audio and video recordings.
 
5. Readme-E2E script Overview and Execution Steps link:
•	Refer to the Readme-E2E.txt document for an overview and detailed execution steps. Location:E2E/Documents
 
6. Handling Test Results:
•	Treat automation test results as confidential information and limit access to authorized personnel only.

7.Feedback Mechanism:
•	We encourage you to provide feedback on the scripts to facilitate continuous improvement. Your input is valuable for enhancing the testing process.
 
By following these guidelines, teams can effectively leverage automation tests from a security perspective. 

## Trademarks
This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.