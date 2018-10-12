<#
    .SYNOPSIS
        Returns a localized error message.

        This helper function is obsolete, should use new helper functions.
        https://github.com/PowerShell/SqlServerDsc/blob/dev/CONTRIBUTING.md#localization
        https://github.com/PowerShell/SqlServerDsc/blob/dev/DSCResources/CommonResourceHelper.psm1

        Strings in this function has not been localized since this helper function should be removed
        when all resources has moved over to the new localization,

    .PARAMETER ErrorType
        String containing the key of the localized error message.

    .PARAMETER FormatArgs
        Collection of strings to replace format objects in the error message.

    .PARAMETER ErrorCategory
        The category to use for the error message. Default value is 'OperationStopped'.
        Valid values are a value from the enumeration System.Management.Automation.ErrorCategory.

    .PARAMETER TargetObject
        The object that was being operated on when the error occurred.

    .PARAMETER InnerException
        Exception object that was thrown when the error occurred, which will be added to the final error message.
#>
function New-TerminatingError
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorType,

        [Parameter()]
        [System.String[]]
        $FormatArgs,

        [Parameter()]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory = [System.Management.Automation.ErrorCategory]::OperationStopped,

        [Parameter()]
        [System.Object]
        $TargetObject = $null,

        [Parameter()]
        [System.Exception]
        $InnerException = $null
    )

    $errorMessage = $script:localizedData.$ErrorType

    if (!$errorMessage)
    {
        $errorMessage = ($script:localizedData.NoKeyFound -f $ErrorType)

        if (!$errorMessage)
        {
            $errorMessage = ("No Localization key found for key: {0}" -f $ErrorType)
        }
    }

    $errorMessage = ($errorMessage -f $FormatArgs)

    if ( $InnerException )
    {
        $errorMessage += " InnerException: $($InnerException.Message)"
    }

    $callStack = Get-PSCallStack

    # Get Name of calling script
    if ($callStack[1] -and $callStack[1].ScriptName)
    {
        $scriptPath = $callStack[1].ScriptName

        $callingScriptName = $scriptPath.Split('\')[-1].Split('.')[0]

        $errorId = "$callingScriptName.$ErrorType"
    }
    else
    {
        $errorId = $ErrorType
    }

    Write-Verbose -Message "$($script:localizedData.$ErrorType -f $FormatArgs) | ErrorType: $errorId"

    $exception = New-Object -TypeName System.Exception -ArgumentList $errorMessage, $InnerException
    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, $errorId, $ErrorCategory, $TargetObject

    return $errorRecord
}