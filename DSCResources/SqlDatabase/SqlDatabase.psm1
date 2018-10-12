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
        New-VerboseMessage -Message "Reversing Database $($databaseObject.Name)"

        [PSCustomObject] @{
            ResourceType = 'SqlDatabase'
            ResourceName = $databaseObject.Name
            DependsOn = $dependencies
            Properties = @{
                Name = $databaseObject.Name
                ServerName = $SMO.ComputerNamePhysicalNetBIOS
                InstanceName = $SMO.InstanceName
                Collation = $databaseObject.Collation
            }
        }
    }
}