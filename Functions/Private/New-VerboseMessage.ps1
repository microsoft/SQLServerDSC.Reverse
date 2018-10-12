<#
    .SYNOPSIS
    Displays a standardized verbose message.

    This helper function is obsolete, should use Write-Verbose together with individual resource
    localization strings.
    https://github.com/PowerShell/SqlServerDsc/blob/dev/CONTRIBUTING.md#localization

    Strings in this function has not been localized since this helper function should be removed
    when all resources has moved over to the new localization,

    .PARAMETER Message
    String containing the key of the localized warning message.
#>
function New-VerboseMessage
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([System.String])]
    Param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Message
    )
    Write-Verbose -Message ((Get-Date -format yyyy-MM-dd_HH-mm-ss) + ": $Message") -Verbose
}