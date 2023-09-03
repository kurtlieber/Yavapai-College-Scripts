###########################################################################################
# 2023-08-16                                                                                    
# v0.1                                                                                    
# Script to add new local account to a group of Windows 10 computers                      
# This is only tested (so far) on BMHS lab computers in E200 
# 
# Remote computers must have Powershell remote execution enabled and also allow unencrypted traffic
# see enable-remoting.bat for examples of how to do this# 
#                                                      
# CHANGELOG                                                                                 
# =========                                                                               
# v0.1 - initial version                                                                  
###########################################################################################

# Generate computer names based on a range of numbers
$baseName = "BMHS-E200-"
$startingNumber = 1
$endingNumber = 1
$computerNames = 1..$endingNumber | ForEach-Object { "$baseName$('{0:D2}' -f $_)" }

# Prompt for new user details
$newUserName = Read-Host "Enter the new username"

# Prompt for the new password and confirm password
do {
    $newUserPassword = Read-Host "Enter the new password for the new user" -AsSecureString
    $confirmNewUserPassword = Read-Host "Confirm the new password" -AsSecureString

    $newPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($newUserPassword))
    $confirmPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmNewUserPassword))

    if ($newPasswordText -ne $confirmPasswordText) {
        Write-Host "Passwords do not match. Please try again."
    }
} while ($newPasswordText -ne $confirmPasswordText)

$newUserPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($newUserPassword))

# Prompt for common credentials if needed
$commonCredentials = $null
$useCommonCredentials = Read-Host "Do all computers have the same username and password for connection? (Y/N, default: Y)" 
if ($useCommonCredentials -eq "" -or $useCommonCredentials -eq "Y" -or $useCommonCredentials -eq "y") {
    $commonUsername = Read-Host "Enter the common username"
    Write-Host "Enter this password carefully.  Script blows up if not entered correctly." -ForegroundColor Red
    $commonPassword = Read-Host "Enter the password for the common username" -AsSecureString
    $commonCredentials = New-Object System.Management.Automation.PSCredential ($commonUsername, $commonPassword)
}

# Loop through and do the actual work
foreach ($computerName in $computerNames) {
    try {
        $credential = if ($commonCredentials) { $commonCredentials } else { Get-Credential }

        $existingUser = Invoke-Command -ComputerName $computerName -Credential $credential -ScriptBlock {
            param($userName)
            $user = Get-LocalUser -Name $userName -ErrorAction SilentlyContinue
            $userExists = $user -ne $null
            $userIsAdmin = $false
            if ($userExists) {
                $group = [ADSI]"WinNT://./Administrators,group"
                $admins = $group.Invoke("Members") | ForEach-Object { $_.GetType().InvokeMember("Name", [System.Reflection.BindingFlags]::GetProperty, $null, $_, $null) }
                if ($admins -contains $userName) {
                    $userIsAdmin = $true
                }
            }
            return [PSCustomObject]@{
                Exists = $userExists
                IsAdmin = $userIsAdmin
            }
        } -ArgumentList $newUserName

        if ($existingUser.Exists) {
            if (-not $existingUser.IsAdmin) {
                Write-Host "User account $newUserName already exists on $computerName but is not in the Administrators group. Adding to group..."
                $session = New-PSSession -ComputerName $computerName -Credential $credential
                Invoke-Command -Session $session -ScriptBlock {
                    param($userName)
                    $adminsGroup = [ADSI]"WinNT://./Administrators,group"
                    $adminsGroupMembers = $adminsGroup.Invoke("Members")
                    $userPath = "WinNT://$env:COMPUTERNAME/$userName,user"
                    $userAlreadyAdded = $false
                    foreach ($member in $adminsGroupMembers) {
                        if ($member.Path -eq $userPath) {
                            $userAlreadyAdded = $true
                            break
                        }
                    }
                    if (-not $userAlreadyAdded) {
                        $addUserCommand = "net localgroup Administrators $env:COMPUTERNAME\$userName /add"
                        Invoke-Command -ScriptBlock { param($command) Invoke-Expression $command } -ArgumentList $addUserCommand
                        Write-Host "User $userName added to Administrators group on $computerName."
                    }                    
                } -ArgumentList $newUserName
                Remove-PSSession -Session $session
                Write-Host "User $newUserName added to Administrators group on $computerName."
            }
            $session = New-PSSession -ComputerName $computerName -Credential $credential
            Invoke-Command -Session $session -ScriptBlock {
                param($userName, $userPassword)
                $userPasswordSecure = ConvertTo-SecureString $userPassword -AsPlainText -Force
                Set-LocalUser -Name $userName -Password $userPasswordSecure
            } -ArgumentList $newUserName, $newUserPasswordPlain
            Remove-PSSession -Session $session
            Write-Host "Password for user account $newUserName reset on $computerName."
        } else {
            Write-Host "Creating user account $newUserName on $computerName..."
            $scriptBlock = {
                param($userName, $userPassword)
                $userPasswordSecure = ConvertTo-SecureString $userPassword -AsPlainText -Force
                New-LocalUser -Name $userName -Password $userPasswordSecure
            }

            $session = New-PSSession -ComputerName $computerName -Credential $credential
            Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $newUserName, $newUserPasswordPlain
            Remove-PSSession -Session $session

            Write-Host "User account $newUserName created on $computerName."

            $session = New-PSSession -ComputerName $computerName -Credential $credential
            Invoke-Command -Session $session -ScriptBlock {
                param($userName)
                $adminsGroup = [ADSI]"WinNT://./Administrators,group"
                $adminsGroup.Add("WinNT://$env:COMPUTERNAME/$userName")
            } -ArgumentList $newUserName
            Remove-PSSession -Session $session

            Write-Host "User $newUserName added to Administrators group on $computerName."

            $session = New-PSSession -ComputerName $computerName -Credential $credential
            Invoke-Command -Session $session -ScriptBlock {
                param($userName, $userPassword)
                $userPasswordSecure = ConvertTo-SecureString $userPassword -AsPlainText -Force
                Set-LocalUser -Name $userName -Password $userPasswordSecure
            } -ArgumentList $newUserName, $newUserPasswordPlain
            Remove-PSSession -Session $session
            Write-Host "Password for user account $newUserName reset on $computerName."
        }
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Host "Failed to create/update user account on $computerName. Error: $errorMessage"
    }
}
