<#
  .Synopsis
  Scaffolds a PSSession with the associated PSSessionConfiguration

  .Parameter Servers
  An array of the hostnames to connect to
#>
function New-KeyedPSSession
{
    param (
        [string] $user,
        [string] $encryptedPassword = $null,
        [byte[]] $key = $null,
        [string[]] $servers = @("localhost")
    )

    Write-Log "Attempting to create a multi-hop friendly PSSessionConfiguration"

    if($null -eq $encryptedPassword -or $null -eq $key)
    {
        New-KeyedPSSessionConfiguration -user $user `
                                        -servers $Servers
    }
    else
    {
        New-KeyedPSSessionConfiguration -user $user `
                                        -encryptedPassword $encryptedPassword `
                                        -key $key `
                                        -servers $servers
    }

    # Give the session 5 minutes of idle time
    $sessionOption = New-PSSessionOption -IdleTimeoutMSec 300000
    if($null -eq $encryptedPassword -or $null -eq $key)
    {
        $credentials = Get-KeyedCredentials -username "$($user)"
    }
    else 
    {
        $credentials = Get-KeyedCredentials -username "$($user)" `
                                            -encryptedPassword $encryptedPassword `
                                            -key $key
    }
    $keyedSessions = New-PSSession -ComputerName $servers `
                                    -Credential $credentials `
                                    -ConfigurationName "EscalatedConfiguration"

    return $keyedSessions
}

<#
    .Synopsis
    Creates a PSSessionConfiguration with a credential object, allowing for multi-hopping.

    .Parameter Servers
    An array of the hostnames to connect to
#>
function New-KeyedPSSessionConfiguration
{
    param (
        [string] $user,
        [string] $encryptedPassword = $null,
        [byte[]] $key = $null,
        [string[]] $servers = @("localhost")
    )

    if($null -eq $encryptedPassword -or $null -eq $key)
    {
        $credentials = Get-KeyedCredentials -Username "$($user)"
    }
    else 
    {
        $credentials = Get-KeyedCredentials -username "$($user)" `
                                            -encryptedPassword $encryptedPassword `
                                            -key $key    
    }
    $hostNames = @()
    
    foreach($server in $servers)
    {
        if($server -ne "localhost")
        {
            try
            {
                $hostName = ([System.Net.Dns]::GetHostByName($server)).HostName
            }
            catch
            {
                $hostName = $server
            }
            $hostNames += $hostName
        }
        else 
        {
            $hostNames += $env:COMPUTERNAME
        }
    }
    $session = New-PSSession -ComputerName $hostNames `
                             -Credential $credentials `
                             -Name "EscalatedConfiguration"

    Write-Log "Creating a multi-hop friendly PSSessionConfiguration on the server"

    # Scaffold out the requisite PSSessionConfiguration in order to run the new session in an escalated fashion (and passthrough credentials to things like UNC paths or other sessions).
    # This is a workaround for the "multi-hop" issue present in WinRM, whereby the session will not pass along credentials from the original session to further things needing authentication creds
    Invoke-Command -Session $session -ScriptBlock {
        try
        {
            Get-PSSessionConfiguration -name "EscalatedConfiguration" -ErrorAction Stop
        }
        catch
        {
            Register-PSSessionConfiguration -Name "EscalatedConfiguration" `
                                            -RunAsCredential $using:credentials `
                                            -MaximumReceivedDataSizePerCommandMB 1000 `
                                            -MaximumReceivedObjectSizeMB 1000 `
                                            -Force
        }
    } | Out-Null

    Remove-PSSession $session
}