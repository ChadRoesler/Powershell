<#
 .Synopsis
  Returns a credential from the privately-stored keyed credentials

 .Description
  Returns a credential from the privately-stored keyed credentials

 .Parameter Username
  The username associated with the privately-stored credential
#>
function Get-KeyedCredentials
{
    param(
        [string] $username = $env:USERNAME,
        [string] $encryptedPassword = $null,
        [byte[]] $key = $null
    )

    if($null -eq $encryptedPassword -or $null -eq $key)
    {
        $UserPrivateData = $PrivateData[$username]
        $PrivateData = $MyInvocation.MyCommand.Module.PrivateData
        $password = $UserPrivateData['EncryptedCredential'] | ConvertTo-SecureString -Key $UserPrivateData['Key']
    }
    else 
    {
        $password = $encryptedPassword | ConvertTo-SecureString -Key $key
    }
    $credential = New-Object System.Management.Automation.PsCredential($username, $password)

    Return $credential
}

<#
 .Synopsis
  Creates keyed credentials for a given username

 .Description
  Creates keyed credentials for a given username

 .Parameter username
  The username from which to prompt for credentials
#>
function New-KeyedCredentials
{
    param(
        [string] $username = $env:USERNAME,
        [byte[]] $key = $null
    )

    if($null -eq $key)
    {
        $key = New-Object Byte[] 32
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($key)
    }
    $encryptedPassword = (Get-Credential $username).Password | ConvertFrom-SecureString -Key $key
    $keyedCredentials = @{ "Key" = $key; "EncryptedPassword" = $encryptedPassword }
    return $keyedCredentials
}