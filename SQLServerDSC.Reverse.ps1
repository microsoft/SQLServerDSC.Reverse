<#PSScriptInfo

.VERSION 1.0.0.0

.GUID c5d39ceb-c4b0-4a22-b98f-22be7688802a

.AUTHOR Nik Charlebois

.COMPANYNAME Microsoft

.EXTERNALMODULEDEPENDENCIES

.TAGS SQLServer,ReverseDSC

.RELEASENOTES

* Initial Release;
#>

#Requires -Modules @{ModuleName="ReverseDSC";ModuleVersion="1.7.3.0"},@{ModuleName="xSQLServer";ModuleVersion="7.1.0.0"}

<# 

.DESCRIPTION 
 Extracts the DSC Configuration of an existing SQL Server environment, allowing you to analyze it or to replicate it.

#> 

param()

<## Script Settings #>
$VerbosePreference = "SilentlyContinue"

<## Scripts Variables #>
$Script:dscConfigContent = ""
$Script:sqlConnectionInfo = $null
$DSCSource = "C:\Program Files\WindowsPowerShell\Modules\xSQLServer\"
$DSCVersion = "7.1.0.0"
$Script:setupAccount = Get-Credential -Message "Setup Account"

try {
    $currentScript = Test-ScriptFileInfo $SCRIPT:MyInvocation.MyCommand.Path
    $Script:version = $currentScript.Version.ToString()
}
catch {
    $Script:version = "N/A"
}
$Script:DSCPath = $DSCSource + $DSCVersion

<## This is the main function for this script. It acts as a call dispatcher, calling the various functions required in the proper order to get 
the full environment's picture. #>
function Orchestrator
{        
    <# Import the ReverseDSC Core Engine #>
    $ReverseDSCModule = "ReverseDSC.Core.psm1"
    $module = (Join-Path -Path $PSScriptRoot -ChildPath $ReverseDSCModule -Resolve -ErrorAction SilentlyContinue)
    if($module -eq $null)
    {
        $module = "ReverseDSC"
    }    
    Import-Module -Name $module -Force

    # Retrieve informaton about the SQL connection to the current server;
    <# Import the SQLServer Helper Module #>
    $SQLHelperModule = "xSQLServerHelper.psm1"
    $module = (Join-Path -Path $DSCSource -ChildPath ($DSCVersion + '\' + $SQLHelperModule) -Resolve -ErrorAction SilentlyContinue)       
    Import-Module -Name $module -Force
    
    $configName = "SQLServer"
    $Script:dscConfigContent += "<# Generated with SQLServer.Reverse " + $script:version + " #>`r`n"   
    $Script:dscConfigContent += "Configuration $configName`r`n"
    $Script:dscConfigContent += "{`r`n"

    Write-Host "Configuring Dependencies..." -BackgroundColor DarkGreen -ForegroundColor White
    Set-Imports

    # Get a list of all SQL Instances on the current server;
    $SQLInstances = Get-SQLInstance -ComputerName $env:COMPUTERNAME

    $Script:dscConfigContent += "    Node $env:COMPUTERNAME`r`n"
    $Script:dscConfigContent += "    {`r`n"
    
    # Loop through all SQL Instances and extract their DSC information;
    foreach($sqlInstance in $SQLInstances)
    {        
        $Script:sqlConnectionInfo = Connect-SQL -SQLServer $env:COMPUTERNAME -SQLInstanceName $sqlInstance.Instance
    
        Write-Host "["$sqlInstance.Instance"] Scanning SQL Server Memory..." -BackgroundColor DarkGreen -ForegroundColor White
        Read-SQLMemory -SQLInstanceName $sqlInstance.Instance

        Write-Host "["$sqlInstance.Instance"] Scanning SQL Server Database(s)..." -BackgroundColor DarkGreen -ForegroundColor White
        Read-SQLDatabase -SQLServer $env:COMPUTERNAME -SQLInstanceName $sqlInstance.Instance

        Write-Host "["$sqlInstance.Instance"] Scanning SQL Server Configuration Option(s)..." -BackgroundColor DarkGreen -ForegroundColor White
        Read-SQLConfiguration -SQLServer $env:COMPUTERNAME -SQLInstanceName $sqlInstance.Instance

        Write-Host "["$sqlInstance.Instance"] Scanning SQL Server Login(s)..." -BackgroundColor DarkGreen -ForegroundColor White
        Read-SQLLogin -SQLServer $env:COMPUTERNAME -SQLInstanceName $sqlInstance.Instance

        Write-Host "["$sqlInstance.Instance"] Scanning SQL Server Maximum Degree of Parallelism..." -BackgroundColor DarkGreen -ForegroundColor White
        Read-SQLMaxDop -SQLServer $env:COMPUTERNAME -SQLInstanceName $sqlInstance.Instance

        Write-Host "["$sqlInstance.Instance"] Scanning SQL Server Network Protocol(s)..." -BackgroundColor DarkGreen -ForegroundColor White
        Read-SQLNetwork -SQLInstanceName $sqlInstance.Instance

        Write-Host "["$sqlInstance.Instance"] Scanning SQL Always On Service..." -BackgroundColor DarkGreen -ForegroundColor White
        Read-SQLAlwaysOnService -SQLInstanceName $sqlInstance.Instance

        Write-Host "["$sqlInstance.Instance"] Scanning SQL Always On Availability Group(s)..." -BackgroundColor DarkGreen -ForegroundColor White
        Read-SQLAlwaysOnAvailabilityGroup -SQLInstanceName $sqlInstance.Instance
    }
    Write-Host "Scanning Requirement(s)..."
    Read-SQLAOGroupEnsure

    Write-Host "["$sqlInstance.Instance"] Configuring Local Configuration Manager (LCM)..." -BackgroundColor DarkGreen -ForegroundColor White
    Set-LCM

    $Script:dscConfigContent += "`r`n    }`r`n"           
    $Script:dscConfigContent += "}`r`n"

    Write-Host "["$sqlInstance.Instance"] Setting Configuration Data..." -BackgroundColor DarkGreen -ForegroundColor White
    Set-ConfigurationData

    $Script:dscConfigContent += "$configName -ConfigurationData `$ConfigData"
}

#region Reverse Functions
function Read-SQLMemory($SQLInstanceName)
{    
    $module = Resolve-Path ($Script:DSCPath + "\DSCResources\MSFT_xSQLServerMemory\MSFT_xSQLServerMemory.psm1")
    Import-Module $module
    $params = Get-DSCFakeParameters -ModulePath $module
    
    # Setting Primary Keys
    $params.SQLInstanceName = $SQLInstanceName
    $params.SQLServer = $env:COMPUTERNAME

    $results = Get-TargetResource @params    

    $Script:dscConfigContent += "        xSQLServerMemory " + [System.Guid]::NewGuid().toString() + "`r`n"
    $Script:dscConfigContent += "        {`r`n"
    $Script:dscConfigContent += Get-DSCBlock -Params $results -ModulePath $module
    $Script:dscConfigContent += "        }`r`n"
}

function Read-SQLAOGroupEnsure()
{    
    $module = Resolve-Path ($Script:DSCPath + "\DSCResources\MSFT_xSQLAOGroupEnsure\MSFT_xSQLAOGroupEnsure.psm1")
    Import-Module $module
    $params = Get-DSCFakeParameters -ModulePath $module
    
    foreach($availabilityGroup in $Script:sqlConnectionInfo.AvailabilityGroups)
    {
        # Setting Primary Keys
        $params.AvailabilityGroupName = $availabilityGroup.Name
        $params.SetupCredential = $Script:setupAccount

        $results = Get-TargetResource @params

        $Script:dscConfigContent += "        xSQLAOGroupEnsure " + [System.Guid]::NewGuid().toString() + "`r`n"
        $Script:dscConfigContent += "        {`r`n"
        $Script:dscConfigContent += Get-DSCBlock -Params $results -ModulePath $module
        $Script:dscConfigContent += "        }`r`n"
    }
}

function Read-SQLAlwaysOnAvailabilityGroup($SQLInstanceName)
{    
    $module = Resolve-Path ($Script:DSCPath + "\DSCResources\MSFT_xSQLServerAlwaysOnAvailabilityGroup\MSFT_xSQLServerAlwaysOnAvailabilityGroup.psm1")
    Import-Module $module
    $params = Get-DSCFakeParameters -ModulePath $module
    
    foreach($availabilityGroup in $Script:sqlConnectionInfo.AvailabilityGroups)
    {
        # Setting Primary Keys
        $params.Name = $availabilityGroup.Name
        $params.SQLServer = $env:COMPUTERNAME
        $params.SQLInstanceName = $SQLInstanceName

        $results = Get-TargetResource @params

        $Script:dscConfigContent += "        xSQLServerAlwaysOnAvailabilityGroup " + [System.Guid]::NewGuid().toString() + "`r`n"
        $Script:dscConfigContent += "        {`r`n"
        $Script:dscConfigContent += Get-DSCBlock -Params $results -ModulePath $module
        $Script:dscConfigContent += "        }`r`n"
    }
}

function Read-SQLAlwaysOnService($SQLInstanceName)
{    
    $module = Resolve-Path ($Script:DSCPath + "\DSCResources\MSFT_xSQLServerAlwaysOnService\MSFT_xSQLServerAlwaysOnService.psm1")
    Import-Module $module
    $params = Get-DSCFakeParameters -ModulePath $module
    
    # Setting Primary Keys
    $params.SQLServer = $env:COMPUTERNAME
    $params.SQLInstanceName = $SQLInstanceName

    $results = Get-TargetResource @params    
    $results.Add("SQLServer", $env:COMPUTERNAME)
    $results.Add("SQLInstanceName", $SQLInstanceName)

    # WA - Get-TargetResource doesn't return the proper values, so we need to work around it;
    if($null -ne $results.Get_Item("IsHadrEnabled"))
    {
        $enabled = $results.Get_Item("IsHadrEnabled")
        if($enabled)
        {
            $results.Add("Ensure", "Present")
        }
        else {
            $results.Add("Ensure", "Absent")
        }
        $results.Remove("IsHadrEnabled")
    }

    $Script:dscConfigContent += "        xSQLServerAlwaysOnService " + [System.Guid]::NewGuid().toString() + "`r`n"
    $Script:dscConfigContent += "        {`r`n"
    $Script:dscConfigContent += Get-DSCBlock -Params $results -ModulePath $module
    $Script:dscConfigContent += "        }`r`n"
}

function Read-SQLConfiguration($SQLServer, $SQLInstanceName)
{    
    $module = Resolve-Path ($Script:DSCPath + "\DSCResources\MSFT_xSQLServerConfiguration\MSFT_xSQLServerConfiguration.psm1")
    Import-Module $module
    $params = Get-DSCFakeParameters -ModulePath $module
    
    # Setting Primary Key SQLInstanceName
    $params.SQLInstanceName = $SQLInstanceName
    $params.SQLServer = $env:COMPUTERNAME

    $options = $Script:sqlConnectionInfo.Configuration.Properties

    foreach($option in $options)
    {
        $params.OptionName = $option.DisplayName
        $results = Get-TargetResource @params

        $Script:dscConfigContent += "        xSQLServerConfiguration " + [System.Guid]::NewGuid().toString() + "`r`n"
        $Script:dscConfigContent += "        {`r`n"
        $Script:dscConfigContent += Get-DSCBlock -Params $results -ModulePath $module
        $Script:dscConfigContent += "        }`r`n"
    }    
}

function Read-SQLDatabase($SQLServer, $SQLInstanceName)
{    
    $module = Resolve-Path ($Script:DSCPath + "\DSCResources\MSFT_xSQLServerDatabase\MSFT_xSQLServerDatabase.psm1")
    Import-Module $module
    $params = Get-DSCFakeParameters -ModulePath $module

    $params.SQLInstanceName = $SQLInstanceName
    $params.SQLServer = $SQLServer

    foreach($database in $Script:sqlConnectionInfo.Databases)
    {
        # Setting Primary Keys
        $params.Name = $database.Name

        $results = Get-TargetResource @params

        $Script:dscConfigContent += "        xSQLServerDatabase " + [System.Guid]::NewGuid().toString() + "`r`n"
        $Script:dscConfigContent += "        {`r`n"
        $Script:dscConfigContent += Get-DSCBlock -Params $results -ModulePath $module
        $Script:dscConfigContent += "        }`r`n"
    }
}

function Read-SQLMaxDop($SQLServer, $SQLInstanceName)
{    
    $module = Resolve-Path ($Script:DSCPath + "\DSCResources\MSFT_xSQLServerMaxDop\MSFT_xSQLServerMaxDop.psm1")
    Import-Module $module
    $params = Get-DSCFakeParameters -ModulePath $module

    $params.SQLInstanceName = $SQLInstanceName
    $params.SQLServer = $SQLServer

    $results = Get-TargetResource @params

    $Script:dscConfigContent += "        xSQLServerMaxDop " + [System.Guid]::NewGuid().toString() + "`r`n"
    $Script:dscConfigContent += "        {`r`n"
    $Script:dscConfigContent += Get-DSCBlock -Params $results -ModulePath $module
    $Script:dscConfigContent += "        }`r`n"
}

function Read-SQLNetwork($SQLInstanceName)
{    
    $module = Resolve-Path ($Script:DSCPath + "\DSCResources\MSFT_xSQLServerNetwork\MSFT_xSQLServerNetwork.psm1")
    Import-Module $module
    $params = Get-DSCFakeParameters -ModulePath $module

    $params.InstanceName = $SQLInstanceName
    $params.ProtocolName = "Tcp"

    $results = Get-TargetResource @params

    $Script:dscConfigContent += "        xSQLServerNetwork " + [System.Guid]::NewGuid().toString() + "`r`n"
    $Script:dscConfigContent += "        {`r`n"
    $Script:dscConfigContent += Get-DSCBlock -Params $results -ModulePath $module
    $Script:dscConfigContent += "        }`r`n"
}

function Read-SQLLogin($SQLServer, $SQLInstanceName)
{    
    $module = Resolve-Path ($Script:DSCPath + "\DSCResources\MSFT_xSQLServerLogin\MSFT_xSQLServerLogin.psm1")
    Import-Module $module
    $params = Get-DSCFakeParameters -ModulePath $module

    $params.SQLInstanceName = $SQLInstanceName
    $params.SQLServer = $SQLServer

    foreach($login in $Script:sqlConnectionInfo.Logins)
    {
        # Setting Primary Keys
        $params.Name = $login.Name

        $results = Get-TargetResource @params

        $Script:dscConfigContent += "        xSQLServerLogin " + [System.Guid]::NewGuid().toString() + "`r`n"
        $Script:dscConfigContent += "        {`r`n"
        $Script:dscConfigContent += Get-DSCBlock -Params $results -ModulePath $module
        $Script:dscConfigContent += "        }`r`n"
    }
}
#endregion

# Sets the DSC Configuration Data for the current server;
function Set-ConfigurationData
{
    $Script:dscConfigContent += "`$ConfigData = @{`r`n"
    $Script:dscConfigContent += "    AllNodes = @(`r`n"    

    $tempConfigDataContent += "    @{`r`n"
    $tempConfigDataContent += "        NodeName = `"$env:COMPUTERNAME`";`r`n"
    $tempConfigDataContent += "        PSDscAllowPlainTextPassword = `$true;`r`n"
    $tempConfigDataContent += "        PSDscAllowDomainUser = `$true;`r`n"
    $tempConfigDataContent += "    }`r`n"    

    $Script:dscConfigContent += $tempConfigDataContent
    $Script:dscConfigContent += ")}`r`n"
}

<## This function ensures all required DSC Modules are properly loaded into the current PowerShell session. #>
function Set-Imports
{
    $Script:dscConfigContent += "    Import-DscResource -ModuleName PSDesiredStateConfiguration`r`n"
    $Script:dscConfigContent += "    Import-DscResource -ModuleName xSQLServer -ModuleVersion `"" + $DSCVersion  + "`"`r`n"
}

<## This function sets the settings for the Local Configuration Manager (LCM) component on the server we will be configuring using our resulting DSC Configuration script. The LCM component is the one responsible for orchestrating all DSC configuration related activities and processes on a server. This method specifies settings telling the LCM to not hesitate rebooting the server we are configurating automatically if it requires a reboot (i.e. During the SharePoint Prerequisites installation). Setting this value helps reduce the amount of manual interaction that is required to automate the configuration of our SharePoint farm using our resulting DSC Configuration script. #>
function Set-LCM
{
    $Script:dscConfigContent += "        LocalConfigurationManager"  + "`r`n"
    $Script:dscConfigContent += "        {`r`n"
    $Script:dscConfigContent += "            RebootNodeIfNeeded = `$True`r`n"
    $Script:dscConfigContent += "        }`r`n"
}

# Retrieves the list of all SQL Instances on the current server;
Function Get-SQLInstance 
{
    [OutputType('SQLServer.Information')]
    [cmdletbinding()] 
    Param(
        [parameter(ValueFromPipeline=$True)]
        [string[]]$Computername = 'G13'
    )
    Process {
        ForEach ($Computer in $Computername) {
            # 1 = MSSQLSERVER
            $Filter = "SELECT * FROM SqlServiceAdvancedProperty WHERE SqlServiceType=1" 
            $WMIParams=@{
                Computername = $Computer
                NameSpace='root\Microsoft\SqlServer'
                Query="SELECT name FROM __NAMESPACE WHERE name LIKE 'ComputerManagement%'"
                Authentication = 'PacketPrivacy'
                ErrorAction = 'Stop'
            }
            Write-Verbose "[$Computer] Starting SQL Scan"
            $PropertyHash = [ordered]@{
                Computername = $Computer
                Instance = $Null
                SqlServer = $Null
                WmiNamespace = $Null
                SQLSTATES = $Null
                VERSION = $Null
                SPLEVEL = $Null
                CLUSTERED = $Null
                INSTALLPATH = $Null
                DATAPATH = $Null
                LANGUAGE = $Null
                FILEVERSION = $Null
                VSNAME = $Null
                REGROOT = $Null
                SKU = $Null
                SKUNAME = $Null
                INSTANCEID = $Null
                STARTUPPARAMETERS = $Null
                ERRORREPORTING = $Null
                DUMPDIR = $Null
                SQMREPORTING = $Null
                ISWOW64 = $Null
                BackupDirectory = $Null
                AlwaysOnName = $Null
            }
            Try {
                Write-Verbose "[$Computer] Performing Registry Query"
                $Registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Computer) 
            }
            Catch {
                Write-Warning "[$Computer] $_"
                Continue
            }
            $baseKeys = "SOFTWARE\\Microsoft\\Microsoft SQL Server",
            "SOFTWARE\\Wow6432Node\\Microsoft\\Microsoft SQL Server"
            Try {
                $ErrorActionPreference = 'Stop'
                If ($Registry.OpenSubKey($basekeys[0])) {
                    $regPath = $basekeys[0]
                } 
                ElseIf ($Registry.OpenSubKey($basekeys[1])) {
                    $regPath = $basekeys[1]
                } 
                Else {
                    Continue
                }
            } 
            Catch {
                Continue
            }
            Finally {
                $ErrorActionPreference = 'Continue'
            }
            $RegKey= $Registry.OpenSubKey("$regPath")
            If ($RegKey.GetSubKeyNames() -contains "Instance Names") {
                $RegKey= $Registry.OpenSubKey("$regpath\\Instance Names\\SQL" ) 
                $instances = @($RegKey.GetValueNames())
            } 
            ElseIf ($regKey.GetValueNames() -contains 'InstalledInstances') {
                $isCluster = $False
                $instances = $RegKey.GetValue('InstalledInstances')
            } 
            Else {
                Continue
            }

            If ($instances.count -gt 0) { 
                ForEach ($Instance in $Instances) {
                    $PropertyHash['Instance']=$Instance
                    $Nodes = New-Object System.Collections.Arraylist
                    $clusterName = $Null
                    $isCluster = $False
                    $instanceValue = $regKey.GetValue($instance)
                    $instanceReg = $Registry.OpenSubKey("$regpath\\$instanceValue")
                    If ($instanceReg.GetSubKeyNames() -contains "Cluster") {
                        $isCluster = $True
                        $instanceRegCluster = $instanceReg.OpenSubKey('Cluster')
                        $clusterName = $instanceRegCluster.GetValue('ClusterName')
                        $clusterReg = $Registry.OpenSubKey("Cluster\\Nodes")                            
                        $clusterReg.GetSubKeyNames() | ForEach {
                            $null = $Nodes.Add($clusterReg.OpenSubKey($_).GetValue('NodeName'))
                        }                    
                    }  
                    $PropertyHash['Nodes'] = $Nodes

                    $instanceRegSetup = $instanceReg.OpenSubKey("Setup")
                    Try {
                        $edition = $instanceRegSetup.GetValue('Edition')
                    } Catch {
                        $edition = $Null
                    }
                    $PropertyHash['Skuname'] = $edition
                    Try {
                        $ErrorActionPreference = 'Stop'
                        #Get from filename to determine version
                        $servicesReg = $Registry.OpenSubKey("SYSTEM\\CurrentControlSet\\Services")
                        $serviceKey = $servicesReg.GetSubKeyNames() | Where {
                            $_ -match "$instance"
                        } | Select -First 1
                        $service = $servicesReg.OpenSubKey($serviceKey).GetValue('ImagePath')
                        $file = $service -replace '^.*(\w:\\.*\\sqlservr.exe).*','$1'
                        $PropertyHash['version'] =(Get-Item ("\\$Computer\$($file -replace ":","$")")).VersionInfo.ProductVersion
                    } Catch {
                        #Use potentially less accurate version from registry
                        $PropertyHash['Version'] = $instanceRegSetup.GetValue('Version')
                    } Finally {
                        $ErrorActionPreference = 'Continue'
                    }

                    Try {
                        Write-Verbose "[$Computer] Performing WMI Query"
                        $Namespace = $Namespace = (Get-WMIObject @WMIParams | Sort-Object -Descending | Select-Object -First 1).Name
                        If ($Namespace) {
                            $PropertyHash['WMINamespace'] = $Namespace
                            $WMIParams.NameSpace="root\Microsoft\SqlServer\$Namespace"
                            $WMIParams.Query=$Filter

                            $WMIResults = Get-WMIObject @WMIParams 
                            $GroupResults = $WMIResults | Group ServiceName
                            $PropertyHash['Instance'] = $GroupResults.Name
                            $WMIResults | ForEach {
                                $Name = "{0}{1}" -f ($_.PropertyName.SubString(0,1),$_.PropertyName.SubString(1).ToLower())    
                                $Data = If ($_.PropertyStrValue) {
                                    $_.PropertyStrValue
                                }
                                Else {
                                    If ($Name -match 'Clustered|ErrorReporting|SqmReporting|IsWow64') {
                                        [bool]$_.PropertyNumValue
                                    }
                                    Else {
                                        $_.PropertyNumValue
                                    }        
                                }
                                $PropertyHash[$Name] = $Data
                            }

                            #region Always on availability group
                            if ($PropertyHash['Version'].Major -ge 11) {                                          
                                $splat.Query="SELECT WindowsFailoverClusterName FROM HADRServiceSettings WHERE InstanceName = '$($Group.Name)'"
                                $PropertyHash['AlwaysOnName'] = (Get-WmiObject @WMIParams).WindowsFailoverClusterName
                                if ($PropertyHash['AlwaysOnName']) {
                                    $PropertyHash.SqlServer = $PropertyHash['AlwaysOnName']
                                }
                            } 
                            else {
                                $PropertyHash['AlwaysOnName'] = $null
                            }  
                            #endregion Always on availability group

                            #region Backup Directory
                            $RegKey=$Registry.OpenSubKey("$($PropertyHash['RegRoot'])\MSSQLServer")
                            $PropertyHash['BackupDirectory'] = $RegKey.GetValue('BackupDirectory')
                            #endregion Backup Directory
                        }#IF NAMESPACE
                    }
                    Catch {
                    }
                    #region Caption
                    $Caption = {Switch -Regex ($PropertyHash['version']) {
                        "^13" {'SQL Server 2016';Break}
                        "^12" {'SQL Server 2014';Break}
                        "^11" {'SQL Server 2012';Break}
                        "^10\.5" {'SQL Server 2008 R2';Break}
                        "^10" {'SQL Server 2008';Break}
                        "^9"  {'SQL Server 2005';Break}
                        "^8"  {'SQL Server 2000';Break}
                        Default {'Unknown'}
                    }}.InvokeReturnAsIs()
                    $PropertyHash['Caption'] = $Caption
                    #endregion Caption

                    #region Full SQL Name
                    $Name = If ($clusterName) {
                        $clusterName
                        $PropertyHash['SqlServer'] = $clusterName
                    }
                    Else {
                        $Computer
                        $PropertyHash['SqlServer'] = $Computer
                    }
                    $PropertyHash['FullName'] = ("{0}\{1}" -f $Name,$PropertyHash['Instance'])
                    #emdregion Full SQL Name                        
                    $Object = [pscustomobject]$PropertyHash
                    $Object.pstypenames.insert(0,'SQLServer.Information')
                    $Object
                }#FOREACH INSTANCE                 
            }#IF
        }
    }
}

<# This function is responsible for saving the output file onto disk. #>
function Get-ReverseDSC()
{
    <## Call into our main function that is responsible for extracting all the information about our SharePoint farm. #>
    Orchestrator

    <## Prompts the user to specify the FOLDER path where the resulting PowerShell DSC Configuration Script will be saved. #>
    $fileName = "SQLServer.DSC.ps1"
    $OutputDSCPath = Read-Host "Please enter the full path of the output folder for DSC Configuration (will be created as necessary)"
    
    <## Ensures the specified output folder path actually exists; if not, tries to create it and throws an exception if we can't. ##>
    while (!(Test-Path -Path $OutputDSCPath -PathType Container -ErrorAction SilentlyContinue))
    {
        try
        {
            Write-Output "Directory `"$OutputDSCPath`" doesn't exist; creating..."
            New-Item -Path $OutputDSCPath -ItemType Directory | Out-Null
            if ($?) {break}
        }
        catch
        {
            Write-Warning "$($_.Exception.Message)"
            Write-Warning "Could not create folder $OutputDSCPath!"
        }
        $OutputDSCPath = Read-Host "Please Enter Output Folder for DSC Configuration (Will be Created as Necessary)"
    }
    <## Ensures the path we specify ends with a Slash, in order to make sure the resulting file path is properly structured. #>
    if(!$OutputDSCPath.EndsWith("\") -and !$OutputDSCPath.EndsWith("/"))
    {
        $OutputDSCPath += "\"
    }

    <## Save the content of the resulting DSC Configuration file into a file at the specified path. #>
    $outputDSCFile = $OutputDSCPath + $fileName
    $Script:dscConfigContent | Out-File $outputDSCFile
    Write-Output "Done."
    <## Wait a couple of seconds, then open our $outputDSCPath in Windows Explorer so we can review the glorious output. ##>
    Start-Sleep 2
    Invoke-Item -Path $OutputDSCPath
}

Get-ReverseDSC