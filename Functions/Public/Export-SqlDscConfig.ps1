<#
    .SYNOPSIS
        Extracts the DSC Configuration of an existing SQL Server environment.

    .DESCRIPTION
        Extracts the DSC Configuration of an existing SQL Server environment, allowing you to analyze it or to replicate it.

    .PARAMETER SQLServer
        String containing the host name of the SQL Server to connect to.

    .PARAMETER SQLInstanceName
        String containing the SQL Server Database Engine instance to connect to.

    .PARAMETER Credential
        PSCredential object with the credentials to use to impersonate a user when connecting.
        If this is not provided then the current user will be used to connect to the SQL Server Database Engine instance.

    .PARAMETER LoginType
        If the Credential is set, specify with this parameter, which type
        of credentials are set: Native SQL login or Windows user Login. Default
        value is 'WindowsUser'.

    .PARAMETER Path
        Path to output the configuration to. If not specified, the configuration will be returned as a string.

    .EXAMPLE
        PS C:\>Export-SqlDscConfig -SQLServer localhost -Path '.\localhost.ps1'
#>
function Export-SqlDscConfig {
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $SQLServer = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $SQLInstanceName = 'MSSQLSERVER',

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [ValidateSet('WindowsUser', 'SqlLogin')]
        [System.String]
        $LoginType = 'WindowsUser',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        $Path
    )

    $sqlServerObject = Connect-SQL `
        -SQLServer $SQLServer `
        -SQLInstanceName $SQLInstanceName `
        -SetupCredential $Credential `
        -LoginType $LoginType

    if ($sqlServerObject) {
        $resourceObjects = @()

        $resources = Get-ChildItem -Path (Join-Path -Path $script:ModuleRoot -ChildPath 'DSCResources') | Where-Object { $_.Name -ne 'Disabled' }
        foreach ($resource in $resources) {
            Import-Module -FullyQualifiedName $resource.FullName -Force
            Write-Host "Imported $($resource.FullName)"

            $resourceObjects += Get-ResourceDefinition -SMO $sqlServerObject #| ConvertTo-DscResource
        }

        # create the node
        $nodeObjects = @()
        $nodeObjects += [PSCustomObject] @{
            NodeName = "$($SQLServer)_$($SQLInstanceName)"
            Resources = $resourceObjects
        }

        # create the configuration
        $configObjects = @()
        $configObjects += [PSCustomObject] @{
            ConfigurationName = "$($SQLServer)_$($SQLInstanceName)"
            Nodes = $nodeObjects
        }

        $config = $configObjects | ConvertTo-DscConfiguration

        if ($Path) {
            Out-File -FilePath $Path -InputObject $config
        }
        else {
            $config
        }
    }
}