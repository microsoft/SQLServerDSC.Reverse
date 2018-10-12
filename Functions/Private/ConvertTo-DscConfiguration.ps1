function ConvertTo-DscConfiguration {
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        $ConfigurationName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        $Nodes
    )

    $output = "Configuration $ConfigurationName {" + [Environment]::NewLine
    $output += $Nodes | ConvertTo-DscNode
    $output += '}' + [Environment]::NewLine

    $output
}