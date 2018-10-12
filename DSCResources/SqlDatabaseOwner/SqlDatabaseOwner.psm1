function Get-ResourceDefinition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SqlServer.Management.Smo.Server]
        $SMO
    )

    $dependencies = @(
        @{ ResourceType = 'SqlSetup'; Name = $smo.ComputerNamePhysicalNetBIOS }
    )

    $databases = $SMO.Databases | Where-Object { $_.IsAccessible -eq $true -and $_.IsSystemObject -eq $false }
    foreach ($databaseObject in $databases) {
        New-VerboseMessage -Message "Reversing Database Owner for $($databaseObject.Name)"

        [PSCustomObject] @{
            ResourceType = 'SqlDatabaseOwner'
            ResourceName = $databaseObject.Name
            DependsOn = $dependencies + @{ ResourceType = 'SqlDatabase'; Name = $databaseObject.Name }
            Properties = @{
                ServerName = $SMO.ComputerNamePhysicalNetBIOS
                InstanceName = $SMO.InstanceName
                Database = $databaseObject.Name
                Name = $databaseObject.Owner
            }
        }
    }
}