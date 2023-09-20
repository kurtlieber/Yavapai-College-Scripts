$baseComputerName = "test"
$source = "\\test-01\scripts`$\"
$exeFile = $source + "veyon-4.8.2.0-win64-setup.exe"
$jsonFile = $source + "e200-config.json"
$pemFile = $source + "administrators_public_key.pem"
$installParams = "/S /NoMaster /ApplyConfig=$jsonFile"

$veyon-cli = "c:\Program Files\Veyon\veyon-cli"
$keyImportParams = "authkeys import administrators/public $pemFile"

# Define the range of computer numbers
$startNumber = 2
$endNumber = 4

$credential = Get-Credential

for ($i = $startNumber; $i -le $endNumber; $i++) {
    $computerName = "{0}-{1:D2}" -f $baseComputerName, $i

    Invoke-Command -ComputerName $computerName -Credential $credential -ScriptBlock {
        param($computer)
        $exeExists = Test-Path -Path $using:exeFile
        $jsonExists = Test-Path -Path $using:jsonFile

        if ($exeExists -and $jsonExists) {

            $process = Start-Process -FilePath $exeFile -ArgumentList $installParams -PassThru
            $process.WaitForExit()
            $import = Start-Process -FilePath $veyon-cli -ArgumentList $keyImportParams -PassThru
            $import.WaitForExit()

        } else {
            Write-Host "One or both files were not available."
        }

    } -ArgumentList $computerName

}

