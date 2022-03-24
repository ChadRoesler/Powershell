function Protect-String
{
    param
    (
        [string] $StringToProtect,
        [string] $AesIV,
        [string] $AesKey
    )
    
    $aes = New-Object System.Security.Cryptography.AesCryptoServiceProvider 
    
    $aes.BlockSize = 128
    $aes.KeySize   = 128
    $aes.IV        = [Text.Encoding]::UTF8.GetBytes($AesIV)
    $aes.Key       = [Text.Encoding]::UTF8.GetBytes($AesKey)
    $aes.Mode      = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding   = [System.Security.Cryptography.PaddingMode]::PKCS7
    
    $protectedByteArray = [Text.Encoding]::Unicode.GetBytes($StringToProtect)
    
    $encryptor = $aes.CreateEncryptor()
    $encryptedString = $encryptor.TransformFinalBlock($protectedByteArray, 0, $protectedByteArray.Length);

    return [System.Convert]::ToBase64String($encryptedString);
}

function UnProtect-String
{
    param
    (
        [string] $StringToUnProtect,
        [string] $AesIV,
        [string] $AesKey
    )
    
    $protectedByteArray = [System.Convert]::FromBase64String($StringToUnProtect)
    
    $aes = New-Object System.Security.Cryptography.AesCryptoServiceProvider 
    
    $aes.BlockSize = 128
    $aes.KeySize   = 128
    $aes.IV        = [Text.Encoding]::UTF8.GetBytes($AesIV)
    $aes.Key       = [Text.Encoding]::UTF8.GetBytes($AesKey)
    $aes.Mode      = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding   = [System.Security.Cryptography.PaddingMode]::PKCS7
    
    
    $decryptor = $aes.CreateDecryptor()
    $decryptedString = $decryptor.TransformFinalBlock($protectedByteArray,0,$protectedByteArray.Length)
    return [System.Text.Encoding]::Unicode.GetString($decryptedString);
}

function Get-RandomString
{
    param(
        [int] $Length,
        [switch] $ExcludeSimilar,
        [switch] $ExcludeAmbiguous
    )

    if($ExcludeAmbiguous)
    {
        $symbolArray = [char[]]([char]33) + [char[]]([char]35..[char]38) + [char[]]([char]42..[char]43) + [char[]]([char]45) + [char[]]([char]63..[char]64) + [char[]]([char]94..[char]95) + [char[]]([char]124)
    }
    else
    {
        $symbolArray = [char[]]([char]33..[char]47) + [char[]]([char]58..[char]64) + [char[]]([char]92..[char]96) + [char[]]([char]123..[char]126)
    }

    if($ExcludeSimilar)
    {
        $numberArray = [char[]]([char]50..[char]57)
    }
    else
    {
        $numberArray = [char[]]([char]48..[char]57)
    }

    if($ExcludeSimilar)
    {
        $lowerCaseArray = [char[]]([char]97..[char]104) + [char[]]([char]106..[char]107) + [char[]]([char]109..[char]110) + [char[]]([char]112..[char]122)
    }
    else
    {
        $lowerCaseArray =  [char[]]([char]97..[char]122)
    }

    if($ExcludeSimilar)
    {
        $upperCaseArray = [char[]]([char]65..[char]72) + [char[]]([char]74..[char]75) + [char[]]([char]77..[char]78) + [char[]]([char]80..[char]90)
    }
    else
    {
        $upperCaseArray = [char[]]([char]65..[char]90)
    }

    $finalCharArray = ($symbolArray) + ($numberArray) + ($lowerCaseArray) + ($upperCaseArray)
    $finalString = ""
    while($finalString.Length -lt $Length)
    {
        $finalString += $finalCharArray | Get-Random -Count 1
    }
    return $finalString
}