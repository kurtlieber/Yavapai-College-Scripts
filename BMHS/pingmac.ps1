param (
    [string]$OutputCsv
)

# Prompt for the base computer name
$baseComputerName = Read-Host "Enter the base computer name"

# Define the range of computer numbers
$startNumber = 1
$endNumber = 24

# Initialize an array to store ping results
$pingResults = @()

# Loop through the range and ping each computer
for ($i = $startNumber; $i -le $endNumber; $i++) {
    $computerName = "{0}{1:D2}" -f $baseComputerName, $i
    $pingResult = Test-Connection -ComputerName $computerName -Count 1 -ErrorAction SilentlyContinue
    $pingResults += [PSCustomObject]@{
        ComputerName = $computerName
        Online = $null -ne $pingResult
    }
}

# Initialize a hashtable to store MAC addresses
$macAddresses = @{}

# Iterate through ping results and collect MAC addresses
foreach ($result in $pingResults) {
    if ($result.Online) {
        $ipAddress = (Resolve-DnsName -Name $result.ComputerName).IPAddress
        $neighbor = Get-NetNeighbor -IPAddress $ipAddress
        if ($neighbor) {
            $macAddress = $neighbor.LinkLayerAddress
            $macAddresses[$result.ComputerName] = $macAddress
        }
    }
}

# Display the collected MAC addresses sorted by computer name
Write-Host "Name              MAC"
Write-Host "=============================="
$macAddresses.GetEnumerator() | Sort-Object -Property Name | ForEach-Object {
    Write-Host ("{0},{1}" -f $_.Key, $_.Value)
}

# Export to CSV if OutputCsv is provided
if ($OutputCsv) {
    $macAddresses.GetEnumerator() | Sort-Object -Property Name | Select-Object @{Name='ComputerName'; Expression={$_.Key}}, @{Name='MACAddress'; Expression={$_.Value}} | Export-Csv -Path $OutputCsv -NoTypeInformation
}