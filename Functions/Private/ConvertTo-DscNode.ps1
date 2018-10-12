function ConvertTo-DscNode {
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        $NodeName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        $Resources
    )

    $output = "    Node $NodeName {" + [Environment]::NewLine
    $output += $Resources | ConvertTo-DscResource
    $output += '    }' + [Environment]::NewLine

    $output
}