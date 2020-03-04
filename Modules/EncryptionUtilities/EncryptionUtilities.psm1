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