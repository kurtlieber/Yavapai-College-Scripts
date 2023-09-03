:: Run locally on machine - must be run w/ admin privileges
@echo off

:: Enable PowerShell Remote Execution
echo Enabling PowerShell Remote Execution...
powershell -Command "Enable-PSRemoting -Force"

:: Allow Unencrypted Traffic (Optional)
echo Allowing Unencrypted Traffic...
powershell -Command "Set-Item WSMan:\localhost\client\trustedhosts * -Force"

:: Restart WinRM Service
echo Restarting WinRM Service...
net stop winrm
net start winrm

echo PowerShell Remote Execution is now enabled.
pause
