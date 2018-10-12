<#
    .SYNOPSIS
        Imports the module SQLPS in a standardized way.

    .PARAMETER Force
        Forces the removal of the previous SQL module, to load the same or newer
        version fresh.
        This is meant to make sure the newest version is used, with the latest
        assemblies.

#>
function Import-SQLPSModule
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [Switch]
        $Force
    )

    if ($Force.IsPresent)
    {
        Write-Verbose -Message $script:localizedData.ModuleForceRemoval -Verbose
        Remove-Module -Name @('SqlServer','SQLPS','SQLASCmdlets') -Force -ErrorAction SilentlyContinue
    }

    <#
        Check if either of the modules are already loaded into the session.
        Prefer to use the first one (in order found).
        NOTE: There should actually only be either SqlServer or SQLPS loaded,
        otherwise there can be problems with wrong assemblies being loaded.
    #>
    $loadedModuleName = (Get-Module -Name @('SqlServer', 'SQLPS') | Select-Object -First 1).Name
    if ($loadedModuleName)
    {
        Write-Verbose -Message ($script:localizedData.PowerShellModuleAlreadyImported -f $loadedModuleName) -Verbose
        return
    }

    $availableModuleName = $null

    # Get the newest SqlServer module if more than one exist
    $availableModule = Get-Module -FullyQualifiedName 'SqlServer' -ListAvailable |
        Sort-Object -Property 'Version' -Descending |
        Select-Object -First 1 -Property Name, Path, Version

    if ($availableModule)
    {
        $availableModuleName = $availableModule.Name
        Write-Verbose -Message ($script:localizedData.PreferredModuleFound) -Verbose
    }
    else
    {
        Write-Verbose -Message ($script:localizedData.PreferredModuleNotFound) -Verbose

        <#
            After installing SQL Server the current PowerShell session doesn't know about the new path
            that was added for the SQLPS module.
            This reloads PowerShell session environment variable PSModulePath to make sure it contains
            all paths.
        #>
        $env:PSModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')

        <#
            Get the newest SQLPS module if more than one exist.
        #>
        $availableModule = Get-Module -FullyQualifiedName 'SQLPS' -ListAvailable |
            Select-Object -Property Name, Path, @{
                Name = 'Version'
                Expression = {
                    # Parse the build version number '120', '130' from the Path.
                    (Select-String -InputObject $_.Path -Pattern '\\([0-9]{3})\\' -List).Matches.Groups[1].Value
                }
            } |
            Sort-Object -Property 'Version' -Descending |
            Select-Object -First 1

        if ($availableModule)
        {
            # This sets $availableModuleName to the Path of the module to be loaded.
            $availableModuleName = Split-Path -Path $availableModule.Path -Parent
        }
    }

    if ($availableModuleName)
    {
        try
        {
            Write-Debug -Message ($script:localizedData.DebugMessagePushingLocation)
            Push-Location

            <#
                SQLPS has unapproved verbs, disable checking to ignore Warnings.
                Suppressing verbose so all cmdlet is not listed.
            #>
            $importedModule = Import-Module -Name $availableModuleName -DisableNameChecking -Verbose:$false -Force:$Force -PassThru -ErrorAction Stop

            <#
                SQLPS returns two entries, one with module type 'Script' and another with module type 'Manifest'.
                Only return the object with module type 'Manifest'.
                SqlServer only returns one object (of module type 'Script'), so no need to do anything for SqlServer module.
            #>
            if ($availableModuleName -ne 'SqlServer')
            {
                $importedModule = $importedModule | Where-Object -Property 'ModuleType' -EQ -Value 'Manifest'
            }

            Write-Verbose -Message ($script:localizedData.ImportedPowerShellModule -f $importedModule.Name, $importedModule.Version, $importedModule.Path) -Verbose
        }
        catch
        {
            $errorMessage = $script:localizedData.FailedToImportPowerShellSqlModule -f $availableModuleName
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
        finally
        {
            Write-Debug -Message ($script:localizedData.DebugMessagePoppingLocation)
            Pop-Location
        }
    }
    else
    {
        $errorMessage = $script:localizedData.PowerShellSqlModuleNotFound
        New-InvalidOperationException -Message $errorMessage
    }
}