<#
    .SYNOPSIS
        Displays a localized warning message.

        This helper function is obsolete, should use Write-Warning together with individual resource
        localization strings.
        https://github.com/PowerShell/SqlServerDsc/blob/dev/CONTRIBUTING.md#localization

        Strings in this function has not been localized since this helper function should be removed
        when all resources has moved over to the new localization,

    .PARAMETER WarningType
        String containing the key of the localized warning message.

    .PARAMETER FormatArgs
        Collection of strings to replace format objects in warning message.
#>
function New-WarningMessage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $WarningType,

        [Parameter()]
        [System.String[]]
        $FormatArgs
    )

    ## Attempt to get the string from the localized data
    $warningMessage = $script:localizedData.$WarningType

    ## Ensure there is a message present in the localization file
    if (!$warningMessage)
    {
        $errorParams = @{
            ErrorType     = 'NoKeyFound'
            FormatArgs    = $WarningType
            ErrorCategory = 'InvalidArgument'
            TargetObject  = 'New-WarningMessage'
        }

        ## Raise an error indicating the localization data is not present
        throw New-TerminatingError @errorParams
    }

    ## Apply formatting
    $warningMessage = $warningMessage -f $FormatArgs

    ## Write the message as a warning
    Write-Warning -Message $warningMessage
}