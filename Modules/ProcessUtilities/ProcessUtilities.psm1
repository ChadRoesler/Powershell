<#
 .Synopsis
  Works in a similar vein as Start-Process, but allows more control over output redirection.

 .Description
  Works in a similar vein as Start-Process, but allows more control over output redirection and returns details about the process execution lifecycle.

 .Parameter ProcessPath
  The path to executable to execute.

 .Parameter ArgumentList
  A string denoting process arguments.

 .Parameter WorkingDirectory
  An optional path denoting the working directory, useful for applications that have multiple dependencies that need to be resolved in its root path.

 .Example
  $processResults = Invoke-Process -ProcessPath ping.exe -ArgumentList "localhost"
#>
function Invoke-Process
{
    param(
        [string] $ProcessPath,
        [string] $ArgumentList,
        [string] $WorkingDirectory = $null
    )

    Set-Variable StandardOutputEventName -Option Constant -value "OutputDataReceived"
    Set-Variable StandardErrorEventName -Option Constant -value "ErrorDataReceived"

    if ([string]::IsNullOrEmpty($ProcessPath))
    {
        throw New-Object System.ArgumentException ("ProcessPath has not been specified", "ProcessPath")
    }

    if ([string]::IsNullOrEmpty($ArgumentList))
    {
        throw New-Object System.ArgumentException ("ArgumentList has not been specified", "ArgumentList")
    }

    $processInfo                        = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName               = $ProcessPath
    $processInfo.RedirectStandardError  = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.UseShellExecute        = $false
    $processInfo.CreateNoWindow         = $true
    $processInfo.Arguments              = $ArgumentList

    if (![string]::IsNullOrEmpty($WorkingDirectory))
    {
       $processInfo.WorkingDirectory = $WorkingDirectory
    }

    $process           = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo

    $standardOutput = New-Object -TypeName System.Text.StringBuilder
    $standardError  = New-Object -TypeName System.Text.StringBuilder

    $outputHandler = {
        if (![String]::IsNullOrEmpty($EventArgs.Data))
        {
            $Event.MessageData.AppendLine($EventArgs.Data)
        }
    }

    Write-Log -Message "Registering event handlers..."

    $standardOutputEvent = Register-ObjectEvent -InputObject $process `
                                                -Action $outputHandler `
                                                -EventName $StandardOutputEventName `
                                                -MessageData $standardOutput

    $standardErrorEvent = Register-ObjectEvent -InputObject $process `
                                               -Action $outputHandler `
                                               -EventName $StandardErrorEventName `
                                               -MessageData $standardError

    Write-Log -Message "Started executing $($ProcessPath) with arguments $($ArgumentList)..."

    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    $process.WaitForExit()

    Write-Log -Message "Finished executing $($ProcessPath); unregistering event handlers..."

    Unregister-Event -SourceIdentifier $standardOutputEvent.Name
    Unregister-Event -SourceIdentifier $standardErrorEvent.Name

    return @{
        StandardOutput = $standardOutput.ToString().Trim();
        StandardError = $standardError.ToString().Trim();
        ExitCode = $process.ExitCode
    }
}