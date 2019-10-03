function Load-AwsKeyFile
{
    param(
    [string] $pathToRegisteredAccounts = "$($env:LOCALAPPDATA)\AWSToolkit\RegisteredAccounts.json"
    )

    $registeredAccountsFile = Get-Item $pathToRegisteredAccounts
    $registeredAccountsText = [System.IO.File]::ReadAllText($registeredAccountsFile)
    $registeredAccountsObject = ConvertFrom-Json $registeredAccountsText
    $accountsArray = @()

    foreach($accountObject in $registeredAccountsObject.PsObject.Properties)
    {
        $account = New-Object System.Object
        $account | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $registeredAccountsObject."$($accountObject.Name)".DisplayName
        $account | Add-Member -MemberType NoteProperty -Name "AccessKey" -Value (Decrypt-LikeAws -valueToDecrypt $registeredAccountsObject."$($accountObject.Name)".AWSAccessKey)
        $account | Add-Member -MemberType NoteProperty -Name "SecretKey" -Value (Decrypt-LikeAws -valueToDecrypt $registeredAccountsObject."$($accountObject.Name)".AWSSecretKey)
        $accountsArray += $account
    }
    return $accountsArray
}

function Decrypt-LikeAws 
{
    param(
    [string] $valueToDecrypt
    )
    Add-Type -AssemblyName System.Security
    $dataIn = New-Object System.Collections.ArrayList
    $entropy = New-Object Byte[] 0
    for($i = 0; $i -lt $valueToDecrypt.Length; $i = $i + 2)
    {
        $data = [System.Convert]::ToByte($valueToDecrypt.Substring($i, 2), 16)
        [void]$dataIn.Add($data)
    }
    $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect($dataIn.ToArray(), $entropy, [System.Security.Cryptography.DataProtectionScope]::LocalMachine)
    $decryptedString = [System.Text.Encoding]::Unicode.GetString($decryptedBytes)
    return $decryptedString
}

function Encrypt-LikeAws
{
    param (
        [string] $valueToEncrypt
    )

    $entropy = New-Object Byte[] 0
    Add-Type -AssemblyName System.Security

    $bytesToEncrypt = [System.Text.Encoding]::Unicode.GetBytes($valueToEncrypt)
    $encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect($bytesToEncrypt,$entropy, [System.Security.Cryptography.DataProtectionScope]::LocalMachine)
    $encryptedString = [String]::Empty
    for($i = 0; $i -le $encryptedBytes.Length; $i = $i + 1)
    {
        $encryptedString += [System.Convert]::ToString($encryptedBytes[$i], 16).PadLeft(2, '0').ToUpper()
    }
    return $encryptedString
}