$script:ModuleRoot = $PSScriptRoot

function Import-ModuleFile {
    [CmdletBinding()]
    Param (
        [string]
        $Path
    )

    if ($doDotSource) {
        . $Path
    }
    else {
        try {
            $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create([io.file]::ReadAllText($Path))), $null, $null)
        }
        catch {
            Write-Warning "Failed to import $Path"
        }
    }
}

$script:doDotSource = $false
if ($sqlreversedsc_dotsourcemodule) { $script:doDotSource = $true }

# Import all private functions
foreach ($function in (Get-ChildItem "$ModuleRoot\Functions\Private\*.ps1")) {
    . Import-ModuleFile -Path $function.FullName
}

$script:localizedData = Get-LocalizedData -ResourceName 'SqlServerDsc.Reverse' -ScriptRoot $PSScriptRoot

# Import all public functions
foreach ($function in (Get-ChildItem "$ModuleRoot\Functions\Public\*.ps1")) {
    . Import-ModuleFile -Path $function.FullName
}

