<#
 .Synopsis
  Writes a log message to the console.

 .Description
  Writes a log message to the console with an appropriately formed header to indicate its script, function and timestamp.

 .Parameter message
  The log message to write.
#>
function Write-Log()
{
    param
    (
        [System.Object] $message,
        [string] $logFileLocation = $null
    )

    $logHeader = Format-LogHeader -caller $((Get-PSCallStack)[1])
    $message = "$logHeader $($message)"
    if($logFileLocation -ne $null -and $logFileLocation -ne "")
    {
        Write-ToFile -Message $message -FileLocation $logFileLocation
    }
    Write-Host $message
}

<#
 .Synopsis
  Writes an error message to the console.

 .Description
  Writes an error message to the console with an appropriately formed header to indicate its script, function and timestamp.

 .Parameter message
  The log message to write.
#>
function Write-ErrorLog()
{
    param(
        [System.Object] $message,
        [string] $logFileLocation  = ""
    )
    $logHeader = Format-LogHeader -caller $((Get-PSCallStack)[1])
    $message = "$logHeader [ERROR] $($message)"
    if($logFileLocation -ne $null -and $logFileLocation -ne "")
    {
        Write-ToFile -Message $message -FileLocation $logFileLocation
    }
    Write-Error $message
}

<#
 .Synopsis
  Writes a warning message to the console.

 .Description
  Writes a warning message to the console with an appropriately formed header to indicate its script, function and timestamp.

 .Parameter message
  The log message to write.
#>
function Write-WarningLog()
{
    param(
        [System.Object] $message,
        [string] $logFileLocation  = ""
    )
    $logHeader = Format-LogHeader -caller $((Get-PSCallStack)[1])
    $message = "$logHeader [WARNING] $($message)"
    if($logFileLocation -ne $null -and $logFileLocation -ne "")
    {
        Write-ToFile -Message $message -FileLocation $logFileLocation
    }
    Write-Warning $message
}

<#
 .Synopsis
  Formats a caller object into an expected format

 .Description
  Formats a caller object into an expected format

 .Parameter caller
  The calling function (usually pulled from the PSCallStack)
#>
function Format-CallerObject()
{
    param
    (
        [System.Object] $caller
    )

    $script = (Get-ChildItem $caller.ScriptName -ErrorVariable error -ErrorAction SilentlyContinue)
    $lineNumber = 1
    $scriptFile = "<No file>"

    if ($error.Count -eq 0 -and $null -ne $caller.ScriptName)
    {
        $scriptFile = $script.BaseName
        $lineNumber = $($caller.ScriptLineNumber)
    }

    $functionName = $caller.FunctionName

    return [PSCustomObject] @{
        "ScriptFile" = $scriptFile;
        "LineNumber" = $lineNumber;
        "FunctionName" = $functionName
    }
}

<#
 .Synopsis
  Formats the header for a log line.

 .Description
  Formats the header for a log line with the following format "[Date][Calling Function's File][Calling Function] Log Message"

 .Parameter caller
  The calling function (usually pulled from the PSCallStack)
#>
function Format-LogHeader()
{
    param
    (
        [System.Object] $caller
    )

    Set-Variable -Name LogHeaderFormat -Option Constant -Value "[{0}][{1}:{2}][{3}]"

    $formattedCallerObject = Format-CallerObject -caller $caller

    $logHeader = ($LogHeaderFormat -f (Format-LogDate), `
                                      $formattedCallerObject.ScriptFile, `
                                      $formattedCallerObject.LineNumber, `
                                      $formattedCallerObject.FunctionName)

    return $logHeader
}

<#
 .Synopsis
  Formats an Application Name to be specified as part of the connection

 .Description
  Formats an Application Name to be specified as part of the connection with the following format "[Calling Function's File][Calling Function] Log Message"

 .Parameter caller
  The calling function (usually pulled from the PSCallStack)
#>
function Format-ConnectionName()
{
    param
    (
        [System.Object] $caller
    )

    Set-Variable -Name ConnectionNameFormat -Option Constant -Value "[{0}:{1}][{2}]"

    $formattedCallerObject = Format-CallerObject -caller $caller

    $connectionName = ($ConnectionNameFormat -f $formattedCallerObject.ScriptFile, `
                                                $formattedCallerObject.LineNumber, `
                                                $formattedCallerObject.FunctionName)

    return $connectionName
}

<#
 .Synopsis
  Formats the date for a log line.

 .Description
  Formats the date for a log line (e.g. 07.15.2015 21:01:15.012156)

 .Parameter caller
  The calling function (usually pulled from the PSCallStack)
#>
function Format-LogDate()
{
    return $(get-date -Format 'MM.dd.yyyy HH:mm:ss.ffffff')
}

<#
 .Synopsis
  Creates a new ScriptBlock for the purposes of passing the dependency along to new remote PSSessions.

 .Description
  Creates a new ScriptBlock for the purposes of passing the dependency along to new remote PSSessions.
#>
function New-LoggingScriptBlock()
{
    $writeLogDefinition = "function Write-Log { ${function:Write-Log} }".Replace("$", "``$")
    $writeWarningLogDefinition = "function Write-WarningLog { ${function:Write-WarningLog} }".Replace("$", "``$")
    $writeErrorLogDefinition = "function Write-ErrorLog { ${function:Write-ErrorLog} }".Replace("$", "``$")
    $formatLogHeaderDefinition = "function Format-LogHeader { ${function:Format-LogHeader} }".Replace("$", "``$")
    $formatCallerObjectDefinition = "function Format-CallerObject { ${function:Format-CallerObject} }".Replace("$", "``$")
    $formatLogDateDefinition = "function Format-LogDate { ${function:Format-LogDate} }".Replace("$", "``$")
    $writeToFileDefinition = "function Write-ToFile { ${function:Write-ToFile} }".Replace("$", "``$")

    return ". ([ScriptBlock]::Create(@""
    $($formatLogDateDefinition);$($formatCallerObjectDefinition);$($formatLogHeaderDefinition);$($writeLogDefinition);$($writeWarningLogDefinition);$($writeErrorLogDefinition);$($writeToFileDefinition)
""@))"
}

<#
 .Synopsis
  Coalesces error output from a user-defined array of errors

 .Description
    Coalesces error output from a user-defined array of errors; generally used to coalesce error output at the end of some method lifecycle without relying upon the global $Error array.

 .Parameter Errors
  A collection of structured error objects in the form of:
    {
        "Type" = "Type of error";
        "Fields" = @{"variableName" = "value"}; -- Any state of relevance at the time of execution
        "Message" = "Stack traces or any other diagnostic information produced by the code being executed"
        "ExceptionContext" = An optional [System.Management.Automation.ErrorRecord]
    }
#>


function Assert-ErrorHandling
{
    param
    (
        [array] $Errors,
        [string] $logFileLocation  = "",
        [string] $ErrorPreference = "Stop"
    )

    Set-Variable ErrorStringFormat -Option Constant -Value "The following data was captured as part of the error handling: $([System.Environment]::NewLine) {0}"
    Set-Variable ErrorStringMessageFormat -Option Constant -Value @"
Error Type:
{0}
-----------------------
Fields:
{1}
-----------------------
Message:
{2}
-----------------------
Context:
{3}
-----------------------
$([System.Environment]::NewLine)
"@
    Set-Variable FieldStringFormat -Option Constant -Value "Variable: {0}, Value: {1} $([System.Environment]::NewLine)"
    Set-Variable ExceptionContextFormat -Option Constant -Value "{0}({1}): {2}"
    Set-Variable ExceptionContextDefault -Option Constant -Value "No valid ExceptionContext specified"

    $coalescedErrorOutput = ""

    if ($Errors.Count -gt 0)
    {
        foreach($error in $Errors)
        {
            <# Build a formatted field string #>
            $fields = ""
            $context = $ExceptionContextDefault

            if ($error.Fields -is [Hashtable])
            {
                foreach ($field in $error.Fields.GetEnumerator())
                {
                    $fields += $FieldStringFormat -f $field.Name, $field.Value
                }
            }

            if ($null -ne $error.ExceptionContext -and $error.ExceptionContext -is [System.Management.Automation.ErrorRecord])
            {
                $context = $ExceptionContextFormat -f $error.ExceptionContext.InvocationInfo.ScriptName, $error.ExceptionContext.InvocationInfo.ScriptLineNumber, $error.ExceptionContext.InvocationInfo.Line
            }

            $coalescedErrorOutput += $ErrorStringMessageFormat -f $error.Type, $fields, $error.Message, $context
        }

        if ($coalescedErrorOutput.Length -gt 0)
        {
            $ErrorActionPreference = $ErrorPreference
            $ErrorView = "CategoryView"
            if($logFileLocation -ne $null -and $logFileLocation -ne "")
            {
                Write-ToFile -message ($ErrorStringFormat -f $coalescedErrorOutput) -FileLocation $logFileLocation
            }
            Write-Error ($ErrorStringFormat -f $coalescedErrorOutput)
        }
    }
}


function Assert-WarningHandling
{
    param
    (
        [array] $Warnings,
        [string] $logFileLocation  = ""
    )

    Set-Variable WarningStringFormat -Option Constant -Value "The following data was captured as part of the warning handling: $([System.Environment]::NewLine) {0}"
    Set-Variable WarningStringMessageFormat -Option Constant -Value @"
Warning Type:
{0}
-----------------------
Fields:
{1}
-----------------------
Message:
{2}
-----------------------
Context:
{3}
-----------------------
$([System.Environment]::NewLine)
"@
    Set-Variable FieldStringFormat -Option Constant -Value "Variable: {0}, Value: {1} $([System.Environment]::NewLine)"
    Set-Variable ExceptionContextFormat -Option Constant -Value "{0}({1}): {2}"
    Set-Variable ExceptionContextDefault -Option Constant -Value "No valid ExceptionContext specified"

    $coalescedWarningOutput = ""

    if ($Warning.Count -gt 0)
    {
        foreach($warning in $Warnings)
        {
            <# Build a formatted field string #>
            $fields = ""
            $context = $ExceptionContextDefault

            if ($warning.Fields -is [Hashtable])
            {
                foreach ($field in $warning.Fields.GetEnumerator())
                {
                    $fields += $FieldStringFormat -f $field.Name, $field.Value
                }
            }

            if ($null -ne $warning.ExceptionContext -and $warning.ExceptionContext -is [System.Management.Automation.WarningRecord])
            {
                $context = $ExceptionContextFormat -f $warning.ExceptionContext.InvocationInfo.ScriptName, $warning.ExceptionContext.InvocationInfo.ScriptLineNumber, $warning.ExceptionContext.InvocationInfo.Line
            }

            $coalescedWarningOutput += $WarningStringMessageFormat -f $warning.Type, $fields, $warning.Message, $context
        }

        if ($coalescedWarningOutput.Length -gt 0)
        {
            if($null -ne $logFileLocation -and $logFileLocation -ne "")
            {
                Write-ToFile -message ($ErrorStringFormat -f $coalescedErrorOutput) -FileLocation $logFileLocation
            }
            Write-Warning ($WarningStringFormat -f $coalescedWarningOutput)
        }
    }
}

function Write-ToFile
{
    param (
        [string] $message,
        [string] $fileLocation,
        [int] $mutexWaitTimeout = 10000,
        [bool] $append = $true
    )

    $mutexName = $fileLocation.Replace("\","")
    $fileMutex = New-Object System.Threading.Mutex($false, $mutexName)
    $fileMutex.WaitOne($mutexWaitTimeout) | Out-Null
    if(!(Test-Path $fileLocation))
    {
        New-Item -Path $fileLocation -ItemType "file" -Force | Out-Null
    }
    if($append)
    {
        $message | Out-File $fileLocation -Append
    }
    else
    {
        $message | Out-File $fileLocation
    }
    $fileMutex.ReleaseMutex();
}