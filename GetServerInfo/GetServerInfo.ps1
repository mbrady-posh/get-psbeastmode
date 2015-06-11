#TODO: Make sure to keep some type of backup or history

[CmdletBinding()]
    Param(
        [Parameter(ParameterSetName='Individual',Mandatory=$True,Position=0)]
            [string]$Computer,
        [Parameter(ParameterSetName='byOU',Mandatory=$True,Position=0)]
            [string]$BaseOU,
        [Parameter(Mandatory=$True,Position=1)][string]$OutputFolder = "$($env:userprofile)\desktop"
        )
    
    $ScriptPath = Split-Path $MyInvocation.MyCommand.Path
    $ScriptParentPath = Split-Path (Split-Path $MyInvocation.MyCommand.Path)

    . "$ScriptParentPath\Write-PStoHTML\Write-PStoHTML.ps1"

    $Global:OriginalEAP = $ErrorActionPreference

    $Global:OriginalPath = Get-Location

    Function RetrieveServerInfo() {

        #region before contacting

        $HTMLFile = $(If (!(Test-Path "$($OutputFolder)\$($computer).html")) { Copy-Item "$ScriptPath\GetServerInfo.html" "$($OutputFolder)\$($computer).html" ; Write-Output "$($OutputFolder)\$($computer).html" } Else { Move-Item "$($OutputFolder)\$($computer).html" "$($OutputFolder)\$($computer).html.bak" ; Copy-Item "$ScriptPath\GetServerInfo.html" "$($OutputFolder)\$($computer).html" ; Write-Output "$($OutputFolder)\$($computer).html"})

        Write-StringtoHTML "Header" "$($Computer.ToUpper())" $HTMLFile
       
        #$ServerOU = ((Get-ADComputer -Identity "$Computer" -Properties distinguishedName).distinguishedname).Split(",") ; $ServerOU = $ServerOU[1..($ServerOU.Length)] -Join ","
        $RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://RootDSE")
            $Domain = $RootDSE.DefaultNamingContext
            $DomainRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Domain")
            $ADSearcher = New-Object System.DirectoryServices.DirectorySearcher($DomainRoot)
            $ADSearcher.Filter = "(&(objectClass=Computer)(name=$Computer))"
            $ComputerResult = $ADSearcher.FindOne()
            [System.String]$ServerOU = ($ComputerResult.properties.distinguishedname) ; $ServerOU = ($ServerOU.Split(",") | Where-Object {$_ -notlike "CN=*"}) -Join ","
        Write-StringtoHTML "ServerOU" "$ServerOU" $HTMLFile

        #endregion

        #region GetSoftware

        $SoftwareKeys = (Get-ChildItem -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") + (Get-ChildItem -Path "HKLM:\Software\WOW6432node\Microsoft\Windows\CurrentVersion\Uninstall")
            $Software = Foreach ($Key in $SoftwareKeys) {
                            Set-Location "HKLM:\"
                            Try {
                                $ErrorActionPreference = "Stop"
                                (Get-ItemProperty -Path $Key -Name "DisplayName").DisplayName
                                Write-Output "`r`n"
                                }
                                Catch {
                                    #Do nothing
                                    }
                                Finally {
                                    $ErrorActionPreference = $Global:OriginalEAP
                                    }
                            }
            Set-Location $Global:OriginalPath

            Write-ListtoHTML "Software" "Installed Software" "$Software" $HTMLFile

        #endregion

        #region GetRoles

        $Roles = If ((Get-Module -ListAvailable) -like "*ServerManager*") {
            Import-Module "ServerManager"
            Get-WindowsFeature | Where-Object {$_.Installed -eq "True"} | Sort-Object -Property DisplayName| Foreach-Object {$_.DisplayName ; Write-Output "`r`n"}
            }
            Write-ListtoHTML "Roles" "Installed Server Roles" "$Roles" $HTMLFile

        #IIS

        $IISApplications = If ((Get-Module -ListAvailable) -like "*WebAdministration*") {
            Import-Module "WebAdministration"
            Get-Webapplication | Foreach-Object { $_.Path.Trim("/") ; Write-Output "`r`n" }
            }
            Write-ListtoHTML "IIS" "IIS Applications" "$IISApplications" $HTMLFile

        #SQL

        $SQLPSKey="HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps"
        If ((Get-Module -ListAvailable) -like "*SQLPS*") {
            Import-Module "SQLPS" -DisableNameChecking
            Set-Location $OriginalPath
            $SQL = New-Object -TypeName ('Microsoft.SqlServer.Management.Smo.Server') -ArgumentList "localhost"
            $SQLInstances = Get-ChildItem -Path "SQLServer:\SQL\$env:COMPUTERNAME" | ForEach-Object { $_.DisplayName }
            $SQLObjects = Foreach ($SQLInstance in $SQLInstances) {
                $SQLprops = @{}
                $DatabaseList = Get-ChildItem -Path "SQLServer:\SQL\$env:COMPUTERNAME\$SQLInstance\Databases" | ForEach-Object { $_.DisplayName }
                $SQLprops.Add("Databases",$DatabaseList)
                $SQLprops.Add("Name","$SqlInstance")
                New-Object PSObject -Property $SQLprops
                }
            }
            ElseIf (Test-Path $SQLPSKey -ErrorAction SilentlyContinue) {
                $SQLKey = Get-ItemProperty $SQLPSKey
                $SQLPSPath = [System.IO.Path]::GetDirectoryName($SQLKey.Path)
                Set-Location $SQLPSPath
                Add-PSSnapin SqlServerCmdletSnapin100
                Add-PSSnapin SqlServerProviderSnapin100
                $AssemblyList = 
                    "Microsoft.SqlServer.Management.Common",
                    "Microsoft.SqlServer.Smo",
                    "Microsoft.SqlServer.Dmf ",
                    "Microsoft.SqlServer.Instapi ",
                    "Microsoft.SqlServer.SqlWmiManagement ",
                    "Microsoft.SqlServer.ConnectionInfo ",
                    "Microsoft.SqlServer.SmoExtended ",
                    "Microsoft.SqlServer.SqlTDiagM ",
                    "Microsoft.SqlServer.SString ",
                    "Microsoft.SqlServer.Management.RegisteredServers ",
                    "Microsoft.SqlServer.Management.Sdk.Sfc ",
                    "Microsoft.SqlServer.SqlEnum ",
                    "Microsoft.SqlServer.RegSvrEnum ",
                    "Microsoft.SqlServer.WmiEnum ",
                    "Microsoft.SqlServer.ServiceBrokerEnum ",
                    "Microsoft.SqlServer.ConnectionInfoExtended ",
                    "Microsoft.SqlServer.Management.Collector ",
                    "Microsoft.SqlServer.Management.CollectorEnum",
                    "Microsoft.SqlServer.Management.Dac",
                    "Microsoft.SqlServer.Management.DacEnum",
                    "Microsoft.SqlServer.Management.Utility"


                Foreach ($asm in $AssemblyList) {
                    $asm = [Reflection.Assembly]::LoadWithPartialName($asm)
                    }

                Set-Variable -scope Global -name SqlServerMaximumChildItems -Value 0
                Set-Variable -scope Global -name SqlServerConnectionTimeout -Value 30
                Set-Variable -scope Global -name SqlServerIncludeSystemObjects -Value $false
                Set-Variable -scope Global -name SqlServerMaximumTabCompletion -Value 1000

                $SQL = New-Object -TypeName ('Microsoft.SqlServer.Management.Smo.Server') -ArgumentList "localhost"
                $SQLInstances = Get-ChildItem -Path "SQLServer:\SQL\$env:COMPUTERNAME" | ForEach-Object { $_.DisplayName }
                $SQLObjects = Foreach ($SQLInstance in $SQLInstances) {
                    $SQLprops = @{}
                    $DatabaseList = Get-ChildItem -Path "SQLServer:\SQL\$env:COMPUTERNAME\$SQLInstance\Databases" | ForEach-Object { $_.DisplayName }
                    $SQLprops.Add("Databases",$DatabaseList)
                    $SQLprops.Add("Name","$SqlInstance")
                    New-Object PSObject -Property $SQLprops
                    }
                }
            Write-ListtoHTMLfromObject "SQL" "SQL" $SQLObjects $HTMLFile

        #Hyper-V

        $VMs = If ((Get-Module -ListAvailable) -like "*Hyper-V*") {
            Import-Module "Hyper-V"
            Foreach ($VM in $(Get-VM | Where-Object { $_.State -eq "Running" })) {
                $VM.Name
                Write-Output "`r`n"
                }
            }
            Write-ListtoHTML "Hyper-V" "Virtual Machines" "$VMs" $HTMLFile

        #endregion

        #region get OS info

        $WMICS = Get-WmiObject -Class Win32_ComputerSystem ; $FQDN = "$($WMICS.Name).$($WMICS.Domain)"
            Write-StringtoHTML "FQDN" "$FQDN" $HTMLFile

        $OSName = ((Get-WmiObject -Class Win32_OperatingSystem -Property Name).Name).Split('|')[0]
            Write-StringtoHTML "OSName" "$OSName" $HTMLFile

        $Admingroup = [ADSI]"WinNT://./Administrators,group"
            $AGroupmembers = @($Admingroup.Invoke("Members"))
            #$Administrators = @()
            $Administrators = Foreach ($AMember in $AGroupmembers) {
                $Amember.GetType().Invokemember("ADSPath","GetProperty",$null,$Amember,$null).Substring(8).Replace("/","\")
                Write-Output "`r`n"
                }
            Write-ListtoHTML "Admingroup" "Local Administrators" "$Administrators" $HTMLFile

        $RemoteDesktopGroup = [ADSI]"WinNT://./Remote Desktop Users,group"
            $RGroupmembers = @($RemoteDesktopGroup.Invoke("Members"))
            #$RDPUsers = @()
            $RDPUsers = Foreach ($RMember in $RGroupmembers) {
                $RMember.GetType().Invokemember("ADSPath","GetProperty",$null,$RMember,$null).Substring(8).Replace("/","\")
                Write-Output "`r`n"
                }
            Write-ListtoHTML "RemoteDesktopGroup" "Remote Desktop Users" "$RDPUsers" $HTMLFile
        
        $WUAuto = (Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name AUOptions).AUOptions | %{If ($_ -eq 4) { $True } Else { $False }}
            $WUDay = (Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name ScheduledInstallDay).ScheduledInstallDay |
                %{Switch ($_) { 0 { "Everyday"} ; 1 {"Sunday"} ; 2 {"Monday"} ; 3 {"Tuesday"} ; 4 {"Wednesday"} ; 5 {"Thursday"} ; 6 {"Friday"} ; 7 {"Saturday"} } }
            $WUTime = Get-Date -Hour $((Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name ScheduledInstallTime).ScheduledInstallTime) -Minute 00 -Format hh:%mmtt
            $WUProperties = @{"Weekday" = $WUDay; "Time" = $WUTime; "Automatic Install" = $WUAuto}
            $WindowsUpdateStatus = New-Object -TypeName PSObject -Property $WUProperties
            $WUPropList = "Weekday","Time","Automatic Install"
            Write-TabletoHTMLfromObject "WindowsUpdates" $WindowsUpdateStatus $WUPropList $HTMLFile

        $BackupJobs = If ((Get-Module -ListAvailable) -like "*BEMCLI*") {
            Import-Module BEMCLI ; Get-BEJob | Where-Object {($_.JobType -eq "Backup") -and ($_.Status -eq "Scheduled")} | Select-Object -Property Name,TaskName,SelectionSummary,Schedule
            }
            ElseIf (Test-Path "$env:ProgramFiles\Symantec\Backup Exec\bemcmd.exe") {
                Import-Module "..\BackupExecInfo\BackupExecInfo.psm1" ; $BackupJobs = Get-BEScheduledBackupJobInfo
                $BECustomObject = Foreach ($BEJob in $BackupJobs) {
                    $Name = (($BEJob.'JOB ID') -Split "} ")[1] -Replace "[(|)]",""
                    $BackupMethod = $BEJob."Backup Method".Split(" ")[1] -Replace "[(|)]",""
                    $SelectionNames = $BEJob | Get-Member | Where-Object {$_.Name -like "Selection*"} | Select-Object -Property Name
                    $JobSelections = @() ; $JobExclusions = @()
                    Foreach ($Selection in $SelectionNames) {
                        If ($BEJob.$($Selection.Name).'Operation Type' -eq 1) {
                            $JobSelections += "$($BEJob.$($Selection.Name).'Device Selection')\$($BEJob.$($Selection.Name).'File Name')"
                            }
                            ElseIf ($BEJob.$($Selection.Name).'Operation Type' -eq 0) {
                                $JobExclusions += "$($BEJob.$($Selection.Name).'Device Selection')\$($BEJob.$($Selection.Name).'File Name')"
                                }
                        }
                    $StartTime = $BEJob.Schedule.'Start Time'
                    $FirstWeek = (($BEJob.Schedule.'First Week').Split(",") | ForEach-Object {$_.Trim().SubString(0,3)}) -Join ""
                    $SecondWeek = (($BEJob.Schedule.'Second Week').Split(",") | ForEach-Object {$_.Trim().SubString(0,3)}) -Join ""
                    $ThirdWeek = (($BEJob.Schedule.'Third Week').Split(",") | ForEach-Object {$_.Trim().SubString(0,3)}) -Join ""
                    $FourthWeek = (($BEJob.Schedule.'Fourth Week').Split(",") | ForEach-Object {$_.Trim().SubString(0,3)}) -Join ""
                    $LastWeek = (($BEJob.Schedule.'Last Week').Split(",") | ForEach-Object {$_.Trim().SubString(0,3)}) -Join ""
                    $BEprops = @{"Name"=$Name;"Job Selections"=$($JobSelections | Sort-Object);"Job Exclusions"=$JobExclusions;"Start Time"=$StartTime;
                        "Week 1"=$FirstWeek;"Week 2"=$SecondWeek;"Week 3"=$ThirdWeek;"Week 4"=$FourthWeek;"Week Last"=$LastWeek }
                    New-Object PSObject -Property $BEprops
                    }
                Write-ListtoHTMLfromObject "BackupExec" "Backup Exec Jobs" $BECustomObject $HTMLFile
                }

            
        $BEKey = If (Test-Path 'HKLM:\SOFTWARE\Symantec\Backup Exec For Windows\Backup Exec\Engine\Agents') {
            (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Symantec\Backup Exec For Windows\Backup Exec\Engine\Agents' -Name 'Agent Directory List').'Agent Directory List'
            $BEPublishedServers = Foreach ($Server in $BEKey) {
                $Server
                Write-Output "`r`n"
                }
            Write-ListtoHTML "BEPublishedServers" "Backup Exec Servers" "$BEPublishedServers" $HTMLFile
            }

        $IPSecEnabled = If (netsh ipsec static show policy all | select-string -pattern "Assigned               : YES") {$True} Else {$False}
            Write-StringtoHTML "IPSecEnabled" "$IPSecEnabled" $HTMLFile
            
        $WFirewallEnabled = If (netsh advfirewall show domainprofile | Select-String -Pattern "State                                 ON") {$True} Else {$False}
            Write-StringtoHTML "WfirewallEnabled" "$WFirewallEnabled" $HTMLFile

        $Certificates = Get-ChildItem "Cert:\LocalMachine\My"
            $CertObjects = Foreach ($Cert in $Certificates) {
                $CertProps = @{}
                $SubjectName = $Cert.SubjectName.Name.Split(" ")[0].Replace("CN=","").Replace(",","")
                $CertProps.Add("Name",$SubjectName)
                $CertProps.Add("Expiration Date",$Cert.NotAfter)
                If ($($Cert.NotAfter) -gt $(Get-Date)) {
                    $SANs = (($Cert.Extensions | Where-Object {$_.Oid.FriendlyName -eq "Subject Alternative Name"}).Format(1)) -Replace "DNS Name=",""
                    $CertProps.Add("SANs",$SANs)
                    }
                New-Object -TypeName PSObject -Property $CertProps
                }
            Write-ListtoHTMLfromObject "Certs" "Certificates" $CertObjects $HTMLFile

        #endregion

        #region get hardware info

        $NetIPAddresses = (ipconfig /all | Select-String -Pattern "IPv4 Address") | %{ Foreach ($String in $_) {$String.ToString().Split(":")[1].Split("(")[0].Trim()} ; Write-Output "`r`n" }
            Write-ListtoHTML "NetIPAddresses" "IP Addresses" "$NetIPAddresses" $HTMLFile

        $SerialNumber = (Get-WmiObject -Class Win32_BIOS -Property SerialNumber).SerialNumber
            Write-StringtoHTML "SerialNumber" "$SerialNumber" $HTMLFile

        $TotalMemory = "$([math]::Round((Get-wmiobject -Class Win32_ComputerSystem -Property TotalPhysicalMemory).TotalPhysicalMemory / 1GB))GB"
            Write-StringtoHTML "Memory" "$TotalMemory" $HTMLFile

        $CPUquery = Get-WmiObject -Class Win32_Processor
            $CPUs = Foreach ($CPU in $CPUquery) {
                $CPUProps = @{'CPU Name' = $CPU.Name ; 'Cores' = $CPU.NumberofCores}
                New-Object -TypeName "PSObject" -Property $CPUprops
                }
            $CPUPropList = "CPU Name","Cores"
            Write-TabletoHTMLfromObject "CPUs" $CPUs $CPUPropList $HTMLFile

        $Diskquery = Get-Wmiobject -Class Win32_LogicalDisk | Where {$_.DriveType -eq 3}
            $Disks = Foreach ($Disk in $Diskquery) {
                $DiskProps = @{'Drive Letter' = $Disk.DeviceID ; 'Drive Space Used' = "$(([math]::Round(([math]::Abs(($Disk.FreeSpace / $Disk.Size) - 1))*100)))%"}
                New-Object "PSObject" -Property $DiskProps
                }
            $DiskPropList = "Drive Letter", "Drive Space Used"
            Write-TabletoHTMLfromObject "Disks" $Disks $DiskPropList $HTMLFile

        #endregion
        }

    If ($Computer) {
        RetrieveServerInfo $Computer
        }
    If ($BaseOU) {
        Foreach ($ComputerObject in ((Get-ADComputer -SearchBase $BaseOU -Filter *).Name)) {
            RetrieveServerInfo $ComputerObject
            }
        }