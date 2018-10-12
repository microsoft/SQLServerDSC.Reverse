function ConvertTo-DscResource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ResourceType,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ResourceName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        $DependsOn,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        $Properties
    )

    process {
        $output = "        $ResourceType '$ResourceName' {" + [Environment]::NewLine

        foreach ($attribute in $Properties.GetEnumerator()) {
            if ($attribute.Value -ne $null) {


                if ($attribute.Value -is [System.Management.Automation.CommandInfo]) {
                    $value = $($attribute.Value.Name)
                }
                elseif ($attribute.Value -is [array]) {
                    Write-Host "array found"

                    $values = @()
                    foreach ($val in $attribute.Value) {
                        $values += "'$val'"
                    }

                    $value = '@(' + ($values -join ', ') + ')'
                }
                else {
                    $value = "'$($attribute.Value)'"
                }

                $output += "            $($attribute.Name) = $value" + [Environment]::NewLine
            }
        }

        if ($DependsOn) {
            $output += [Environment]::NewLine
            $output += "            DependsOn = @(" + [Environment]::NewLine
            foreach ($dependency in $DependsOn) {
                $output += "                '[$($dependency.ResourceType)]$($dependency.Name)'" + [Environment]::NewLine
            }
            $output += "            )" + [Environment]::NewLine
        }

        $output += '        }' + [Environment]::NewLine

        $output
    }
}