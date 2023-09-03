################################################################################
# ch3-baseline.ps1
# v0.1 - 20230903 - intitial version
#
# resets various networking components on Windows 10 to a baseline config
# designed primarily to reset CNT 101 computers prior to doing Ch 3 labs.
#
# USAGE:
# Powershell must be configured to run unsigned scripts:
#
#    Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force (as Admin)
#
# Powershell may still complain about scripts from the internet.
# You can turn off this warning via
#
#    Unblock-File -Path 'Path\To\Your\File.exe'  (as Admin)    
#
# Next, configure $adapterName below and/or pass it via command line.
# (command line flag will override variable set below)
#
# then just run the script as an Administrator:
#
# .\ch3-baseline.ps1
#
# or
#
# .\ch3-baseline.ps1 -r -a "PC-A"
#
# COMMAND LINE OPTIONS:
# -a <adapter name> : set name of adapter to be modified. (will override 
#                     $adapterName configured below)
# -r                : optional flag.  will reboot the comptuer after finishing.  
#                     Not strictly necessary, but Widnows doesn't do well
#                     when all these changes are made at once without a reboot
#                     So it is STRONGLY recommended you reboot the computer
################################################################################
#
# Declare the parameters for command-line input
param(
    [string]$a = "",
    [switch]$r = $false
)

# Name of the ethernet adapter to configure.  
$adapterName = "PC-A"

# check for admin privs.  bail out if not present.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "Error: This script requires administrative privileg. Exiting."
    exit 1
}

# use hard-coded $adapterName if no command line argument present
$aName = if ($a -ne "") { $a } else { $adapterName }

# Check if the adapter exists
$adapter = Get-NetAdapter | Where-Object { $_.Name -eq $adapterName }

if ($null -eq $adapter) {
    Write-Host "Error: Adapter '$aName' not found. Exiting script."
    exit 1
}

# Set the interface speed to Auto Negotiation
Set-NetAdapterAdvancedProperty -Name $aName -DisplayName "Speed & Duplex" -DisplayValue "Auto Negotiation"

# Set IP Configuration to DHCP for adapter
Set-NetIPInterface -InterfaceAlias $aName -Dhcp Enabled

# Turn off Windows Firewall for all profiles
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Turn on File and Print Sharing for Private Network Profile
Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Profile Private -Enabled True

# Get the network profile associated with the adapter and set it to Private
$netProfile = Get-NetConnectionProfile -InterfaceAlias $aName
if ($netProfile -ne $null) {
    Set-NetConnectionProfile -InterfaceAlias $aName -NetworkCategory Private
}

# Output to confirm changes
Write-Host "Interface speed set to Auto Negotiation"
Write-Host "IP configuration set to DHCP for '$adapterName'"
Write-Host "Windows Firewall turned off for all profiles"
Write-Host "File and Print Sharing enabled for private networks"
Write-Host "Network set to private for '$adapterName'"

# 10 second optional reboot warning
if ($r) {
    Write-Host "System will reboot in 10 seconds...Ctrl-C to cancel."
    Start-Sleep -Seconds 10

    # Reboot the computer
    Restart-Computer
}