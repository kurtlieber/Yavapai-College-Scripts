# Define the base computer name
$baseComputerName = "BMHS-E200"

# Define the range of computer numbers
$startNumber = 1
$endNumber = 24

# Prompt for credentials
$credential = Get-Credential

# Loop through the range and generate computer names
for ($i = $startNumber; $i -le $endNumber; $i++) {
    $computerName = "{0}-{1:D2}" -f $baseComputerName, $i
    Write-Host "Shutting down $computerName..."

    # Issue remote shutdown command using provided credentials
    Invoke-Command -ComputerName $computerName -Credential $credential -ScriptBlock {
        param($computer)
        Shutdown.exe /s /f /t 0
    } -ArgumentList $computerName

    Write-Host "Shutdown command sent to $computerName"
}
